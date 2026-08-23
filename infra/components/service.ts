// The runtime service account, its IAM, the Cloud Run service, and the one-shot
// migrate Job (which also runs the seed once, via an args override).

import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import { config, provider } from "../config";
import { apis } from "./apis";
import { instance } from "./database";
import { secrets } from "./secrets";
import { mediaBucket } from "./storage";

// Dedicated runtime identity (never the default compute SA).
const sa = new gcp.serviceaccount.Account(
  "run-sa",
  { accountId: "deep-api-run", displayName: "Deep API Cloud Run runtime" },
  { provider, dependsOn: apis }
);
const member = pulumi.interpolate`serviceAccount:${sa.email}`;

// --- IAM (collected so the service waits for them before its first boot) ---
const iam: pulumi.Resource[] = [];

iam.push(
  new gcp.projects.IAMMember(
    "run-cloudsql",
    { project: config.project, role: "roles/cloudsql.client", member },
    { provider }
  )
);

// Accessor per secret (scoped, not project-wide).
for (const s of secrets) {
  iam.push(
    new gcp.secretmanager.SecretIamMember(
      `run-secret-${s.envName}`,
      { secretId: s.secret.id, role: "roles/secretmanager.secretAccessor", member },
      { provider }
    )
  );
}

// Read + write media objects through the FUSE mount (admin audio uploads).
iam.push(
  new gcp.storage.BucketIAMMember(
    "run-bucket",
    { bucket: mediaBucket.name, role: "roles/storage.objectAdmin", member },
    { provider }
  )
);

// PUBLIC_BASE_URL must be known before the service exists (it's the security
// boundary for media URLs — src/lib/media.ts refuses to trust the Host header
// when it's set). Cloud Run URLs are deterministic:
//   https://<service>-<projectNumber>.<region>.run.app
// so compute it from the project number and pin the service name below.
const SERVICE_NAME = "deep-api";
const projectInfo = gcp.organizations.getProjectOutput({ projectId: config.project }, { provider });
export const publicBaseUrl = pulumi.interpolate`https://${SERVICE_NAME}-${projectInfo.number}.${config.region}.run.app`;

// --- Container env ---
const plainEnv: gcp.types.input.cloudrunv2.ServiceTemplateContainerEnv[] = [
  { name: "NODE_ENV", value: "production" },
  { name: "MEDIA_DIR", value: "/media" },
  { name: "PUBLIC_BASE_URL", value: publicBaseUrl },
  { name: "ADMIN_BOOTSTRAP_EMAIL", value: config.adminBootstrapEmail }
  // Deliberately unset: ALLOW_TIME_OVERRIDE (dev-only time-travel routes must
  // not exist in prod) and GEOIP_DB_PATH / MAXMIND_LICENSE_KEY (GeoIP degrades
  // gracefully to country-only presence without the mmdb).
];

const secretEnv = (s: (typeof secrets)[number]): gcp.types.input.cloudrunv2.ServiceTemplateContainerEnv => ({
  name: s.envName,
  valueSource: { secretKeyRef: { secret: s.secret.secretId, version: "latest" } }
});

const cloudSqlVolume = {
  name: "cloudsql",
  cloudSqlInstance: { instances: [instance.connectionName] }
};
const cloudSqlMount = { name: "cloudsql", mountPath: "/cloudsql" };

// --- Cloud Run service ---
export const service = new gcp.cloudrunv2.Service(
  "api",
  {
    name: SERVICE_NAME, // pinned: publicBaseUrl above depends on it
    location: config.region,
    ingress: "INGRESS_TRAFFIC_ALL",
    deletionProtection: false,
    template: {
      serviceAccount: sa.email,
      // GEN2 is required for GCS FUSE volume mounts.
      executionEnvironment: "EXECUTION_ENVIRONMENT_GEN2",
      // maxInstances MUST stay 1 — Global Pause presence is an in-memory Map
      // (deep-api/src/lib/pausePresence.ts). See config.ts.
      scaling: { minInstanceCount: config.minInstances, maxInstanceCount: config.maxInstances },
      maxInstanceRequestConcurrency: 80,
      volumes: [
        cloudSqlVolume,
        {
          name: "media",
          // uid/gid 1000 = the `node` user the image runs as; without these the
          // FUSE files surface root-owned and uploads would EACCES.
          gcs: { bucket: mediaBucket.name, readOnly: false, mountOptions: ["uid=1000", "gid=1000"] }
        }
      ],
      containers: [
        {
          image: config.image,
          ports: { containerPort: 8080 },
          envs: [...plainEnv, ...secrets.map(secretEnv)],
          volumeMounts: [cloudSqlMount, { name: "media", mountPath: "/media" }],
          resources: {
            limits: { cpu: "1", memory: "512Mi" },
            cpuIdle: config.minInstances === 0 // throttle CPU between requests when scaling to zero
          },
          // Generous: bootstrapAdmin() talks to the DB before listen(), and a
          // db-f1-micro handshake through the socket proxy on a cold start can
          // be slow.
          startupProbe: {
            httpGet: { path: "/health", port: 8080 },
            periodSeconds: 5,
            failureThreshold: 24,
            timeoutSeconds: 3
          },
          livenessProbe: { httpGet: { path: "/health", port: 8080 } }
        }
      ]
    }
  },
  { provider, dependsOn: iam }
);

// Public endpoint — the app authenticates itself with its own JWTs.
new gcp.cloudrunv2.ServiceIamMember(
  "api-invoker",
  { name: service.name, location: config.region, role: "roles/run.invoker", member: "allUsers" },
  { provider }
);

// --- One-shot migrate Job: `prisma migrate deploy` against Cloud SQL ---
// Seed once (and only once — it wipes/reinserts content tables) by overriding
// the args: gcloud run jobs execute <job> --args tsx,prisma/seed.ts
const dbSecret = secrets.find((s) => s.envName === "DATABASE_URL")!;
const jobDbEnv: gcp.types.input.cloudrunv2.JobTemplateTemplateContainerEnv = {
  name: dbSecret.envName,
  valueSource: { secretKeyRef: { secret: dbSecret.secret.secretId, version: "latest" } }
};

export const migrateJob = new gcp.cloudrunv2.Job(
  "migrate",
  {
    location: config.region,
    deletionProtection: false,
    template: {
      template: {
        serviceAccount: sa.email,
        maxRetries: 1,
        timeout: "600s",
        volumes: [cloudSqlVolume],
        containers: [
          {
            image: config.image,
            commands: ["npx"],
            args: ["prisma", "migrate", "deploy"],
            envs: [jobDbEnv],
            volumeMounts: [cloudSqlMount]
          }
        ]
      }
    }
  },
  { provider, dependsOn: iam }
);

export const apiUrl = service.uri;
export const migrateJobName = migrateJob.name;
