import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ATTENDANCE_EDGE_SLACK_MS,
  ATTENDANCE_MIN_BEATS,
  attendanceCovers,
} from "../src/lib/awardRules.js";

// A real-shaped meditation window: 132s, matching the seeded config.
const START = new Date("2026-08-20T13:40:00.000Z");
const END = new Date(START.getTime() + 132_000);
const WINDOW = { startsAt: START, endsAt: END };

const at = (base: Date, offsetMs: number) => new Date(base.getTime() + offsetMs);

function span(firstMs: number, lastMs: number, beats = ATTENDANCE_MIN_BEATS) {
  return { firstSeenAt: at(START, firstMs), lastSeenAt: at(END, lastMs), beats };
}

test("full coverage with enough beats qualifies", () => {
  assert.equal(attendanceCovers(WINDOW, span(-5_000, 5_000, 7)), true);
  // Exactly on the window edges also qualifies.
  assert.equal(attendanceCovers(WINDOW, span(0, 0)), true);
});

test("joining within 25s of the start qualifies; a moment later does not", () => {
  assert.equal(attendanceCovers(WINDOW, span(ATTENDANCE_EDGE_SLACK_MS, 0)), true);
  assert.equal(attendanceCovers(WINDOW, span(ATTENDANCE_EDGE_SLACK_MS + 1, 0)), false);
});

test("staying to within 25s of the end qualifies; leaving a moment earlier does not", () => {
  assert.equal(attendanceCovers(WINDOW, span(0, -ATTENDANCE_EDGE_SLACK_MS)), true);
  assert.equal(attendanceCovers(WINDOW, span(0, -ATTENDANCE_EDGE_SLACK_MS - 1)), false);
});

test("both edges at maximum slack together still qualify", () => {
  assert.equal(
    attendanceCovers(WINDOW, span(ATTENDANCE_EDGE_SLACK_MS, -ATTENDANCE_EDGE_SLACK_MS)),
    true,
  );
});

test("too few beats disqualify even perfect coverage", () => {
  assert.equal(attendanceCovers(WINDOW, span(-5_000, 5_000, ATTENDANCE_MIN_BEATS - 1)), false);
  assert.equal(attendanceCovers(WINDOW, span(-5_000, 5_000, 1)), false);
  assert.equal(attendanceCovers(WINDOW, span(-5_000, 5_000, ATTENDANCE_MIN_BEATS)), true);
});

test("a mid-window blip (late join AND early leave) does not qualify", () => {
  assert.equal(attendanceCovers(WINDOW, span(60_000, -60_000, 10)), false);
});
