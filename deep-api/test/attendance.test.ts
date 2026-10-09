import { test } from "node:test";
import assert from "node:assert/strict";
import {
  HEAD_GRACE_MS,
  TAIL_GRACE_MS,
  attendanceCovers,
  attendanceInstant,
  attendanceTarget,
  minAttendanceBeats,
} from "../src/lib/awardRules.js";

// A real-shaped meditation window: 132s, matching the seeded config.
const START = new Date("2026-08-20T13:40:00.000Z");
const END = new Date(START.getTime() + 132_000);
const WINDOW = { startsAt: START, endsAt: END };

const at = (offsetMs: number) => new Date(START.getTime() + offsetMs);

// Installed builds beat every 20s, from whenever the member joined.
function cadence(fromMs: number, untilMs: number, everyMs = 20_000): number[] {
  const offsets = [];
  for (let t = fromMs; t <= untilMs; t += everyMs) offsets.push(t);
  return offsets;
}

// What the heartbeat route would have recorded for beats at these offsets
// (ms from the meditation start): only instants attendanceInstant accepts,
// widened into one span exactly as recordAttendance does.
function record(offsets: number[]) {
  const seen = offsets
    .map((o) => attendanceInstant(WINDOW, at(o)))
    .filter((d): d is Date => d != null)
    .map((d) => d.getTime());
  if (seen.length === 0) return null;
  return {
    firstSeenAt: new Date(Math.min(...seen)),
    lastSeenAt: new Date(Math.max(...seen)),
    beats: seen.length,
  };
}

function covers(offsets: number[]): boolean {
  const span = record(offsets);
  return span != null && attendanceCovers(WINDOW, span);
}

const dropLast = (offsets: number[]) => offsets.slice(0, -1);

test("staying for the whole meditation qualifies", () => {
  // Joined in the lobby: beats straddle the window, the first in-window one
  // landing as late as ~20s in.
  assert.equal(covers(cadence(-19_900, 140_000)), true);
  assert.equal(covers(cadence(-5_000, 140_000)), true);
});

test("a full stay still qualifies with its last in-window beat dropped", () => {
  // Worst phase: first in-window beat at 19.9s, the 119.9s beat lost, and no
  // closing beat inside the tail grace.
  assert.equal(covers(dropLast(cadence(19_900, 132_000))), true);
});

test("a full stay still qualifies with a middle beat dropped", () => {
  const beats = cadence(5_000, 140_000).filter((o) => o !== 65_000);
  assert.equal(covers(beats), true);
});

test("a full stay qualifies with its first in-window beat dropped, at every phase", () => {
  // Without the head grace a dropped first beat failed whenever it landed
  // past ~13s in (~35% of phases): the lobby beat just before the start now
  // stands in for it.
  for (let phase = 0; phase < 20_000; phase += 100) {
    const beats = cadence(phase - 20_000, 142_000).filter((o) => o !== phase);
    assert.equal(covers(beats), true, `phase ${phase}ms`);
  }
});

test("a full stay qualifies with both edge beats dropped, at every phase", () => {
  for (let phase = 0; phase < 20_000; phase += 100) {
    const beats = dropLast(cadence(phase - 20_000, 132_000)).filter((o) => o !== phase);
    assert.equal(covers(beats), true, `phase ${phase}ms`);
  }
});

test("joining 30s late qualifies; 36s late does not", () => {
  assert.equal(covers(cadence(30_000, 140_000)), true);
  assert.equal(covers(cadence(36_000, 140_000)), false);
});

test("joining 30s late with the last beat dropped still qualifies", () => {
  assert.equal(covers(dropLast(cadence(30_000, 132_000))), true);
});

test("leaving at 80s does not qualify", () => {
  assert.equal(covers(cadence(0, 80_000)), false);
});

test("a mid-window blip does not qualify", () => {
  assert.equal(covers(cadence(60_000, 72_000, 4_000)), false);
  assert.equal(covers([66_000]), false);
});

test("too few beats disqualify even perfect coverage", () => {
  const min = minAttendanceBeats(WINDOW);
  const span = (beats: number) => ({ firstSeenAt: START, lastSeenAt: END, beats });
  assert.equal(attendanceCovers(WINDOW, span(min - 1)), false);
  assert.equal(attendanceCovers(WINDOW, span(min)), true);
});

test("minAttendanceBeats scales with the meditation length", () => {
  const window = (seconds: number) => ({
    startsAt: START,
    endsAt: new Date(START.getTime() + seconds * 1000),
  });
  assert.equal(minAttendanceBeats(window(60)), 3);
  assert.equal(minAttendanceBeats(window(132)), 4);
  assert.equal(minAttendanceBeats(window(600)), 11);
});

test("lobby beats before the head grace are not evidence", () => {
  // A member who only sat in the lobby and left as the meditation began.
  assert.equal(covers(cadence(-120_000, -1_000)), false);
});

test("attendanceInstant accepts the window, clamps both graces, rejects the rest", () => {
  assert.equal(attendanceInstant(WINDOW, at(-HEAD_GRACE_MS - 1)), null);
  assert.deepEqual(attendanceInstant(WINDOW, at(-HEAD_GRACE_MS)), START);
  assert.deepEqual(attendanceInstant(WINDOW, at(-1)), START);
  assert.deepEqual(attendanceInstant(WINDOW, START), START);
  assert.deepEqual(attendanceInstant(WINDOW, at(60_000)), at(60_000));
  assert.deepEqual(attendanceInstant(WINDOW, END), END);
  assert.deepEqual(attendanceInstant(WINDOW, at(132_001)), END);
  assert.deepEqual(attendanceInstant(WINDOW, at(132_000 + TAIL_GRACE_MS)), END);
  assert.equal(attendanceInstant(WINDOW, at(132_000 + TAIL_GRACE_MS + 1)), null);
});

test("attendanceTarget finds the occurrence a beat belongs to, even once it has ended", () => {
  // Zero-length feedback: the occurrence ends with its meditation, so the
  // closing beat lands after it is "over" — still inside the tail grace.
  const phases = (startMs: number) => [
    { key: "lobby", startsAt: new Date(startMs - 300_000), endsAt: new Date(startMs) },
    { key: "meditation", startsAt: new Date(startMs), endsAt: new Date(startMs + 132_000) },
    { key: "feedback", startsAt: new Date(startMs + 132_000), endsAt: new Date(startMs + 132_000) },
  ];
  const evening = { slotId: "evening", phases: phases(START.getTime()) };
  const night = { slotId: "night", phases: phases(START.getTime() + 3_600_000) };
  const day = [evening, night];

  const closing = attendanceTarget(day, at(132_000 + 5_000));
  assert.equal(closing?.occurrence.slotId, "evening");
  assert.deepEqual(closing?.seenAt, END);

  const lobby = attendanceTarget(day, at(3_600_000 - 10_000));
  assert.equal(lobby?.occurrence.slotId, "night");
  assert.deepEqual(lobby?.seenAt, at(3_600_000));

  assert.equal(attendanceTarget(day, at(1_800_000)), null);
});
