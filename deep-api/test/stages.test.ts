import { test } from "node:test";
import assert from "node:assert/strict";
import { deriveStageIndex, validateThresholds } from "../src/lib/awardRules.js";

// The seeded oak shape: Seedling 0 / Young 200 / Mature 700 (cumulative).
const OAK = [
  { sunlightRequired: 0, displayOrder: 0 },
  { sunlightRequired: 200, displayOrder: 1 },
  { sunlightRequired: 700, displayOrder: 2 },
];

test("deriveStageIndex walks thresholds inclusively", () => {
  assert.equal(deriveStageIndex(OAK, 0), 0);
  assert.equal(deriveStageIndex(OAK, 199), 0);
  assert.equal(deriveStageIndex(OAK, 200), 1);
  assert.equal(deriveStageIndex(OAK, 699), 1);
  assert.equal(deriveStageIndex(OAK, 700), 2);
});

test("deriveStageIndex stays at the final stage past the last threshold", () => {
  assert.equal(deriveStageIndex(OAK, 701), 2);
  assert.equal(deriveStageIndex(OAK, 1_000_000), 2);
});

test("deriveStageIndex sorts by displayOrder, not array order", () => {
  const scrambled = [OAK[2]!, OAK[0]!, OAK[1]!];
  assert.equal(deriveStageIndex(scrambled, 250), 1);
  assert.equal(deriveStageIndex(scrambled, 700), 2);
});

test("deriveStageIndex degenerate shapes: single stage and empty list", () => {
  assert.equal(deriveStageIndex([{ sunlightRequired: 0, displayOrder: 0 }], 0), 0);
  assert.equal(deriveStageIndex([{ sunlightRequired: 0, displayOrder: 0 }], 9999), 0);
  assert.equal(deriveStageIndex([], 500), 0);
});

test("validateThresholds accepts a strictly increasing ladder starting at 0", () => {
  assert.equal(validateThresholds(OAK), true);
  assert.equal(validateThresholds([{ sunlightRequired: 0, displayOrder: 0 }]), true);
  // Mid-authoring: no stages yet is fine.
  assert.equal(validateThresholds([]), true);
});

test("validateThresholds rejects a first stage above 0", () => {
  assert.equal(validateThresholds([{ sunlightRequired: 100, displayOrder: 0 }]), false);
  assert.equal(
    validateThresholds([
      { sunlightRequired: 50, displayOrder: 0 },
      { sunlightRequired: 200, displayOrder: 1 },
    ]),
    false,
  );
});

test("validateThresholds rejects plateaus and regressions", () => {
  assert.equal(
    validateThresholds([
      { sunlightRequired: 0, displayOrder: 0 },
      { sunlightRequired: 200, displayOrder: 1 },
      { sunlightRequired: 200, displayOrder: 2 },
    ]),
    false,
  );
  assert.equal(
    validateThresholds([
      { sunlightRequired: 0, displayOrder: 0 },
      { sunlightRequired: 700, displayOrder: 1 },
      { sunlightRequired: 200, displayOrder: 2 },
    ]),
    false,
  );
});

test("validateThresholds orders by displayOrder, not array order", () => {
  // Valid ladder handed over scrambled.
  assert.equal(validateThresholds([OAK[1]!, OAK[2]!, OAK[0]!]), true);
  // displayOrder order is what must increase: array order increasing but
  // displayOrder order regressing is invalid.
  assert.equal(
    validateThresholds([
      { sunlightRequired: 0, displayOrder: 0 },
      { sunlightRequired: 200, displayOrder: 2 },
      { sunlightRequired: 700, displayOrder: 1 },
    ]),
    false,
  );
});
