import { test } from "node:test";
import assert from "node:assert/strict";
import {
  SESSION_AWARD_FUTURE_SLACK_MS,
  SESSION_AWARD_MAX_AGE_MS,
  isValidTimeZone,
  sessionAwardDayKey,
} from "../src/lib/awardRules.js";

const BANGKOK = "Asia/Bangkok";
const NEW_YORK = "America/New_York";

test("sessionAwardDayKey keys on the user-local calendar date", () => {
  const now = new Date("2026-08-20T18:00:00Z");
  // 16:59Z is 23:59 in Bangkok (UTC+7); 17:00Z crosses local midnight.
  assert.equal(sessionAwardDayKey(new Date("2026-08-20T16:59:00Z"), BANGKOK, now), "2026-08-20");
  assert.equal(sessionAwardDayKey(new Date("2026-08-20T17:00:00Z"), BANGKOK, now), "2026-08-21");
});

test("the same instant keys different days in different zones", () => {
  const completedAt = new Date("2026-08-20T17:30:00Z");
  const now = new Date("2026-08-20T18:00:00Z");
  assert.equal(sessionAwardDayKey(completedAt, BANGKOK, now), "2026-08-21");
  assert.equal(sessionAwardDayKey(completedAt, NEW_YORK, now), "2026-08-20");
});

test("48h window: exactly 48h old still awards, a moment older does not", () => {
  const now = new Date("2026-08-20T12:00:00Z");
  const exactly = new Date(now.getTime() - SESSION_AWARD_MAX_AGE_MS);
  const older = new Date(exactly.getTime() - 1_000);
  assert.equal(sessionAwardDayKey(exactly, BANGKOK, now), "2026-08-18");
  assert.equal(sessionAwardDayKey(older, BANGKOK, now), null);
});

test("future guard: 5min of clock skew allowed, more withheld", () => {
  const now = new Date("2026-08-20T12:00:00Z");
  const skewed = new Date(now.getTime() + SESSION_AWARD_FUTURE_SLACK_MS);
  const broken = new Date(skewed.getTime() + 1_000);
  assert.equal(sessionAwardDayKey(skewed, BANGKOK, now), "2026-08-20");
  assert.equal(sessionAwardDayKey(broken, BANGKOK, now), null);
});

test("DST spring-forward (America/New_York, 2026-03-08) keys correctly", () => {
  // After every sampled instant, and within 48h of them all.
  const now = new Date("2026-03-09T04:00:00Z");
  // 23:30 the night before (EST, UTC-5).
  assert.equal(sessionAwardDayKey(new Date("2026-03-08T04:30:00Z"), NEW_YORK, now), "2026-03-07");
  // 01:59 EST, one minute before the clocks jump to 03:00.
  assert.equal(sessionAwardDayKey(new Date("2026-03-08T06:59:00Z"), NEW_YORK, now), "2026-03-08");
  // 03:30 EDT (UTC-4), just after the jump — same local day.
  assert.equal(sessionAwardDayKey(new Date("2026-03-08T07:30:00Z"), NEW_YORK, now), "2026-03-08");
  // 23:30 EDT that evening still keys the DST day.
  assert.equal(sessionAwardDayKey(new Date("2026-03-09T03:30:00Z"), NEW_YORK, now), "2026-03-08");
});

test("DST fall-back (America/New_York, 2026-11-01) keys both 01:30s to one day", () => {
  const now = new Date("2026-11-01T12:00:00Z");
  // 23:59 EDT on Oct 31.
  assert.equal(sessionAwardDayKey(new Date("2026-11-01T03:59:00Z"), NEW_YORK, now), "2026-10-31");
  // 01:30 EDT — the first pass through the repeated hour.
  assert.equal(sessionAwardDayKey(new Date("2026-11-01T05:30:00Z"), NEW_YORK, now), "2026-11-01");
  // 01:30 EST — the second pass; same calendar day, no double-key.
  assert.equal(sessionAwardDayKey(new Date("2026-11-01T06:30:00Z"), NEW_YORK, now), "2026-11-01");
});

test("Bangkok never shifts: day boundary is stable year-round", () => {
  const now = new Date("2026-01-15T12:00:00Z");
  assert.equal(sessionAwardDayKey(new Date("2026-01-14T16:59:59Z"), BANGKOK, now), "2026-01-14");
  assert.equal(sessionAwardDayKey(new Date("2026-01-14T17:00:00Z"), BANGKOK, now), "2026-01-15");
});

test("isValidTimeZone accepts real IANA zones and rejects junk", () => {
  assert.equal(isValidTimeZone("Asia/Bangkok"), true);
  assert.equal(isValidTimeZone("America/New_York"), true);
  assert.equal(isValidTimeZone("UTC"), true);
  assert.equal(isValidTimeZone("Not/AZone"), false);
  assert.equal(isValidTimeZone("blorp"), false);
  assert.equal(isValidTimeZone(""), false);
});
