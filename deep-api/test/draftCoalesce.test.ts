import { test } from "node:test";
import assert from "node:assert/strict";
import {
  changedFields,
  coalesce,
  prunePatch,
  sameValue,
} from "../src/lib/drafts/coalesce.js";

test("a first edit stages whatever op it is", () => {
  assert.deepEqual(coalesce(null, { op: "CREATE", patch: { title: "Rain" } }), {
    action: "upsert",
    op: "CREATE",
    patch: { title: "Rain" },
  });
  assert.deepEqual(coalesce(null, { op: "UPDATE", patch: { title: "Rain" } }), {
    action: "upsert",
    op: "UPDATE",
    patch: { title: "Rain" },
  });
  assert.deepEqual(coalesce(null, { op: "DELETE" }), {
    action: "upsert",
    op: "DELETE",
    patch: null,
  });
});

test("editing a staged create keeps it a create and merges the patch", () => {
  const existing = { op: "CREATE" as const, patch: { title: "Rain", subtitle: "Soft" } };
  assert.deepEqual(coalesce(existing, { op: "UPDATE", patch: { title: "Heavy rain" } }), {
    action: "upsert",
    op: "CREATE",
    patch: { title: "Heavy rain", subtitle: "Soft" },
  });
});

test("repeat edits to a live record stay one UPDATE", () => {
  const existing = { op: "UPDATE" as const, patch: { title: "Rain" } };
  assert.deepEqual(coalesce(existing, { op: "UPDATE", patch: { subtitle: "Soft" } }), {
    action: "upsert",
    op: "UPDATE",
    patch: { title: "Rain", subtitle: "Soft" },
  });
});

test("deleting a staged create drops the draft rather than staging a delete", () => {
  // Nothing was ever live, so there is nothing to publish a deletion of.
  const existing = { op: "CREATE" as const, patch: { title: "Rain" } };
  assert.deepEqual(coalesce(existing, { op: "DELETE" }), { action: "clear" });
});

test("deleting an edited live record replaces the edit with the delete", () => {
  const existing = { op: "UPDATE" as const, patch: { title: "Rain" } };
  assert.deepEqual(coalesce(existing, { op: "DELETE" }), {
    action: "upsert",
    op: "DELETE",
    patch: null,
  });
});

test("editing a record whose deletion is staged is refused, not silently undone", () => {
  const existing = { op: "DELETE" as const, patch: null };
  const result = coalesce(existing, { op: "UPDATE", patch: { title: "Rain" } });
  assert.equal(result.action, "reject");
  assert.match(
    result.action === "reject" ? result.reason : "",
    /deletion staged/i,
  );
});

test("staging a delete twice is idempotent", () => {
  const existing = { op: "DELETE" as const, patch: null };
  assert.deepEqual(coalesce(existing, { op: "DELETE" }), {
    action: "upsert",
    op: "DELETE",
    patch: null,
  });
});

test("creating over an existing draft is refused", () => {
  const existing = { op: "UPDATE" as const, patch: { title: "Rain" } };
  assert.equal(coalesce(existing, { op: "CREATE", patch: {} }).action, "reject");
});

test("prunePatch drops fields that already match live", () => {
  const live = { title: "Rain", subtitle: "Soft", isPremium: false };
  assert.deepEqual(prunePatch({ title: "Rain", subtitle: "Loud" }, live), {
    subtitle: "Loud",
  });
});

test("prunePatch leaves nothing when an edit is reverted by hand", () => {
  // Type a new title, change it back: no pending change, no phantom badge.
  const live = { title: "Rain" };
  assert.deepEqual(prunePatch({ title: "Rain" }, live), {});
});

test("prunePatch keeps everything when there is no live row", () => {
  assert.deepEqual(prunePatch({ title: "Rain" }, null), { title: "Rain" });
});

test("an edit that undoes a staged edit clears the draft entirely", () => {
  // Regression: pruning the incoming edit alone is not enough. Staging "Storm"
  // and then staging the live value back leaves a merged patch that still
  // carries "Storm" unless the MERGED patch is what gets pruned - which is why
  // stage.ts prunes after coalescing rather than before.
  const live = { title: "Heavy rain" };
  const staged = { op: "UPDATE" as const, patch: { title: "Storm" } };

  const merged = coalesce(staged, { op: "UPDATE", patch: { title: "Heavy rain" } });
  assert.equal(merged.action, "upsert");
  const mergedPatch = merged.action === "upsert" ? (merged.patch ?? {}) : {};
  assert.deepEqual(mergedPatch, { title: "Heavy rain" });

  // Pruned against live it is empty, so stage.ts drops the draft row.
  assert.deepEqual(prunePatch(mergedPatch, live), {});
});

test("sameValue compares dates by instant and objects structurally", () => {
  assert.equal(sameValue(new Date(1000), new Date(1000)), true);
  assert.equal(sameValue(new Date(1000), new Date(2000)), false);
  assert.equal(sameValue({ a: 1 }, { a: 1 }), true);
  assert.equal(sameValue(null, null), true);
  assert.equal(sameValue(null, undefined), false);
  assert.equal(sameValue(0, false), false);
});

test("changedFields lists the patch keys, and nothing for a delete", () => {
  assert.deepEqual(changedFields({ op: "UPDATE", patch: { title: "a", isActive: false } }), [
    "title",
    "isActive",
  ]);
  assert.deepEqual(changedFields({ op: "DELETE", patch: null }), []);
});
