// Materializes the backend's secrets into Secret Manager. Each becomes a Secret
// + SecretVersion; Cloud Run references the version by name, and the runtime
// service account is granted accessor per-secret (in service.ts).

import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import { config, provider } from "../config";
import { apis } from "./apis";
import { databaseUrl } from "./database";

export interface AppSecret {
  /** The env var name the backend reads (also the Secret Manager secret id). */
  envName: string;
  secret: gcp.secretmanager.Secret;
}

function makeSecret(envName: string, value: pulumi.Input<string>): AppSecret {
  const secret = new gcp.secretmanager.Secret(
    `secret-${envName}`,
    { secretId: envName, replication: { auto: {} } },
    { provider, dependsOn: apis }
  );
  new gcp.secretmanager.SecretVersion(
    `secret-${envName}-v`,
    { secret: secret.id, secretData: value },
    { provider }
  );
  return { envName, secret };
}

export const secrets: AppSecret[] = [
  makeSecret("DATABASE_URL", databaseUrl),
  makeSecret("JWT_SECRET", config.jwtSecret),
  makeSecret("ADMIN_BOOTSTRAP_PASSWORD", config.adminBootstrapPassword)
];
