import { test } from "node:test";
import assert from "node:assert/strict";
import {
  AWARD_CONFIG,
  DAILY_HEARTS_CAP,
  decideAward,
} from "../src/lib/awardRules.js";

test("AWARD_CONFIG carries the confirmed product values", () => {
  assert.deepEqual(AWARD_CONFIG.SESSION_COMPLETED, { hearts: 1, sunlight: 1, perDay: 4 });
  assert.deepEqual(AWARD_CONFIG.TRACK_COMPLETED, { hearts: 1, sunlight: 1, perDay: 3 });
  assert.deepEqual(AWARD_CONFIG.PAUSE_ATTENDED, { hearts: 5, sunlight: 5, perDay: 1 });
  assert.deepEqual(AWARD_CONFIG.PEACE_MESSAGE, { hearts: 1, sunlight: 1, perDay: 1 });
  // Reserved for the deferred daily check-in; no endpoint grants it yet.
  assert.deepEqual(AWARD_CONFIG.DAILY_CHECKIN, { hearts: 1, sunlight: 1, perDay: 1 });
  assert.equal(DAILY_HEARTS_CAP, 30);
});

test("decideAward grants the configured value under both caps", () => {
  const d = decideAward("SESSION_COMPLETED", 0, 0);
  assert.deepEqual(d, { granted: true, hearts: 1, sunlight: 1, cappedBy: null });
  const pause = decideAward("PAUSE_ATTENDED", 0, 10);
  assert.deepEqual(pause, { granted: true, hearts: 5, sunlight: 5, cappedBy: null });
});

test("decideAward enforces the per-kind daily count", () => {
  // 4th session of the day (count 3) still grants; the 5th does not.
  assert.equal(decideAward("SESSION_COMPLETED", 3, 0).granted, true);
  const capped = decideAward("SESSION_COMPLETED", 4, 0);
  assert.deepEqual(capped, { granted: false, hearts: 0, sunlight: 0, cappedBy: "kind_cap" });

  assert.equal(decideAward("TRACK_COMPLETED", 2, 0).granted, true);
  assert.equal(decideAward("TRACK_COMPLETED", 3, 0).cappedBy, "kind_cap");

  assert.equal(decideAward("PAUSE_ATTENDED", 1, 0).cappedBy, "kind_cap");
  assert.equal(decideAward("PEACE_MESSAGE", 1, 0).cappedBy, "kind_cap");
});

test("decideAward fills the daily cap exactly but never past it", () => {
  // 29 + 1 lands exactly on 30: granted.
  assert.equal(decideAward("SESSION_COMPLETED", 0, DAILY_HEARTS_CAP - 1).granted, true);
  // 30 + 1 would exceed: withheld.
  const over = decideAward("SESSION_COMPLETED", 0, DAILY_HEARTS_CAP);
  assert.deepEqual(over, { granted: false, hearts: 0, sunlight: 0, cappedBy: "daily_cap" });
});

test("decideAward is all-or-nothing when a 5-heart award would truncate", () => {
  // 25 + 5 = 30: fits exactly.
  assert.equal(decideAward("PAUSE_ATTENDED", 0, 25).granted, true);
  // 26 + 5 = 31: grants zero rather than the 4 that would fit.
  const truncated = decideAward("PAUSE_ATTENDED", 0, 26);
  assert.equal(truncated.granted, false);
  assert.equal(truncated.hearts, 0);
  assert.equal(truncated.sunlight, 0);
  assert.equal(truncated.cappedBy, "daily_cap");
});

test("decideAward reports kind_cap when both caps apply", () => {
  const both = decideAward("PAUSE_ATTENDED", 1, DAILY_HEARTS_CAP);
  assert.equal(both.cappedBy, "kind_cap");
});
