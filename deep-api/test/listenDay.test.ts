import { test } from "node:test";
import assert from "node:assert/strict";
import { listenAwardDayKey } from "../src/lib/awardRules.js";

// Which day a finished track's heart counts against.

const BANGKOK = "Asia/Bangkok";
const NEW_YORK = "America/New_York";

test("no completedAt (older clients) means today in the user's zone", () => {
  // 2026-08-20T18:00Z is already the 21st in Bangkok, still the 20th in New York.
  const now = new Date("2026-08-20T18:00:00Z");
  assert.equal(listenAwardDayKey(undefined, BANGKOK, now), "2026-08-21");
  assert.equal(listenAwardDayKey(undefined, NEW_YORK, now), "2026-08-20");
});

test("a retried listen counts on the local day it finished", () => {
  // Finished 23:50 Bangkok on the 20th, delivered after midnight.
  const now = new Date("2026-08-20T17:30:00Z");
  const completedAt = new Date("2026-08-20T16:50:00Z");
  assert.equal(listenAwardDayKey(completedAt, BANGKOK, now), "2026-08-20");
});

test("a listen up to 48h old still places; older earns nothing", () => {
  const now = new Date("2026-08-20T12:00:00Z");
  const exactly = new Date(now.getTime() - 48 * 60 * 60 * 1000);
  const older = new Date(exactly.getTime() - 1);
  assert.equal(listenAwardDayKey(exactly, BANGKOK, now), "2026-08-18");
  assert.equal(listenAwardDayKey(older, BANGKOK, now), null);
});

test("a completedAt ahead of now (a fast device clock) counts today", () => {
  // 2026-08-20T16:58Z is 23:58 in Bangkok; a clock 10 minutes fast stamps the
  // finish just past midnight, but the listen happened today.
  const now = new Date("2026-08-20T16:58:00Z");
  const slightly = new Date(now.getTime() + 60 * 1000);
  const tenMinutes = new Date(now.getTime() + 10 * 60 * 1000);
  const wayAhead = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  assert.equal(listenAwardDayKey(slightly, BANGKOK, now), "2026-08-20");
  assert.equal(listenAwardDayKey(tenMinutes, BANGKOK, now), "2026-08-20");
  assert.equal(listenAwardDayKey(wayAhead, BANGKOK, now), "2026-08-20");
});
