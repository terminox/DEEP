import { test } from "node:test";
import assert from "node:assert/strict";
import {
  NO_SLOTS_MESSAGE,
  scheduleProblems,
  slotOverlap,
  type PhaseTimes,
} from "../src/lib/drafts/validators.js";

// The rules that decide whether a day's session times hold together. Every one
// of them is a rule about the *set*, which is why they live behind one entry
// point that both the admin write path and publish call.

function slot(
  lobbyStart: string,
  welcomeStart: string,
  meditationStart: string,
  windowEnd: string,
): PhaseTimes {
  return { lobbyStart, welcomeStart, meditationStart, windowEnd };
}

const MORNING = slot("08:00:00", "08:09:50", "08:10:00", "08:30:00");
const EVENING = slot("20:30:00", "20:39:50", "20:40:00", "21:00:00");
const TRACK = 132;

const blockers = (slots: PhaseTimes[], duration = TRACK) =>
  scheduleProblems(slots, duration).blockers;

test("two sessions a day, well spaced, are fine", () => {
  const { blockers, warnings } = scheduleProblems([MORNING, EVENING], TRACK);
  assert.deepEqual(blockers, []);
  assert.deepEqual(warnings, []);
});

test("phase times must increase within a session", () => {
  const outOfOrder = slot("20:30:00", "20:20:00", "20:40:00", "21:00:00");
  assert.equal(blockers([outOfOrder]).length, 1);
  assert.match(blockers([outOfOrder])[0]!, /the 20:40 session/);
  assert.match(blockers([outOfOrder])[0]!, /strictly increasing/);
});

test("a meditation longer than its window is refused, and names that session", () => {
  // This is the coupling worth pinning: the track's length lives on the config
  // and the windows live on the sessions, so one upload can overrun some
  // sessions and not others. The morning leaves 20 minutes after 08:10; this
  // evening leaves 50 after 20:40. A 25-minute track fits one and not the other,
  // and the message has to say which.
  const roomyEvening = slot("20:30:00", "20:39:50", "20:40:00", "21:30:00");
  const problems = blockers([MORNING, roomyEvening], 25 * 60);
  assert.equal(problems.length, 1);
  assert.match(problems[0]!, /the 08:10 session/);
  assert.doesNotMatch(problems[0]!, /the 20:40 session/);
});

test("sessions that touch are allowed; a one-second overlap is not", () => {
  const first = slot("08:00:00", "08:09:50", "08:10:00", "08:30:00");
  // Opening exactly as the previous one closes is well defined: at that instant
  // the earlier occurrence has ended and the later one wins.
  assert.equal(slotOverlap([first, slot("08:30:00", "08:39:50", "08:40:00", "09:00:00")]), null);
  assert.notEqual(
    slotOverlap([first, slot("08:29:59", "08:39:50", "08:40:00", "09:00:00")]),
    null,
  );
});

test("overlap is found whatever order the rows arrive in, and across three sessions", () => {
  const a = slot("08:00:00", "08:09:50", "08:10:00", "08:30:00");
  const b = slot("12:00:00", "12:09:50", "12:10:00", "12:30:00");
  const c = slot("12:20:00", "12:29:50", "12:30:00", "13:00:00"); // overlaps b
  assert.notEqual(slotOverlap([a, b, c]), null);
  assert.notEqual(slotOverlap([c, b, a]), null);
  assert.notEqual(slotOverlap([b, a, c]), null);
  assert.equal(slotOverlap([a, b]), null);
});

test("a session that would run past midnight is refused", () => {
  // Wall-clock strings cannot express a wrap, and the resolver leans on that:
  // it never looks at yesterday's occurrences.
  const wraps = slot("23:30:00", "23:39:50", "23:40:00", "00:10:00");
  assert.match(blockers([wraps])[0]!, /cannot run past midnight/);
});

test("the last session time cannot be removed", () => {
  assert.deepEqual(blockers([]), [NO_SLOTS_MESSAGE]);
});

test("sessions less than a minute apart warn about presence bleeding across", () => {
  // Presence is in-memory with a 60s TTL, so the earlier session's stragglers
  // linger in the later one's live count. Worth saying; not worth refusing.
  const back = slot("08:30:30", "08:39:50", "08:40:00", "09:00:00");
  const { blockers, warnings } = scheduleProblems([MORNING, back], TRACK);
  assert.deepEqual(blockers, []);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0]!, /30s after/);
});
