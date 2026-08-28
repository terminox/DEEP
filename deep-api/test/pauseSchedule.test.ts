import { test } from "node:test";
import assert from "node:assert/strict";
import type { PauseConfig } from "@prisma/client";
import {
  formatHms,
  occurrenceOn,
  resolveOccurrence,
  secondsOfDay,
} from "../src/lib/pauseSchedule.js";

// The config is a plain row; only the fields the schedule reads matter here.
function config(overrides: Partial<PauseConfig> = {}): PauseConfig {
  return {
    id: 1,
    timezone: "Asia/Bangkok",
    lobbyStart: "20:30:00",
    welcomeStart: "20:39:50",
    meditationStart: "20:40:00",
    windowEnd: "21:00:00",
    lobbyAudioPath: "/media/audio/global-pause.mp3",
    meditationAudioPath: "/media/audio/global-pause.mp3",
    meditationDurationSeconds: 132,
    updatedAt: new Date("2026-08-27T00:00:00Z"),
    ...overrides,
  } as PauseConfig;
}

const phase = (c: PauseConfig, key: string) =>
  occurrenceOn(c, "2026-08-27").phases.find((p) => p.key === key)!;

const spanSeconds = (c: PauseConfig, key: string) => {
  const p = phase(c, key);
  return (p.endsAt.getTime() - p.startsAt.getTime()) / 1000;
};

test("the meditation lasts exactly as long as its track", () => {
  assert.equal(spanSeconds(config(), "meditation"), 132);
  assert.equal(spanSeconds(config({ meditationDurationSeconds: 600 }), "meditation"), 600);
});

test("a longer track moves the end without touching any other phase", () => {
  // The bug this replaces: a new 10-minute track left the window at the old
  // 132 s, so every client cut the session at 2:12.
  const before = config();
  const after = config({ meditationDurationSeconds: 600 });
  for (const key of ["lobby", "welcome"]) {
    assert.deepEqual(phase(before, key), phase(after, key));
  }
  assert.equal(phase(after, "meditation").endsAt.toISOString(), "2026-08-27T13:50:00.000Z");
});

test("feedback starts the instant the meditation ends", () => {
  const c = config({ meditationDurationSeconds: 600 });
  assert.equal(
    phase(c, "feedback").startsAt.getTime(),
    phase(c, "meditation").endsAt.getTime(),
  );
  assert.equal(phase(c, "feedback").endsAt.toISOString(), "2026-08-27T14:00:00.000Z");
});

test("phases stay contiguous and strictly increasing", () => {
  const phases = occurrenceOn(config({ meditationDurationSeconds: 600 }), "2026-08-27").phases;
  assert.deepEqual(
    phases.map((p) => p.key),
    ["lobby", "welcome", "meditation", "feedback"],
  );
  for (const [i, p] of phases.entries()) {
    assert.ok(p.endsAt > p.startsAt, `${p.key} must have positive length`);
    if (i > 0) assert.equal(p.startsAt.getTime(), phases[i - 1]!.endsAt.getTime());
  }
});

test("a track that overruns the window clamps instead of inverting the phases", () => {
  // The write path rejects this, but a row predating that check must not
  // produce a negative-length feedback phase.
  const c = config({ meditationDurationSeconds: 3 * 3600 });
  const meditation = phase(c, "meditation");
  const feedback = phase(c, "feedback");
  assert.equal(meditation.endsAt.toISOString(), "2026-08-27T14:00:00.000Z");
  assert.equal(feedback.endsAt.getTime(), feedback.startsAt.getTime());
  assert.ok(feedback.endsAt >= feedback.startsAt);
});

test("seconds are added to the instant, so the window survives a DST step", () => {
  // 2026-11-01: New York falls back 02:00 -> 01:00 local. A meditation starting
  // 01:30 local and running 40 min ends at a real 40 minutes later, not at the
  // wall-clock string "02:10" that the clock passes through twice.
  const c = config({
    timezone: "America/New_York",
    lobbyStart: "01:00:00",
    welcomeStart: "01:29:50",
    meditationStart: "01:30:00",
    windowEnd: "23:00:00",
    meditationDurationSeconds: 40 * 60,
  });
  assert.equal(spanSeconds(c, "meditation"), 40 * 60);
});

test("resolveOccurrence rolls to tomorrow only once the whole window has ended", () => {
  const c = config({ meditationDurationSeconds: 600 });
  // 13:59:59Z is 20:59:59 in Bangkok - still inside tonight's window.
  assert.equal(resolveOccurrence(c, new Date("2026-08-27T13:59:59Z")).pauseDate, "2026-08-27");
  assert.equal(resolveOccurrence(c, new Date("2026-08-27T14:00:00Z")).pauseDate, "2026-08-28");
});

test("phaseAt reports the meditation across the full new window", () => {
  const c = config({ meditationDurationSeconds: 600 });
  const occurrence = resolveOccurrence(c, new Date("2026-08-27T13:45:00Z"));
  // 13:42:12Z is where the old hand-set end used to sit; it is mid-meditation now.
  assert.equal(occurrence.phaseAt(new Date("2026-08-27T13:42:12Z")), "meditation");
  assert.equal(occurrence.phaseAt(new Date("2026-08-27T13:49:59Z")), "meditation");
  assert.equal(occurrence.phaseAt(new Date("2026-08-27T13:50:00Z")), "feedback");
});

test("secondsOfDay and formatHms round-trip", () => {
  assert.equal(secondsOfDay("20:40:00"), 74_400);
  assert.equal(secondsOfDay("00:00:00"), 0);
  assert.equal(formatHms(secondsOfDay("20:40:00") + 600), "20:50:00");
  assert.equal(formatHms(secondsOfDay("20:42:12")), "20:42:12");
  // Past midnight wraps rather than printing an impossible hour.
  assert.equal(formatHms(secondsOfDay("23:50:00") + 900), "00:05:00");
});
