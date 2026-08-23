// Cloud SQL Postgres 15 for user data. Public IP with NO authorized networks:
// Cloud Run reaches it only through the built-in Cloud SQL connector (a unix
// socket), never the public internet. The DATABASE_URL is assembled here in the
// exact unix-socket form Prisma needs and stored whole in Secret Manager, so the
// backend needs zero changes.

import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import * as random from "@pulumi/random";
import { config, provider } from "../config";
import { apis } from "./apis";

const password = new random.RandomPassword("db-password", {
  length: 32,
  special: false // alphanumeric → no URL-encoding needed in the connection string
});

export const instance = new gcp.sql.DatabaseInstance(
  "pg",
  {
    databaseVersion: "POSTGRES_15",
    region: config.region,
    deletionProtection: config.deletionProtection,
    settings: {
      tier: config.dbTier,
      availabilityType: "ZONAL",
      ipConfiguration: { ipv4Enabled: true, authorizedNetworks: [] },
      backupConfiguration: {
        // Daily backups, default 7 retained. PITR stays off — it needs WAL
        // storage that roughly doubles a db-f1-micro's bill.
        enabled: true,
        pointInTimeRecoveryEnabled: false
      }
    }
  },
  { provider, dependsOn: apis }
);

export const database = new gcp.sql.Database(
  "app-db",
  { name: "deep", instance: instance.name },
  { provider }
);

export const dbUser = new gcp.sql.User(
  "app-user",
  { name: "deep", instance: instance.name, password: password.result },
  { provider }
);

// Cloud Run mounts the instance socket at /cloudsql/<connectionName>. Prisma
// takes the socket directory via `?host=`; the host before `@` is an ignored
// placeholder. `connection_limit=5` guards db-f1-micro's small max_connections
// (~25) against the Prisma pool — with maxInstances 1 the total stays low.
export const databaseUrl: pulumi.Output<string> = pulumi.interpolate`postgresql://deep:${password.result}@localhost/deep?host=/cloudsql/${instance.connectionName}&connection_limit=5`;
