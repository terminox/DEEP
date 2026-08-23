// Docker repository that holds the backend image builds and Cloud Run runs.
// Image path: <region>-docker.pkg.dev/<project>/backend/api:<tag>

import * as gcp from "@pulumi/gcp";
import { config, provider } from "../config";
import { apis } from "./apis";

export const repo = new gcp.artifactregistry.Repository(
  "backend",
  {
    repositoryId: "backend",
    format: "DOCKER",
    location: config.region,
    description: "Deep backend container images",
    // Without these, every build is retained forever. The DELETE must be
    // tagState ANY, not UNTAGGED: images are pushed tagged with a unique short
    // SHA, so a version never becomes untagged and an UNTAGGED-only policy
    // would collect precisely nothing. `keep-recent` is what makes ANY safe —
    // Artifact Registry evaluates KEEP policies first, so the newest 10
    // survive regardless of age.
    //
    // NB: an image is only collectable once no Cloud Run revision pins it, so
    // prune old revisions too (`gcloud run revisions delete`).
    cleanupPolicies: [
      {
        id: "keep-recent",
        action: "KEEP",
        mostRecentVersions: { keepCount: 10 }
      },
      {
        id: "delete-old",
        action: "DELETE",
        condition: { tagState: "ANY", olderThan: "2592000s" } // 30 days
      }
    ],
    // Ship once with this true, read the would-be deletions out of the repo's
    // cleanup dry-run output, then set it false to arm the policies.
    cleanupPolicyDryRun: true
  },
  { provider, dependsOn: apis }
);
