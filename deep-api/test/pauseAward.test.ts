import { test } from "node:test";
import assert from "node:assert/strict";
import { ATTENDANCE_MIN_BEATS, coveredOccurrence } from "../src/lib/awardRules.js";
import { occurrencesOn, type PauseSlotTimes, type PauseTiming } from "../src/lib/pauseSchedule.js";

// Which of a day's occurrences a member's presence actually covers.
//
// The hazard this guards: attendance spans widen monotonically, so pooling a
// day's presence into one record would let the start of one meditation and the
// end of another add up to "sat through the whole thing" for a window nobody
// sat through. Evidence is therefore matched slot to slot.

const TIMING: PauseTiming = { timezone: "Asia/Bangkok", meditationDurationSeconds: 600 };
const MORNING: PauseSlotTimes = {
  id: "morning",
  lobbyStart: "08:00:00",
  welcomeStart: "08:09:50",
  meditationStart: "08:10:00",
  windowEnd: "08:40:00",
};
const EVENING: PauseSlotTimes = {
  id: "evening",
  lobbyStart: "20:30:00",
  welcomeStart: "20:39:50",
  meditationStart: "20:40:00",
  windowEnd: "21:10:00",
};

const PAUSE_DATE = "2026-08-27";
const TODAY = occurrencesOn(TIMING, [MORNING, EVENING], PAUSE_DATE);

// Bangkok is UTC+7. The morning meditation runs 01:10Z-01:20Z, the evening
// 13:40Z-13:50Z.
const at = (iso: string) => new Date(iso);

function span(slotId: string, firstSeenAt: string, lastSeenAt: string, beats = ATTENDANCE_MIN_BEATS) {
  return { slotId, firstSeenAt: at(firstSeenAt), lastSeenAt: at(lastSeenAt), beats };
}

test("sitting through the morning meditation earns the day's award", () => {
  const covered = coveredOccurrence(TODAY, [
    span("morning", "2026-08-27T01:10:00Z", "2026-08-27T01:20:00Z", 12),
  ]);
  assert.equal(covered?.slotId, "morning");
});

test("sitting through the evening one earns it too", () => {
  const covered = coveredOccurrence(TODAY, [
    span("evening", "2026-08-27T13:40:00Z", "2026-08-27T13:50:00Z", 12),
  ]);
  assert.equal(covered?.slotId, "evening");
});

test("the start of the morning and the end of the evening cover neither", () => {
  // THE regression this whole design exists for. Pooled into one span these two
  // visits read as 01:10Z -> 13:50Z, which trivially brackets both meditations
  // and would have earned a real award for sitting through neither. Kept apart
  // by slot, each visit is judged only against the window it happened in.
  const covered = coveredOccurrence(TODAY, [
    span("morning", "2026-08-27T01:10:00Z", "2026-08-27T01:11:20Z", 5), // left after 80s
    span("evening", "2026-08-27T13:48:40Z", "2026-08-27T13:50:00Z", 5), // arrived for the last 80s
  ]);
  assert.equal(covered, null);
});

test("one span cannot vouch for a session it does not belong to", () => {
  // Full morning coverage, mislabelled onto the evening slot, must not satisfy
  // the morning: the slot id is the whole matching rule.
  const covered = coveredOccurrence(TODAY, [
    span("evening", "2026-08-27T01:10:00Z", "2026-08-27T01:20:00Z", 12),
  ]);
  assert.equal(covered, null);
});

test("attending both sessions still resolves to one occurrence", () => {
  // The award is per day — the caller keys it on pauseDate and PAUSE_ATTENDED
  // is capped at one a day — so this returns the first covered occurrence and
  // the ledger's unique turns any second claim into a duplicate.
  const covered = coveredOccurrence(TODAY, [
    span("morning", "2026-08-27T01:10:00Z", "2026-08-27T01:20:00Z", 12),
    span("evening", "2026-08-27T13:40:00Z", "2026-08-27T13:50:00Z", 12),
  ]);
  assert.equal(covered?.slotId, "morning");
});

test("an occurrence with no evidence at all is not covered", () => {
  assert.equal(coveredOccurrence(TODAY, []), null);
});

test("too few beats never covers, however wide the span", () => {
  const covered = coveredOccurrence(TODAY, [
    span("morning", "2026-08-27T01:10:00Z", "2026-08-27T01:20:00Z", ATTENDANCE_MIN_BEATS - 1),
  ]);
  assert.equal(covered, null);
});
