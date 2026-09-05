import { test } from "node:test";
import assert from "node:assert/strict";
import type { ContentDraft, DraftOp } from "@prisma/client";
import { DraftEntity } from "@prisma/client";
type DraftEntity = (typeof DraftEntity)[keyof typeof DraftEntity];
import {
  withRequiredAncestors,
  withStagedDescendants,
} from "../src/lib/drafts/publish.js";
import { PUBLISH_ORDER, refKey } from "../src/lib/drafts/registry.js";

function draft(
  entity: DraftEntity,
  entityId: string,
  op: DraftOp,
  parentKey: string | null = null,
): ContentDraft {
  return {
    id: `${entity}-${entityId}`,
    entity,
    entityId,
    op,
    patch: null,
    baseVersion: null,
    label: entityId,
    parentKey,
    authorId: "admin",
    createdAt: new Date(0),
    updatedAt: new Date(0),
  };
}

function index(drafts: ContentDraft[]) {
  return new Map(drafts.map((d) => [refKey({ entity: d.entity, entityId: d.entityId }), d]));
}

test("publishing a track pulls in its unpublished collection and category", () => {
  // The exact half-published accident this exists to prevent: a track inserted
  // against a collection that does not exist yet.
  const drafts = [
    draft("SOUND_CATEGORY", "cat", "CREATE"),
    draft("SOUND_COLLECTION", "col", "CREATE", "SOUND_CATEGORY:cat"),
    draft("SOUND_TRACK", "trk", "CREATE", "SOUND_COLLECTION:col"),
  ];
  const { resolved, added } = withRequiredAncestors(
    new Set(["SOUND_TRACK:trk"]),
    index(drafts),
  );

  assert.deepEqual(
    [...resolved].sort(),
    ["SOUND_CATEGORY:cat", "SOUND_COLLECTION:col", "SOUND_TRACK:trk"],
  );
  assert.deepEqual(added.sort(), ["SOUND_CATEGORY:cat", "SOUND_COLLECTION:col"]);
});

test("an already-live parent is not dragged into the publish", () => {
  // The collection exists in the database and merely has an edit staged; the
  // track can go live without also shipping that unrelated edit.
  const drafts = [
    draft("SOUND_COLLECTION", "col", "UPDATE"),
    draft("SOUND_TRACK", "trk", "CREATE", "SOUND_COLLECTION:col"),
  ];
  const { resolved, added } = withRequiredAncestors(
    new Set(["SOUND_TRACK:trk"]),
    index(drafts),
  );

  assert.deepEqual([...resolved], ["SOUND_TRACK:trk"]);
  assert.deepEqual(added, []);
});

test("a parent with no draft at all is left alone", () => {
  const drafts = [draft("PLANT_STAGE", "stage", "CREATE", "PLANT:oak")];
  const { resolved, added } = withRequiredAncestors(
    new Set(["PLANT_STAGE:stage"]),
    index(drafts),
  );
  assert.deepEqual([...resolved], ["PLANT_STAGE:stage"]);
  assert.deepEqual(added, []);
});

test("discarding a staged parent discards everything staged under it", () => {
  // Otherwise the children survive pointing at a record that will never exist.
  const drafts = [
    draft("SOUND_CATEGORY", "cat", "CREATE"),
    draft("SOUND_COLLECTION", "col", "CREATE", "SOUND_CATEGORY:cat"),
    draft("SOUND_TRACK", "trk", "CREATE", "SOUND_COLLECTION:col"),
    draft("SOUND_CATEGORY", "other", "UPDATE"),
  ];
  const resolved = withStagedDescendants(new Set(["SOUND_CATEGORY:cat"]), drafts);

  assert.deepEqual(
    [...resolved].sort(),
    ["SOUND_CATEGORY:cat", "SOUND_COLLECTION:col", "SOUND_TRACK:trk"],
  );
  assert.equal(resolved.has("SOUND_CATEGORY:other"), false);
});

test("discarding a leaf leaves its ancestors staged", () => {
  const drafts = [
    draft("SOUND_COLLECTION", "col", "CREATE"),
    draft("SOUND_TRACK", "trk", "CREATE", "SOUND_COLLECTION:col"),
  ];
  const resolved = withStagedDescendants(new Set(["SOUND_TRACK:trk"]), drafts);
  assert.deepEqual([...resolved], ["SOUND_TRACK:trk"]);
});

test("PUBLISH_ORDER puts every parent before its children", () => {
  // publish() creates in this order and deletes in reverse, so a wrong entry
  // here is a foreign-key failure at publish time.
  const before = (entity: DraftEntity) => PUBLISH_ORDER.indexOf(entity);
  assert.ok(before("SOUND_CATEGORY") < before("SOUND_COLLECTION"));
  assert.ok(before("SOUND_COLLECTION") < before("SOUND_TRACK"));
  assert.ok(before("SOUND_TRACK") < before("TRACK_LYRICS"));
  assert.ok(before("PLANT") < before("PLANT_STAGE"));
  assert.ok(before("PAUSE_CONFIG") < before("PAUSE_SLOT"));
  // Every entity must appear exactly once, or sorting silently drops it to -1.
  // Counted against the enum rather than a literal, so adding an entity and
  // forgetting to order it fails here instead of quietly ordering it last.
  assert.equal(new Set(PUBLISH_ORDER).size, PUBLISH_ORDER.length);
  assert.deepEqual(new Set(PUBLISH_ORDER), new Set(Object.keys(DraftEntity)));
});
