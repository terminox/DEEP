# Deep infrastructure (Pulumi + GCP)

One stack, one GCP project:

| Stack | GCP project | Region | DB tier | Cloud Run scaling | URL |
|---|---|---|---|---|---|
| `production` | `deep-production-app` | `asia-southeast1` | `db-f1-micro` | 0 → **1 (hard max)** | `*.run.app` (no custom domain yet) |

**Resources:** Artifact Registry (Docker) · Cloud SQL Postgres 15 (unix-socket only, no public
clients) · private GCS media bucket FUSE-mounted at `MEDIA_DIR=/media` (uploads + streaming need no
code changes and survive revisions) · Secret Manager (`DATABASE_URL`, `JWT_SECRET`,
`ADMIN_BOOTSTRAP_PASSWORD`) · dedicated runtime SA + least-privilege IAM · Cloud Run v2 service
(gen2) · one-shot Prisma migrate Job.

**`maxInstances` must stay 1**: Global Pause presence is an in-memory Map
(`deep-api/src/lib/pausePresence.ts`). Externalize it (Redis) before raising.

## One-time setup

```bash
gcloud projects create deep-production-app --name=deep-production
gcloud billing projects link deep-production-app --billing-account=<billing-account-id>
gcloud auth configure-docker asia-southeast1-docker.pkg.dev --quiet

cd infra && npm install
pulumi stack init production
pulumi config set --secret deep:jwtSecret "$(openssl rand -hex 32)"
pulumi config set --secret deep:adminBootstrapPassword "$(openssl rand -base64 18)"
pulumi up   # first run deploys a placeholder image so the registry exists before any push
```

## Deploy

```bash
# 1. Build + push the backend image (from repo root; Apple Silicon → force amd64).
REGION=asia-southeast1; PROJECT=deep-production-app; SHA=$(git rev-parse --short HEAD)
IMAGE=$REGION-docker.pkg.dev/$PROJECT/backend/api:$SHA
docker buildx build --platform linux/amd64 -t $IMAGE --push deep-api

# 2. Point the stack at the new image and apply.
cd infra
pulumi config set deep:image $IMAGE
pulumi up

# 3. Run migrations BEFORE trusting the new revision. (The job name is
#    Pulumi-generated — always resolve it from the stack output.)
gcloud run jobs execute "$(pulumi stack output migrateJob)" \
  --region $REGION --project $PROJECT --wait

# 4. Smoke check.
curl -fsS "$(pulumi stack output apiEndpoint)/health"
```

### Seeding (once, not per deploy)

The seed wipes and reinserts the content tables (never users), so admin-made content edits would be
clobbered — run it only on a fresh database, via an args override on the migrate job:

```bash
gcloud run jobs execute "$(pulumi stack output migrateJob)" \
  --region asia-southeast1 --project deep-production-app \
  --args tsx,prisma/seed.ts --wait
```

## Notes

- **Secrets** live in Secret Manager and are injected as secret env refs; the backend reads plain
  `process.env` (`src/env.ts` prefers process env over `.env`).
- **DATABASE_URL** is assembled in `components/database.ts` in the Cloud SQL unix-socket form
  (`?host=/cloudsql/...&connection_limit=5`) and stored whole in Secret Manager.
- **PUBLIC_BASE_URL** is the deterministic Cloud Run URL
  (`https://deep-api-<projectNumber>.<region>.run.app`), computed in `components/service.ts` — the
  service name is pinned to `deep-api` to keep it stable. It is the security boundary for media
  URLs; never remove it.
- **Prod env deliberately omits** `ALLOW_TIME_OVERRIDE` (dev time-travel routes) and GeoIP config
  (degrades to country-only presence).
- **Artifact Registry cleanup** runs in dry-run mode initially; set `cleanupPolicyDryRun: false`
  in `components/artifactRegistry.ts` once the would-be deletions look right.
- **Handover to a client** = relink billing + grant them `roles/owner`; nothing in the stack
  hardcodes the personal account.
