// Reviewing, validating and applying staged changes. Publishing is the only
// moment content moves, so everything that can be checked is checked here first
// and the whole selection lands in a single transaction or not at all.
import type { ContentDraft, DraftEntity, DraftOp } from "@prisma/client";
import { prisma } from "../../prisma.js";
import { ApiError } from "../errors.js";
import { validateThresholds } from "../awardRules.js";
import { sameValue } from "./coalesce.js";
import { loadAllDrafts, rowFromCreate } from "./overlay.js";
import {
  PUBLISH_ORDER,
  parseRefKey,
  refKey,
  specFor,
  type AnyRow,
  type Db,
  type DraftRef,
} from "./registry.js";
import { scheduleProblems, type PhaseTimes } from "./validators.js";

export interface FieldDiff {
  field: string;
  before: unknown;
  after: unknown;
}

export interface CascadeImpact {
  noun: string;
  count: number;
}

export interface ChangeSummary {
  key: string;
  entity: DraftEntity;
  entityId: string;
  noun: string;
  area: "sound" | "garden" | "pause";
  op: DraftOp;
  label: string;
  parentKey: string | null;
  parentLabel: string | null;
  stagedAt: string;
  authorName: string;
  fields: FieldDiff[];
  cascade: CascadeImpact[];
}

export interface ValidationReport {
  /** Every ref that will actually be written, after pulling in required ancestors. */
  resolved: string[];
  /** Refs added on the caller's behalf because a selected change depends on them. */
  addedByDependency: string[];
  blockers: string[];
  warnings: string[];
}

type LiveIndex = Map<DraftEntity, Map<string, AnyRow>>;

/** Loads every live row for the entities that currently have drafts. */
async function loadLiveIndex(drafts: ContentDraft[], db: Db = prisma): Promise<LiveIndex> {
  const index: LiveIndex = new Map();
  const entities = [...new Set(drafts.map((d) => d.entity))];
  for (const entity of entities) {
    const rows = await specFor(entity).delegate(db).findMany({});
    index.set(entity, new Map(rows.map((r) => [String(r.id), r])));
  }
  return index;
}

function liveRow(index: LiveIndex, entity: DraftEntity, id: string): AnyRow | null {
  return index.get(entity)?.get(id) ?? null;
}

function diffFor(draft: ContentDraft, live: AnyRow | null): FieldDiff[] {
  if (draft.op === "DELETE") return [];
  const patch = (draft.patch as AnyRow | null) ?? {};
  return Object.entries(patch)
    .filter(([field, after]) => !sameValue(after, live?.[field]))
    .map(([field, after]) => ({ field, before: live ? (live[field] ?? null) : null, after }));
}

/** What the database will remove along with this row, so the admin sees it first. */
async function cascadeFor(
  draft: ContentDraft,
  db: Db = prisma,
): Promise<CascadeImpact[]> {
  if (draft.op !== "DELETE") return [];
  const id = draft.entityId;
  const p = db as typeof prisma;

  if (draft.entity === "SOUND_CATEGORY") {
    const collections = await p.soundCollection.findMany({
      where: { categoryId: id },
      select: { id: true },
    });
    const collectionIds = collections.map((c) => c.id);
    const tracks = await p.soundTrack.findMany({
      where: { collectionId: { in: collectionIds } },
      select: { id: true },
    });
    const lyrics = await p.trackLyrics.count({
      where: { trackId: { in: tracks.map((t) => t.id) } },
    });
    return impacts([
      ["collection", collections.length],
      ["track", tracks.length],
      ["lyrics translation", lyrics],
    ]);
  }

  if (draft.entity === "SOUND_COLLECTION") {
    const tracks = await p.soundTrack.findMany({
      where: { collectionId: id },
      select: { id: true },
    });
    const lyrics = await p.trackLyrics.count({
      where: { trackId: { in: tracks.map((t) => t.id) } },
    });
    return impacts([
      ["track", tracks.length],
      ["lyrics translation", lyrics],
    ]);
  }

  if (draft.entity === "SOUND_TRACK") {
    return impacts([["lyrics translation", await p.trackLyrics.count({ where: { trackId: id } })]]);
  }

  if (draft.entity === "PLANT") {
    return impacts([["stage", await p.plantStage.count({ where: { plantId: id } })]]);
  }

  return [];
}

function impacts(pairs: [string, number][]): CascadeImpact[] {
  return pairs.filter(([, n]) => n > 0).map(([noun, count]) => ({ noun, count }));
}

// ---- Review ----

export async function pendingChanges(db: Db = prisma): Promise<ChangeSummary[]> {
  const drafts = await loadAllDrafts(db);
  if (drafts.length === 0) return [];

  const index = await loadLiveIndex(drafts, db);
  const byKey = new Map(drafts.map((d) => [refKey({ entity: d.entity, entityId: d.entityId }), d]));
  const authors = new Map(
    (
      await (db as typeof prisma).user.findMany({
        where: { id: { in: [...new Set(drafts.map((d) => d.authorId))] } },
        select: { id: true, displayName: true },
      })
    ).map((u) => [u.id, u.displayName]),
  );

  const summaries: ChangeSummary[] = [];
  for (const draft of drafts) {
    const spec = specFor(draft.entity);
    const live = liveRow(index, draft.entity, draft.entityId);

    let parentLabel: string | null = null;
    if (draft.parentKey) {
      const parentDraft = byKey.get(draft.parentKey);
      if (parentDraft) {
        parentLabel = parentDraft.label;
      } else {
        const parentRef = parseRefKey(draft.parentKey);
        const parentSpec = specFor(parentRef.entity);
        const row = await parentSpec.delegate(db).findUnique({
          where: {
            id: parentSpec.parseId ? parentSpec.parseId(parentRef.entityId) : parentRef.entityId,
          },
        });
        parentLabel = row ? parentSpec.label(row) : null;
      }
    }

    summaries.push({
      key: refKey({ entity: draft.entity, entityId: draft.entityId }),
      entity: draft.entity,
      entityId: draft.entityId,
      noun: spec.noun,
      area: spec.area,
      op: draft.op,
      label: draft.label,
      parentKey: draft.parentKey,
      parentLabel,
      stagedAt: draft.updatedAt.toISOString(),
      authorName: authors.get(draft.authorId) ?? "Unknown",
      fields: diffFor(draft, live),
      cascade: await cascadeFor(draft, db),
    });
  }

  const areaOrder = { sound: 0, garden: 1, pause: 2 };
  return summaries.sort(
    (a, b) =>
      areaOrder[a.area] - areaOrder[b.area] ||
      PUBLISH_ORDER.indexOf(a.entity) - PUBLISH_ORDER.indexOf(b.entity) ||
      a.label.localeCompare(b.label),
  );
}

// ---- Selection ----

/**
 * Publishing a track whose collection is still a staged create has to publish
 * the collection too, or the insert has nothing to hang off. Walks up the
 * parentKey chain and pulls in every ancestor that is itself a pending create.
 */
export function withRequiredAncestors(
  selected: Set<string>,
  byKey: Map<string, ContentDraft>,
): { resolved: Set<string>; added: string[] } {
  const resolved = new Set(selected);
  const added: string[] = [];
  const queue = [...selected];

  while (queue.length > 0) {
    const key = queue.pop()!;
    const draft = byKey.get(key);
    if (!draft?.parentKey) continue;
    const parent = byKey.get(draft.parentKey);
    if (!parent || parent.op !== "CREATE" || resolved.has(draft.parentKey)) continue;
    resolved.add(draft.parentKey);
    added.push(draft.parentKey);
    queue.push(draft.parentKey);
  }
  return { resolved, added };
}

/**
 * Discarding a staged parent must discard its staged children too, or they are
 * left pointing at a record that will never exist.
 */
export function withStagedDescendants(
  selected: Set<string>,
  drafts: ContentDraft[],
): Set<string> {
  const resolved = new Set(selected);
  let grew = true;
  while (grew) {
    grew = false;
    for (const draft of drafts) {
      const key = refKey({ entity: draft.entity, entityId: draft.entityId });
      if (resolved.has(key) || !draft.parentKey) continue;
      if (resolved.has(draft.parentKey)) {
        resolved.add(key);
        grew = true;
      }
    }
  }
  return resolved;
}

// ---- Validation ----

export async function validate(
  selection: string[] | "all",
  db: Db = prisma,
): Promise<ValidationReport> {
  const drafts = await loadAllDrafts(db);
  const byKey = new Map(drafts.map((d) => [refKey({ entity: d.entity, entityId: d.entityId }), d]));
  const requested =
    selection === "all" ? new Set(byKey.keys()) : new Set(selection.filter((k) => byKey.has(k)));

  const { resolved, added } = withRequiredAncestors(requested, byKey);
  const chosen = [...resolved].map((k) => byKey.get(k)!);
  const index = await loadLiveIndex(drafts, db);

  const blockers: string[] = [];
  const warnings: string[] = [];

  if (selection !== "all" && selection.some((k) => !byKey.has(k))) {
    warnings.push("Some selected changes were already published or discarded.");
  }

  for (const draft of chosen) {
    const spec = specFor(draft.entity);
    const live = liveRow(index, draft.entity, draft.entityId);
    const merged =
      draft.op === "CREATE"
        ? rowFromCreate(draft.entity, draft)
        : { ...(live ?? {}), ...(((draft.patch as AnyRow | null) ?? {}) as AnyRow) };

    if (draft.op !== "CREATE" && !live) {
      blockers.push(`${spec.noun} "${draft.label}" no longer exists - discard this change.`);
      continue;
    }

    // Someone else moved the row under this draft.
    if (
      draft.baseVersion &&
      live?.updatedAt instanceof Date &&
      live.updatedAt.getTime() !== draft.baseVersion.getTime()
    ) {
      blockers.push(
        `${spec.noun} "${draft.label}" was changed elsewhere after this edit was staged. Discard and redo it.`,
      );
    }

    // A child whose parent is staged for creation but left out of the selection
    // is caught by withRequiredAncestors; a parent that does not exist at all is
    // a genuine blocker.
    if (draft.op !== "DELETE" && draft.parentKey) {
      const parentRef = parseRefKey(draft.parentKey);
      const parentSpec = specFor(parentRef.entity);
      const parentLive = await parentSpec.delegate(db).findUnique({
        where: {
          id: parentSpec.parseId ? parentSpec.parseId(parentRef.entityId) : parentRef.entityId,
        },
      });
      const parentStaged = resolved.has(draft.parentKey);
      if (!parentLive && !parentStaged) {
        blockers.push(
          `${spec.noun} "${draft.label}" belongs to a ${parentSpec.noun.toLowerCase()} that no longer exists.`,
        );
      }
      // A parent staged for deletion takes the child with it.
      const parentDraft = byKey.get(draft.parentKey);
      if (parentDraft?.op === "DELETE" && resolved.has(draft.parentKey)) {
        warnings.push(
          `${spec.noun} "${draft.label}" will be removed with its ${parentSpec.noun.toLowerCase()}.`,
        );
      }
    }

    await validateEntity(draft, merged, chosen, index, blockers, warnings, db);
  }

  await validateUniqueness(chosen, index, blockers, db);
  await validatePauseSchedule(chosen, index, blockers, warnings, db);

  return {
    resolved: [...resolved],
    addedByDependency: added,
    blockers: [...new Set(blockers)],
    warnings: [...new Set(warnings)],
  };
}

async function validateEntity(
  draft: ContentDraft,
  merged: AnyRow,
  chosen: ContentDraft[],
  index: LiveIndex,
  blockers: string[],
  warnings: string[],
  db: Db,
): Promise<void> {
  const p = db as typeof prisma;
  const spec = specFor(draft.entity);

  // A staged create can sit for days. Re-check it against the entity's own
  // schema so a draft written before a column was added cannot insert a row
  // that no longer validates.
  if (draft.op === "CREATE") {
    const parsed = spec.createSchema.safeParse(merged);
    if (!parsed.success) {
      const fields = [...new Set(parsed.error.issues.map((i) => i.path.join(".")))]
        .filter(Boolean)
        .join(", ");
      blockers.push(
        `${spec.noun} "${draft.label}" is incomplete${fields ? `: ${fields}` : ""}.`,
      );
    }
  }

  // The schedule's own rules are checked once for the whole selection, in
  // validatePauseSchedule: none of them can be judged from one record, because
  // the meditation's length lives on the config while the windows live on the
  // sessions.
  if ((draft.entity === "PAUSE_CONFIG" || draft.entity === "PAUSE_SLOT") && draft.op !== "DELETE") {
    warnings.push(
      "Publishing this changes today's Global Pause for every user.",
    );
  }

  if (draft.entity === "SOUND_TRACK" && draft.op !== "DELETE" && !merged.audioPath) {
    warnings.push(`Track "${draft.label}" has no audio file yet.`);
  }

  if (draft.entity === "PLANT" && draft.op === "DELETE") {
    const inUse = await p.userPlantProgress.count({ where: { plantId: draft.entityId } });
    if (inUse > 0) {
      blockers.push(
        `Plant "${draft.label}" is in use by ${inUse} ${inUse === 1 ? "person" : "people"} and cannot be deleted. Hide it instead.`,
      );
    }
  }

  // Stage thresholds are a property of the whole ladder, so they are checked
  // against the plant's stage list as it will look after this publish.
  if (draft.entity === "PLANT_STAGE") {
    const plantId = String(merged.plantId ?? "");
    if (plantId) {
      const ladder = await effectiveStages(plantId, chosen, index, db);
      if (!validateThresholds(ladder)) {
        blockers.push(
          `Plant "${plantId}" stages must start at 0 sunlight and increase with each stage.`,
        );
      }
    }
  }
}

/** The stage ladder a plant will have once the chosen drafts are applied. */
async function effectiveStages(
  plantId: string,
  chosen: ContentDraft[],
  index: LiveIndex,
  db: Db,
): Promise<{ displayOrder: number; sunlightRequired: number }[]> {
  const live = await (db as typeof prisma).plantStage.findMany({ where: { plantId } });
  const rows = new Map<string, AnyRow>(live.map((s) => [s.id, s as AnyRow]));

  for (const draft of chosen) {
    if (draft.entity !== "PLANT_STAGE") continue;
    if (draft.op === "DELETE") {
      rows.delete(draft.entityId);
      continue;
    }
    const base =
      draft.op === "CREATE"
        ? rowFromCreate("PLANT_STAGE", draft)
        : { ...(liveRow(index, "PLANT_STAGE", draft.entityId) ?? {}), ...(draft.patch as AnyRow) };
    if (String(base.plantId) !== plantId) {
      rows.delete(draft.entityId);
      continue;
    }
    rows.set(draft.entityId, base);
  }

  return [...rows.values()].map((r) => ({
    displayOrder: Number(r.displayOrder ?? 0),
    sunlightRequired: Number(r.sunlightRequired ?? 0),
  }));
}

/**
 * The Global Pause schedule as it will stand once the chosen drafts are applied.
 *
 * Every schedule rule is a rule about the *set*: sessions must not overlap each
 * other, at least one must survive, and each one's window must be long enough
 * for a meditation track whose length lives on the config rather than on the
 * session. So this runs once per publish rather than once per draft, over live
 * rows overlaid with the chosen drafts only — which is deliberately a different
 * set from the one the admin screen validates (that one overlays *every* staged
 * draft, because that is what the admin is looking at).
 */
async function validatePauseSchedule(
  chosen: ContentDraft[],
  index: LiveIndex,
  blockers: string[],
  warnings: string[],
  db: Db,
): Promise<void> {
  const touchesSchedule = chosen.some(
    (d) => d.entity === "PAUSE_SLOT" || d.entity === "PAUSE_CONFIG",
  );
  if (!touchesSchedule) return;

  const p = db as typeof prisma;

  const live = await p.pauseSlot.findMany();
  const rows = new Map<string, AnyRow>(live.map((slot) => [slot.id, slot as AnyRow]));
  for (const draft of chosen) {
    if (draft.entity !== "PAUSE_SLOT") continue;
    if (draft.op === "DELETE") {
      rows.delete(draft.entityId);
      continue;
    }
    rows.set(
      draft.entityId,
      draft.op === "CREATE"
        ? rowFromCreate("PAUSE_SLOT", draft)
        : {
            ...(liveRow(index, "PAUSE_SLOT", draft.entityId) ?? {}),
            ...((draft.patch as AnyRow | null) ?? {}),
          },
    );
  }

  // The track's length comes from the config as the same publish will leave it:
  // a longer meditation staged alongside the sessions has to be judged against
  // the windows it will actually play in.
  const liveConfig = await p.pauseConfig.findUnique({ where: { id: 1 } });
  const configDraft = chosen.find((d) => d.entity === "PAUSE_CONFIG" && d.op !== "DELETE");
  const merged = {
    ...(liveConfig ?? {}),
    ...(((configDraft?.patch as AnyRow | null) ?? {}) as AnyRow),
  };
  const duration = Number(merged.meditationDurationSeconds ?? 0);
  if (!Number.isFinite(duration) || duration <= 0) return;

  const problems = scheduleProblems([...rows.values()] as unknown as PhaseTimes[], duration);
  blockers.push(...problems.blockers);
  warnings.push(...problems.warnings);
}

/** Unique columns must not collide with live rows or with each other. */
async function validateUniqueness(
  chosen: ContentDraft[],
  index: LiveIndex,
  blockers: string[],
  db: Db,
): Promise<void> {
  const deleting = new Set(
    chosen.filter((d) => d.op === "DELETE").map((d) => refKey({ entity: d.entity, entityId: d.entityId })),
  );

  for (const entity of new Set(chosen.map((d) => d.entity))) {
    const spec = specFor(entity);
    if (!spec.uniqueFields?.length) continue;

    const live = await spec.delegate(db).findMany({});
    const taken = new Map<string, string>();
    for (const row of live) {
      if (deleting.has(refKey({ entity, entityId: String(row.id) }))) continue;
      for (const field of spec.uniqueFields) {
        taken.set(`${field}:${String(row[field])}`, String(row.id));
      }
    }

    for (const draft of chosen) {
      if (draft.entity !== entity || draft.op === "DELETE") continue;
      const merged =
        draft.op === "CREATE"
          ? rowFromCreate(entity, draft)
          : {
              ...(liveRow(index, entity, draft.entityId) ?? {}),
              ...(((draft.patch as AnyRow | null) ?? {}) as AnyRow),
            };

      for (const field of spec.uniqueFields) {
        if (merged[field] === undefined) continue;
        const slot = `${field}:${String(merged[field])}`;
        const holder = taken.get(slot);
        if (holder && holder !== draft.entityId) {
          blockers.push(
            `Another ${spec.noun.toLowerCase()} already uses ${field} "${String(merged[field])}".`,
          );
        }
        taken.set(slot, draft.entityId);
      }
    }
  }
}

// ---- Apply ----

export interface PublishResult {
  published: number;
  refs: string[];
  warnings: string[];
}

export async function publish(
  selection: string[] | "all",
  db: Db = prisma,
): Promise<PublishResult> {
  const report = await validate(selection, db);
  if (report.blockers.length > 0) {
    throw new ApiError(
      409,
      "publish_blocked",
      report.blockers.join(" "),
    );
  }
  if (report.resolved.length === 0) {
    return { published: 0, refs: [], warnings: report.warnings };
  }

  const drafts = await (db as typeof prisma).contentDraft.findMany();
  const byKey = new Map(drafts.map((d) => [refKey({ entity: d.entity, entityId: d.entityId }), d]));
  const chosen = report.resolved.map((k) => byKey.get(k)).filter((d): d is ContentDraft => !!d);

  await (db as typeof prisma).$transaction(async (tx) => {
    // Deletes run children-first, so a freed unique slug is available to any
    // create in the same publish and no FK fires before its cascade.
    const deletes = chosen
      .filter((d) => d.op === "DELETE")
      .sort((a, b) => PUBLISH_ORDER.indexOf(b.entity) - PUBLISH_ORDER.indexOf(a.entity));
    const creates = chosen
      .filter((d) => d.op === "CREATE")
      .sort((a, b) => PUBLISH_ORDER.indexOf(a.entity) - PUBLISH_ORDER.indexOf(b.entity));
    const updates = chosen
      .filter((d) => d.op === "UPDATE")
      .sort((a, b) => PUBLISH_ORDER.indexOf(a.entity) - PUBLISH_ORDER.indexOf(b.entity));

    for (const draft of deletes) await applyDelete(draft, tx);
    for (const draft of creates) await applyCreate(draft, tx);
    for (const draft of updates) await applyUpdate(draft, tx);

    await tx.contentDraft.deleteMany({ where: { id: { in: chosen.map((d) => d.id) } } });
  });

  return { published: chosen.length, refs: report.resolved, warnings: report.warnings };
}

function idValue(draft: ContentDraft): unknown {
  const spec = specFor(draft.entity);
  return spec.parseId ? spec.parseId(draft.entityId) : draft.entityId;
}

async function applyCreate(draft: ContentDraft, tx: Db): Promise<void> {
  const spec = specFor(draft.entity);
  const data = {
    ...(spec.defaults ?? {}),
    ...(((draft.patch as AnyRow | null) ?? {}) as AnyRow),
    id: idValue(draft),
  };
  // Singletons are upserted: the row may already exist from a default-seeded DB.
  if (spec.singleton) {
    const { id, ...rest } = data;
    await spec.delegate(tx).update({ where: { id }, data: rest }).catch(async () => {
      await spec.delegate(tx).create({ data });
    });
    return;
  }
  await spec.delegate(tx).create({ data });
}

async function applyUpdate(draft: ContentDraft, tx: Db): Promise<void> {
  const spec = specFor(draft.entity);
  const patch = ((draft.patch as AnyRow | null) ?? {}) as AnyRow;
  if (Object.keys(patch).length === 0) return;
  await spec.delegate(tx).update({ where: { id: idValue(draft) }, data: patch });
}

async function applyDelete(draft: ContentDraft, tx: Db): Promise<void> {
  const spec = specFor(draft.entity);
  await spec
    .delegate(tx)
    .delete({ where: { id: idValue(draft) } })
    .catch(() => {
      /* already gone - the publish still succeeds */
    });
}

// ---- Discard ----

export async function discard(
  selection: string[] | "all",
  db: Db = prisma,
): Promise<{ discarded: number; refs: string[] }> {
  const p = db as typeof prisma;
  if (selection === "all") {
    const { count } = await p.contentDraft.deleteMany({});
    return { discarded: count, refs: [] };
  }

  const drafts = await loadAllDrafts(db);
  const resolved = withStagedDescendants(new Set(selection), drafts);
  const ids = drafts
    .filter((d) => resolved.has(refKey({ entity: d.entity, entityId: d.entityId })))
    .map((d) => d.id);

  const { count } = await p.contentDraft.deleteMany({ where: { id: { in: ids } } });
  return { discarded: count, refs: [...resolved] };
}

export async function pendingCount(db: Db = prisma): Promise<number> {
  return (db as typeof prisma).contentDraft.count();
}

export type { DraftRef };
