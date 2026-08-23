// Enables the GCP service APIs the stack depends on. Every downstream resource
// `dependsOn` these so a fresh project provisions cleanly in one `pulumi up`.

import * as gcp from "@pulumi/gcp";
import { provider } from "../config";

const SERVICES = [
  "run.googleapis.com",
  "sqladmin.googleapis.com",
  "artifactregistry.googleapis.com",
  "secretmanager.googleapis.com",
  "storage.googleapis.com",
  "compute.googleapis.com" // gcp provider lists regions; Cloud SQL pulls from it
];

export const apis = SERVICES.map(
  (service) =>
    new gcp.projects.Service(
      `api-${service.split(".")[0]}`,
      { service, disableOnDestroy: false },
      { provider }
    )
);
