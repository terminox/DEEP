// What admin write routes call instead of prisma.<model>.create/update/delete.
// Each one records the intent and returns the row as it WOULD look, so the
// panel can render the edit immediately while the app keeps serving live data.
import crypto from "node:crypto";
import type { ContentDraft, DraftEntity } from "@prisma/client";
import { prisma } from "../../prisma.js";
import { ApiError } from "../errors.js";
import { coalesce, prunePatch, type StagedState } from "./coalesce.js";
import { markerFor, resolveOne, rowFromCreate, type Resolved } from "./overlay.js";
import { refKey, specFor, type AnyRow } from "./registry.js";

async function existingDraft(
  entity: DraftEntity,
  entityId: string,
): Promise<ContentDraft | null> {
  return prisma.contentDraft.findUnique({
    where: { entity_entityId: { entity, entityId } },
  });
}

function stateOf(draft: ContentDraft | null): StagedState | null {
  return draft ? { op: draft.op, patch: draft.patch as AnyRow | null } : null;
}

/** Writes the coalesced state, computing the label and parent from the merged row. */
async function commit(
  entity: DraftEntity,
  entityId: string,
  result: ReturnType<typeof coalesce>,
  mergedRow: AnyRow,
  actorId: string,
  baseVersion: Date | null,
): Promise<void> {
  if (result.action === "reject") throw ApiError.conflict(result.reason, "draft_conflict");

  if (result.action === "clear") {
    await prisma.contentDraft
      .delete({ where: { entity_entityId: { entity, entityId } } })
      .catch(() => {
        /* already gone */
      });
    return;
  }

  const spec = specFor(entity);
  const parent = spec.parentOf(mergedRow);

  await prisma.contentDraft.upsert({
    where: { entity_entityId: { entity, entityId } },
    create: {
      entity,
      entityId,
      op: result.op,
      patch: (result.patch ?? undefined) as never,
      baseVersion,
      label: spec.label(mergedRow),
      parentKey: parent ? refKey(parent) : null,
      authorId: actorId,
    },
    update: {
      op: result.op,
      patch: (result.patch ?? null) as never,
      label: spec.label(mergedRow),
      parentKey: parent ? refKey(parent) : null,
      authorId: actorId,
    },
  });
}

async function loadLive(entity: DraftEntity, entityId: string): Promise<AnyRow | null> {
  const spec = specFor(entity);
  return spec
    .delegate(prisma)
    .findUnique({ where: { id: spec.parseId ? spec.parseId(entityId) : entityId } });
}

async function reread<T extends AnyRow = AnyRow>(
  entity: DraftEntity,
  entityId: string,
): Promise<Resolved<T>> {
  const resolved = await resolveOne<T>(entity, entityId);
  if (!resolved) throw ApiError.notFound(`${specFor(entity).noun} not found`);
  return resolved;
}

/**
 * Stages a new record. The id is minted now rather than at publish, so children
 * can be staged against a parent that does not exist in the database yet.
 */
export async function stageCreate<T extends AnyRow = AnyRow>(
  entity: DraftEntity,
  patch: AnyRow,
  actorId: string,
): Promise<Resolved<T>> {
  const spec = specFor(entity);
  const entityId = spec.mintId ? spec.mintId(patch) : crypto.randomUUID();

  if (await existingDraft(entity, entityId)) {
    throw ApiError.conflict(`A ${spec.noun.toLowerCase()} with that id is already staged.`);
  }
  if (await loadLive(entity, entityId)) {
    throw ApiError.conflict(`A ${spec.noun.toLowerCase()} with that id already exists.`);
  }

  const merged = { ...(spec.defaults ?? {}), ...patch, id: entityId };
  await commit(entity, entityId, { action: "upsert", op: "CREATE", patch }, merged, actorId, null);
  return reread<T>(entity, entityId);
}

/** Stages a partial edit. Fields already matching live are dropped. */
export async function stageUpdate<T extends AnyRow = AnyRow>(
  entity: DraftEntity,
  entityId: string,
  patch: AnyRow,
  actorId: string,
): Promise<Resolved<T>> {
  const spec = specFor(entity);
  const draft = await existingDraft(entity, entityId);
  const live = await loadLive(entity, entityId);

  if (!live && draft?.op !== "CREATE") {
    throw ApiError.notFound(`${spec.noun} not found`);
  }

  const baseRow = live ?? rowFromCreate(entity, draft!);
  const merged = { ...baseRow, ...patch };

  let result = coalesce(stateOf(draft), { op: "UPDATE", patch });

  // Prune the FULL staged patch against live, not just this one edit. Typing a
  // new title and then typing the old one back has to leave no pending change,
  // and only the merged patch can tell that the record is back where it started.
  // A staged CREATE is left alone: it has no live row to compare against.
  if (result.action === "upsert" && result.op === "UPDATE") {
    const pruned = prunePatch(result.patch ?? {}, live);
    result =
      Object.keys(pruned).length === 0
        ? { action: "clear" }
        : { action: "upsert", op: "UPDATE", patch: pruned };
  }

  const baseVersion =
    draft?.baseVersion ??
    (spec.versioned && live?.updatedAt instanceof Date ? live.updatedAt : null);

  await commit(entity, entityId, result, merged, actorId, baseVersion);
  return reread<T>(entity, entityId);
}

/** Stages a deletion. A staged create is simply dropped instead. */
export async function stageDelete(
  entity: DraftEntity,
  entityId: string,
  actorId: string,
): Promise<void> {
  const spec = specFor(entity);
  const draft = await existingDraft(entity, entityId);
  const live = await loadLive(entity, entityId);

  if (!live && draft?.op !== "CREATE") {
    // Deleting something that is not there is a no-op, matching the routes'
    // existing idempotent delete behaviour.
    return;
  }

  const baseRow = live ?? rowFromCreate(entity, draft!);
  const result = coalesce(stateOf(draft), { op: "DELETE" });
  const baseVersion =
    draft?.baseVersion ??
    (spec.versioned && live?.updatedAt instanceof Date ? live.updatedAt : null);

  await commit(entity, entityId, result, baseRow, actorId, baseVersion);
}

/**
 * Stages a reorder as one displayOrder patch per moved row. Rows already at
 * their target position produce no draft, so dragging an item back where it
 * started clears the pending change instead of leaving a phantom one.
 */
export async function stageReorder(
  entity: DraftEntity,
  ids: string[],
  actorId: string,
): Promise<void> {
  for (const [index, id] of ids.entries()) {
    await stageUpdate(entity, id, { displayOrder: index }, actorId);
  }
}

/**
 * Stages a singleton (PauseConfig) whose row is upserted rather than created.
 * Publish upserts too, so a database that has never had the row still works.
 */
export async function stageSingleton<T extends AnyRow = AnyRow>(
  entity: DraftEntity,
  patch: AnyRow,
  actorId: string,
): Promise<Resolved<T>> {
  const spec = specFor(entity);
  if (!spec.singleton) throw new Error(`${entity} is not a singleton`);
  const entityId = String(spec.singleton.id);

  const live = await loadLive(entity, entityId);
  if (!live) {
    // First save on a fresh database: stage it as a create of the fixed row.
    return stageCreateWithId<T>(entity, entityId, patch, actorId);
  }
  return stageUpdate<T>(entity, entityId, patch, actorId);
}

/** stageCreate for entities whose id is fixed rather than minted. */
export async function stageCreateWithId<T extends AnyRow = AnyRow>(
  entity: DraftEntity,
  entityId: string,
  patch: AnyRow,
  actorId: string,
): Promise<Resolved<T>> {
  const spec = specFor(entity);
  const draft = await existingDraft(entity, entityId);
  const merged = { ...(spec.defaults ?? {}), ...patch, id: entityId };
  const result = coalesce(stateOf(draft), {
    op: draft ? "UPDATE" : "CREATE",
    patch,
  });
  await commit(entity, entityId, result, merged, actorId, null);
  return reread<T>(entity, entityId);
}

/**
 * The staged equivalent of prisma.upsert on a compound unique key - used by
 * lyrics, which are addressed by (trackId, languageCode) rather than by id.
 */
export async function stageUpsertBy<T extends AnyRow = AnyRow>(
  entity: DraftEntity,
  match: (row: AnyRow) => boolean,
  createPatch: AnyRow,
  updatePatch: AnyRow,
  actorId: string,
): Promise<Resolved<T>> {
  const spec = specFor(entity);
  const live = (await spec.delegate(prisma).findMany({})).find(match);
  if (live) return stageUpdate<T>(entity, String(live.id), updatePatch, actorId);

  const staged = await prisma.contentDraft.findMany({ where: { entity, op: "CREATE" } });
  const pending = staged.find((d) => match(rowFromCreate(entity, d)));
  if (pending) return stageUpdate<T>(entity, pending.entityId, updatePatch, actorId);

  return stageCreate<T>(entity, createPatch, actorId);
}

/** The staged equivalent of a delete addressed by something other than the id. */
export async function stageDeleteBy(
  entity: DraftEntity,
  match: (row: AnyRow) => boolean,
  actorId: string,
): Promise<void> {
  const spec = specFor(entity);
  const live = (await spec.delegate(prisma).findMany({})).find(match);
  if (live) {
    await stageDelete(entity, String(live.id), actorId);
    return;
  }
  const staged = await prisma.contentDraft.findMany({ where: { entity, op: "CREATE" } });
  const pending = staged.find((d) => match(rowFromCreate(entity, d)));
  if (pending) await stageDelete(entity, pending.entityId, actorId);
}

export { markerFor };
