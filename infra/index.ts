// Deep GCP infrastructure (Pulumi, TypeScript).
//
// One stack (`production`) → GCP project `deep-production-app`. Provisions
// Artifact Registry, Cloud SQL Postgres, the private media bucket (FUSE-mounted
// into the service at MEDIA_DIR), Secret Manager, a dedicated runtime service
// account, the Cloud Run service, and a one-shot Prisma migrate Job.
//
// Deploy flow (see README.md): build + push the image, set `deep:image`, run
// `pulumi up`, then execute the migrate Job before trusting the new revision.

import { config } from "./config";
import { repo } from "./components/artifactRegistry";
import { instance } from "./components/database";
import { mediaBucket } from "./components/storage";
import { apiUrl, migrateJobName, publicBaseUrl as baseUrl } from "./components/service";

export const region = config.region;
export const imageRepo = repo.repositoryId.apply(
  (id) => `${config.region}-docker.pkg.dev/${config.project}/${id}`
);
export const sqlInstanceConnectionName = instance.connectionName;
export const mediaBucketName = mediaBucket.name;
export const apiEndpoint = apiUrl;
export const publicBaseUrl = baseUrl;
export const migrateJob = migrateJobName;
