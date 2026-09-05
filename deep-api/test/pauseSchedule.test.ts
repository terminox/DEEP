import { test } from "node:test";
import assert from "node:assert/strict";
import {
  formatHms,
  occurrenceOn,
  occurrencesOn,
  resolveOccurrence,
  secondsOfDay,
  upcomingOccurrences,
  type PauseSlotTimes,
  type PauseTiming,
} from "../src/lib/pauseSchedule.js";

// Only the two fields the phase math reads; the rest of the config is audio.
function timing(overrides: Partial<PauseTiming> = {}): PauseTiming {
  return { timezone: "Asia/Bangkok", meditationDurationSeconds: 132, ...overrides };
}

function slot(
  id: string,
  lobbyStart: string,
  welcomeStart: string,
  meditationStart: string,
  windowEnd: string,
): PauseSlotTimes {
  return { id, lobbyStart, welcomeStart, meditationStart, windowEnd };
}

// Bangkok is UTC+7 year-round, so every Z instant below is the wall clock - 7h.
const EVENING = slot("evening", "20:30:00", "20:39:50", "20:40:00", "21:00:00");
const MORNING = slot("morning", "08:00:00", "08:09:50", "08:10:00", "08:30:00");

const phase = (t: PauseTiming, key: string, s: PauseSlotTimes = EVENING) =>
  occurrenceOn(t, s, "2026-08-27").phases.find((p) => p.key === key)!;

const spanSeconds = (t: PauseTiming, key: string) => {
  const p = phase(t, key);
  return (p.endsAt.getTime() - p.startsAt.getTime()) / 1000;
};

test("the meditation lasts exactly as long as its track", () => {
  assert.equal(spanSeconds(timing(), "meditation"), 132);
  assert.equal(spanSeconds(timing({ meditationDurationSeconds: 600 }), "meditation"), 600);
});

test("a longer track moves the end without touching any other phase", () => {
  // The bug this replaces: a new 10-minute track left the window at the old
  // 132 s, so every client cut the session at 2:12.
  const before = timing();
  const after = timing({ meditationDurationSeconds: 600 });
  for (const key of ["lobby", "welcome"]) {
    assert.deepEqual(phase(before, key), phase(after, key));
  }
  assert.equal(phase(after, "meditation").endsAt.toISOString(), "2026-08-27T13:50:00.000Z");
});

test("feedback starts the instant the meditation ends", () => {
  const t = timing({ meditationDurationSeconds: 600 });
  assert.equal(
    phase(t, "feedback").startsAt.getTime(),
    phase(t, "meditation").endsAt.getTime(),
  );
  assert.equal(phase(t, "feedback").endsAt.toISOString(), "2026-08-27T14:00:00.000Z");
});

test("phases stay contiguous and strictly increasing", () => {
  const phases = occurrenceOn(
    timing({ meditationDurationSeconds: 600 }),
    EVENING,
    "2026-08-27",
  ).phases;
  assert.deepEqual(
    phases.map((p) => p.key),
    ["lobby", "welcome", "meditation", "feedback"],
  );
  for (const [i, p] of phases.entries()) {
    assert.ok(p.endsAt > p.startsAt, `${p.key} must have positive length`);
    if (i > 0) assert.equal(p.startsAt.getTime(), phases[i - 1]!.endsAt.getTime());
  }
});

test("an occurrence carries the id of the slot it resolves", () => {
  assert.equal(occurrenceOn(timing(), MORNING, "2026-08-27").slotId, "morning");
  assert.equal(occurrenceOn(timing(), EVENING, "2026-08-27").pauseDate, "2026-08-27");
});

test("a track that overruns the window clamps instead of inverting the phases", () => {
  // The write path rejects this, but a row predating that check must not
  // produce a negative-length feedback phase.
  const t = timing({ meditationDurationSeconds: 3 * 3600 });
  const meditation = phase(t, "meditation");
  const feedback = phase(t, "feedback");
  assert.equal(meditation.endsAt.toISOString(), "2026-08-27T14:00:00.000Z");
  assert.equal(feedback.endsAt.getTime(), feedback.startsAt.getTime());
  assert.ok(feedback.endsAt >= feedback.startsAt);
});

test("seconds are added to the instant, so the window survives a DST step", () => {
  // 2026-11-01: New York falls back 02:00 -> 01:00 local. A meditation starting
  // 01:30 local and running 40 min ends at a real 40 minutes later, not at the
  // wall-clock string "02:10" that the clock passes through twice.
  const t = timing({ timezone: "America/New_York", meditationDurationSeconds: 40 * 60 });
  const nightOwl = slot("owl", "01:00:00", "01:29:50", "01:30:00", "23:00:00");
  const meditation = occurrenceOn(t, nightOwl, "2026-11-01").phases.find(
    (p) => p.key === "meditation",
  )!;
  assert.equal((meditation.endsAt.getTime() - meditation.startsAt.getTime()) / 1000, 40 * 60);
});

test("a session inside a spring-forward gap still resolves in order", () => {
  // 2026-03-08: New York springs 02:00 -> 03:00, so 02:10 never happens. All
  // four boundaries shift together, which is what keeps the phases usable.
  const t = timing({ timezone: "America/New_York" });
  const inTheGap = slot("gap", "02:00:00", "02:09:50", "02:10:00", "02:30:00");
  const phases = occurrenceOn(t, inTheGap, "2026-03-08").phases;
  for (const [i, p] of phases.entries()) {
    assert.ok(p.endsAt >= p.startsAt, `${p.key} must not invert`);
    if (i > 0) assert.ok(p.startsAt >= phases[i - 1]!.startsAt);
  }
});

test("occurrencesOn returns the day's sessions in clock order, whatever the row order", () => {
  const occurrences = occurrencesOn(timing(), [EVENING, MORNING], "2026-08-27");
  assert.deepEqual(
    occurrences.map((o) => o.slotId),
    ["morning", "evening"],
  );
});

test("two sessions stay in clock order across a DST step", () => {
  // Fall-back day: the gap between the two widens by an hour but cannot invert
  // them, which is why the overlap validator compares wall-clock strings.
  const t = timing({ timezone: "America/New_York" });
  const early = slot("early", "01:00:00", "01:09:50", "01:10:00", "01:30:00");
  const later = slot("later", "04:00:00", "04:09:50", "04:10:00", "04:30:00");
  const occurrences = occurrencesOn(t, [later, early], "2026-11-01");
  assert.deepEqual(
    occurrences.map((o) => o.slotId),
    ["early", "later"],
  );
});

test("a single session behaves exactly as the old singleton did", () => {
  // The regression pin for the whole multi-session refactor: with one slot,
  // resolveOccurrence is still "today's pause, rolling to tomorrow once the
  // window has ended" to the millisecond.
  const t = timing({ meditationDurationSeconds: 600 });
  const slots = [EVENING];
  // 13:59:59Z is 20:59:59 in Bangkok - still inside tonight's window.
  assert.equal(
    resolveOccurrence(t, slots, new Date("2026-08-27T13:59:59Z"))!.pauseDate,
    "2026-08-27",
  );
  assert.equal(
    resolveOccurrence(t, slots, new Date("2026-08-27T14:00:00Z"))!.pauseDate,
    "2026-08-28",
  );
});

test("resolveOccurrence returns the session now sits inside", () => {
  // 01:11Z is 08:11 Bangkok — one minute into a 132s morning meditation.
  const midMeditation = new Date("2026-08-27T01:11:00Z");
  const resolved = resolveOccurrence(timing(), [MORNING, EVENING], midMeditation)!;
  assert.equal(resolved.slotId, "morning");
  assert.equal(resolved.phaseAt(midMeditation), "meditation");
});

test("the morning session stays resolved through its own reflection phase", () => {
  // 01:25Z is 08:25 Bangkok: the meditation ended at 08:12:12 but the window
  // runs to 08:30, so someone writing their reflection is still inside the
  // morning occurrence — and what comes next is tonight, not tomorrow. This is
  // the case the whole change exists for.
  const writingReflection = new Date("2026-08-27T01:25:00Z");
  const t = timing();
  const slots = [MORNING, EVENING];
  const resolved = resolveOccurrence(t, slots, writingReflection)!;
  assert.equal(resolved.slotId, "morning");
  assert.equal(resolved.phaseAt(writingReflection), "feedback");

  const upcoming = upcomingOccurrences(t, slots, writingReflection);
  assert.equal(upcoming[1]!.slotId, "evening");
  assert.equal(upcoming[1]!.pauseDate, "2026-08-27");
});

test("resolveOccurrence returns the next session later today, not tomorrow's first", () => {
  // 02:00Z is 09:00 Bangkok: the morning window closed at 08:30, and the point
  // of more than one session a day is that the answer is tonight, not tomorrow.
  const resolved = resolveOccurrence(
    timing(),
    [MORNING, EVENING],
    new Date("2026-08-27T02:00:00Z"),
  )!;
  assert.equal(resolved.slotId, "evening");
  assert.equal(resolved.pauseDate, "2026-08-27");
});

test("resolveOccurrence rolls to tomorrow's first session once the last window closes", () => {
  // 14:00Z is 21:00 Bangkok, the instant the evening window ends.
  const resolved = resolveOccurrence(
    timing(),
    [MORNING, EVENING],
    new Date("2026-08-27T14:00:00Z"),
  )!;
  assert.equal(resolved.slotId, "morning");
  assert.equal(resolved.pauseDate, "2026-08-28");
});

test("resolveOccurrence returns null when there are no sessions", () => {
  assert.equal(resolveOccurrence(timing(), [], new Date("2026-08-27T02:00:00Z")), null);
  assert.deepEqual(upcomingOccurrences(timing(), [], new Date("2026-08-27T02:00:00Z")), []);
});

test("upcomingOccurrences opens on the resolved occurrence and looks ahead", () => {
  // The schedule route leans on this: upcoming[0] is what resolveOccurrence
  // would return, and upcoming[1] is what the card counts down to next.
  const now = new Date("2026-08-27T02:00:00Z"); // 09:00 Bangkok
  const t = timing();
  const slots = [MORNING, EVENING];
  const upcoming = upcomingOccurrences(t, slots, now);
  assert.equal(upcoming[0]!.slotId, resolveOccurrence(t, slots, now)!.slotId);
  assert.deepEqual(
    upcoming.map((o) => `${o.pauseDate} ${o.slotId}`),
    ["2026-08-27 evening", "2026-08-28 morning", "2026-08-28 evening"],
  );
});

test("phaseAt reports the meditation across the full new window", () => {
  const t = timing({ meditationDurationSeconds: 600 });
  const occurrence = resolveOccurrence(t, [EVENING], new Date("2026-08-27T13:45:00Z"))!;
  // 13:42:12Z is where the old hand-set end used to sit; it is mid-meditation now.
  assert.equal(occurrence.phaseAt(new Date("2026-08-27T13:42:12Z")), "meditation");
  assert.equal(occurrence.phaseAt(new Date("2026-08-27T13:49:59Z")), "meditation");
  assert.equal(occurrence.phaseAt(new Date("2026-08-27T13:50:00Z")), "feedback");
});

test("phaseAt reports offHours between two sessions of the same day", () => {
  // Not "the day's pause is over" — the middle of a day that holds two.
  const occurrence = resolveOccurrence(
    timing(),
    [MORNING, EVENING],
    new Date("2026-08-27T02:00:00Z"),
  )!;
  assert.equal(occurrence.phaseAt(new Date("2026-08-27T02:00:00Z")), "offHours");
});

test("secondsOfDay and formatHms round-trip", () => {
  assert.equal(secondsOfDay("20:40:00"), 74_400);
  assert.equal(secondsOfDay("00:00:00"), 0);
  assert.equal(formatHms(secondsOfDay("20:40:00") + 600), "20:50:00");
  assert.equal(formatHms(secondsOfDay("20:42:12")), "20:42:12");
  // Past midnight wraps rather than printing an impossible hour.
  assert.equal(formatHms(secondsOfDay("23:50:00") + 900), "00:05:00");
});
