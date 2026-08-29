// Merges staged drafts over live rows so the admin panel shows work in
// progress. The app never calls any of this - it reads the live tables, which
// is exactly why unpublished content is invisible to it for free.
import type { ContentDraft, DraftEntity, DraftOp } from "@prisma/client";
import { prisma } from "../../prisma.js";
import { changedFields } from "./coalesce.js";
import { specFor, type AnyRow, type Db } from "./registry.js";

/** What the admin UI renders as a Draft / Edited / Will delete badge. */
export interface PendingMarker {
  op: DraftOp;
  changedFields: string[];
  stagedAt: string;
}

export interface Resolved<T = AnyRow> {
  row: T;
  pending: PendingMarker | null;
}

export function markerFor(draft: ContentDraft): PendingMarker {
  return {
    op: draft.op,
    changedFields: changedFields({ op: draft.op, patch: draft.patch as AnyRow | null }),
    stagedAt: draft.updatedAt.toISOString(),
  };
}

export async function loadDrafts(
  entity: DraftEntity,
  db: Db = prisma,
): Promise<Map<string, ContentDraft>> {
  const drafts = await (db as typeof prisma).contentDraft.findMany({ where: { entity } });
  return new Map(drafts.map((d) => [d.entityId, d]));
}

export async function loadAllDrafts(db: Db = prisma): Promise<ContentDraft[]> {
  return (db as typeof prisma).contentDraft.findMany({ orderBy: { createdAt: "asc" } });
}

/** Materialises a staged CREATE into a row shaped like the live table's. */
export function rowFromCreate(entity: DraftEntity, draft: ContentDraft): AnyRow {
  const spec = specFor(entity);
  return {
    ...(spec.defaults ?? {}),
    ...((draft.patch as AnyRow | null) ?? {}),
    id: spec.parseId ? spec.parseId(draft.entityId) : draft.entityId,
    createdAt: draft.createdAt,
    updatedAt: draft.updatedAt,
  };
}

function applyPatch(liveRow: AnyRow, draft: ContentDraft): AnyRow {
  return { ...liveRow, ...(((draft.patch as AnyRow | null) ?? {}) as AnyRow) };
}

export interface ResolveOptions {
  /**
   * Keeps only the rows the caller asked for, applied AFTER merging, so a track
   * whose staged move puts it in another collection lands in the right list.
   */
  filter?: (row: AnyRow) => boolean;
  /** Default true: sort the merged list by effective displayOrder. */
  sort?: boolean;
}

/**
 * Live rows + their drafts + any staged creates, as one list.
 *
 * Rows with a staged deletion stay in the list carrying a DELETE marker rather
 * than vanishing: the admin needs to see what publishing will remove, and needs
 * somewhere to click to take the deletion back.
 */
export async function resolveMany<T extends AnyRow = AnyRow>(
  entity: DraftEntity,
  liveRows: T[],
  options: ResolveOptions = {},
  db: Db = prisma,
): Promise<Resolved<T>[]> {
  const drafts = await loadDrafts(entity, db);
  const out: Resolved<T>[] = [];

  for (const live of liveRows) {
    const draft = drafts.get(String(live.id));
    if (!draft) {
      out.push({ row: live, pending: null });
      continue;
    }
    const row = draft.op === "DELETE" ? live : (applyPatch(live, draft) as T);
    out.push({ row, pending: markerFor(draft) });
  }

  for (const draft of drafts.values()) {
    if (draft.op !== "CREATE") continue;
    out.push({ row: rowFromCreate(entity, draft) as T, pending: markerFor(draft) });
  }

  const filtered = options.filter ? out.filter((r) => options.filter!(r.row)) : out;
  if (options.sort === false) return filtered;

  return filtered.sort((a, b) => {
    const ao = typeof a.row.displayOrder === "number" ? a.row.displayOrder : 0;
    const bo = typeof b.row.displayOrder === "number" ? b.row.displayOrder : 0;
    if (ao !== bo) return ao - bo;
    return String(a.row.id).localeCompare(String(b.row.id));
  });
}

/** One record by id, resolving ids that so far exist only as a staged create. */
export async function resolveOne<T extends AnyRow = AnyRow>(
  entity: DraftEntity,
  id: string,
  db: Db = prisma,
): Promise<Resolved<T> | null> {
  const spec = specFor(entity);
  const draft = await (db as typeof prisma).contentDraft.findUnique({
    where: { entity_entityId: { entity, entityId: id } },
  });

  if (draft?.op === "CREATE") {
    return { row: rowFromCreate(entity, draft) as T, pending: markerFor(draft) };
  }

  const live = await spec
    .delegate(db)
    .findUnique({ where: { id: spec.parseId ? spec.parseId(id) : id } });
  if (!live) return null;
  if (!draft) return { row: live as T, pending: null };

  return {
    row: (draft.op === "DELETE" ? live : applyPatch(live, draft)) as T,
    pending: markerFor(draft),
  };
}

/** Attaches the badge marker to an already-serialized DTO. */
export function withPending<T extends object>(dto: T, pending: PendingMarker | null) {
  return { ...dto, pending };
}
