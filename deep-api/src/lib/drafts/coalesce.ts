// The rules for folding a new admin edit into whatever is already staged for
// that record. Pure and DB-free so the whole table of cases can be unit tested.
import type { DraftOp } from "@prisma/client";
import type { AnyRow } from "./registry.js";

export interface StagedState {
  op: DraftOp;
  patch: AnyRow | null;
}

export type CoalesceResult =
  /** Write this state to the draft row. */
  | { action: "upsert"; op: DraftOp; patch: AnyRow | null }
  /** Remove the draft row: the record is back to matching live. */
  | { action: "clear" }
  | { action: "reject"; reason: string };

/**
 * Folds `incoming` into `existing`.
 *
 * One draft row per record means a burst of edits reads as "this collection
 * changed", not as a keystroke log. The two interesting cases: staging a delete
 * over a staged create just drops the draft (nothing was ever live), and editing
 * a record whose deletion is already staged is refused rather than silently
 * resurrecting it.
 */
export function coalesce(
  existing: StagedState | null,
  incoming: { op: DraftOp; patch?: AnyRow | null },
): CoalesceResult {
  const patch = incoming.patch ?? null;

  if (!existing) {
    return { action: "upsert", op: incoming.op, patch };
  }

  if (existing.op === "DELETE") {
    if (incoming.op === "DELETE") return { action: "upsert", op: "DELETE", patch: null };
    return {
      action: "reject",
      reason: "This record has a deletion staged. Discard that change before editing it.",
    };
  }

  if (incoming.op === "CREATE") {
    return { action: "reject", reason: "This record already exists." };
  }

  if (incoming.op === "DELETE") {
    // A staged create that gets deleted never existed; drop the draft entirely.
    if (existing.op === "CREATE") return { action: "clear" };
    return { action: "upsert", op: "DELETE", patch: null };
  }

  // UPDATE over CREATE keeps it a CREATE; UPDATE over UPDATE stays an UPDATE.
  return {
    action: "upsert",
    op: existing.op,
    patch: { ...(existing.patch ?? {}), ...(patch ?? {}) },
  };
}

/** Structural equality good enough for Prisma scalar columns and Date values. */
export function sameValue(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a instanceof Date && b instanceof Date) return a.getTime() === b.getTime();
  if (a === null || b === null || a === undefined || b === undefined) return false;
  if (typeof a === "object" && typeof b === "object") {
    return JSON.stringify(a) === JSON.stringify(b);
  }
  return false;
}

/**
 * Drops patch keys that already match the live row, so "change a title and
 * change it back" leaves no pending change and the review screen never shows a
 * record whose before and after are identical.
 */
export function prunePatch(patch: AnyRow, liveRow: AnyRow | null): AnyRow {
  if (!liveRow) return patch;
  const pruned: AnyRow = {};
  for (const [key, value] of Object.entries(patch)) {
    if (!sameValue(value, liveRow[key])) pruned[key] = value;
  }
  return pruned;
}

/** The fields a draft actually changes, for the review screen's diff. */
export function changedFields(state: StagedState): string[] {
  if (state.op === "DELETE") return [];
  return Object.keys(state.patch ?? {});
}
