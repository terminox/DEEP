// Typed, per-stack configuration for the Deep infrastructure. Non-secret values
// live in `Pulumi.<stack>.yaml`; secrets are set encrypted with
// `pulumi config set --secret deep:<key> <value>` and surfaced here as
// `pulumi.Output<string>`. The GCP project + region come from the standard
// `gcp:project` / `gcp:region` config the provider already reads.

import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

const cfg = new pulumi.Config("deep");
const gcpCfg = new pulumi.Config("gcp");

export const project = gcpCfg.require("project");
export const region = gcpCfg.get("region") ?? "asia-southeast1";

export const config = {
  project,
  region,

  // Compute / scaling.
  //
  // maxInstances MUST stay 1: Global Pause presence lives in an in-memory Map
  // (deep-api/src/lib/pausePresence.ts) that a second instance would split-brain.
  // Never raise it without externalizing that state (Redis).
  dbTier: cfg.get("dbTier") ?? "db-f1-micro",
  minInstances: cfg.getNumber("minInstances") ?? 0,
  maxInstances: cfg.getNumber("maxInstances") ?? 1,
  deletionProtection: cfg.getBoolean("deletionProtection") ?? true,

  // The container image to deploy. Set per build:
  //   pulumi config set deep:image <region>-docker.pkg.dev/<proj>/backend/api:<sha>
  // Falls back to a placeholder so the first `pulumi up` can create the
  // Artifact Registry repo before any image exists to push.
  image: cfg.get("image") ?? "us-docker.pkg.dev/cloudrun/container/hello",

  // Admin bootstrap: src/bootstrap.ts upserts this admin account on every boot.
  adminBootstrapEmail: cfg.get("adminBootstrapEmail") ?? "admin@deep.app",

  // Secrets (encrypted in the stack file, materialized into Secret Manager).
  jwtSecret: cfg.requireSecret("jwtSecret"),
  adminBootstrapPassword: cfg.requireSecret("adminBootstrapPassword")
};

// A provider pinned to the configured project/region so every resource lands in
// the right place even when a stack switches projects.
export const provider = new gcp.Provider("gcp", { project, region });
