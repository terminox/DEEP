// Private Cloud Storage bucket for audio media. Public access is hard-blocked;
// the backend FUSE-mounts this bucket at MEDIA_DIR and serves files itself via
// @fastify/static (`/media/...`), so admin uploads and streaming need zero code
// changes and survive Cloud Run's ephemeral filesystem.

import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import { config, provider } from "../config";
import { apis } from "./apis";

export const mediaBucket = new gcp.storage.Bucket(
  "media",
  {
    name: `${config.project}-media`,
    location: config.region.toUpperCase(),
    uniformBucketLevelAccess: true,
    publicAccessPrevention: "enforced"
  },
  { provider, dependsOn: apis }
);

// The three committed tracks the Prisma seed references (prisma/seed.ts checks
// they exist and stores `/media/audio/<file>` paths). Declared here so they
// land in the bucket on the first `pulumi up`, before the seed ever runs.
const SEED_TRACKS = ["global-pause.mp3", "inner-light.mp3", "ivory.mp3"];

export const seedTracks = SEED_TRACKS.map(
  (file) =>
    new gcp.storage.BucketObject(
      `seed-${file}`,
      {
        bucket: mediaBucket.name,
        name: `audio/${file}`,
        contentType: "audio/mpeg",
        source: new pulumi.asset.FileAsset(`../deep-api/media/audio/${file}`)
      },
      { provider }
    )
);
