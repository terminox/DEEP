import type { PauseConfig } from "@prisma/client";
import { env } from "../env.js";

// The Global Pause schedule, resolved from wall-clock config into absolute
// instants for one occurrence ("tonight's pause"). All timezone math lives
// here, server-side — clients receive ISO instants and never touch zones.

export type PausePhaseKey = "lobby" | "welcome" | "meditation" | "feedback";
export type PausePhaseOrOff = PausePhaseKey | "offHours";

export interface PhaseWindow {
  key: PausePhaseKey;
  startsAt: Date;
  endsAt: Date;
}

export interface PauseOccurrence {
  /** Calendar date of the pause in the config timezone, "YYYY-MM-DD". */
  pauseDate: string;
  phases: PhaseWindow[];
  phaseAt(now: Date): PausePhaseOrOff;
}

/** Seconds since midnight for an "HH:mm:ss" wall-clock string. */
export function secondsOfDay(hms: string): number {
  const [h = 0, m = 0, s = 0] = hms.split(":").map(Number);
  return h * 3600 + m * 60 + s;
}

/** The inverse of `secondsOfDay`, wrapping past midnight — for error copy. */
export function formatHms(totalSeconds: number): string {
  const t = ((Math.round(totalSeconds) % 86400) + 86400) % 86400;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(Math.floor(t / 3600))}:${pad(Math.floor(t / 60) % 60)}:${pad(t % 60)}`;
}

/** "YYYY-MM-DD" for `instant` in `timeZone` (en-CA gives ISO ordering). */
export function localDate(instant: Date, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(instant);
}

/**
 * The absolute instant of wall-clock `hms` on `dateKey` in `timeZone`.
 *
 * Works without a timezone library: guess via the zone's current UTC offset,
 * then correct by however far the guess's local wall-clock landed from the
 * target. One correction suffices for real zones (Bangkok never shifts, and
 * even DST zones move in whole steps).
 */
function zonedInstant(dateKey: string, hms: string, timeZone: string): Date {
  const targetAsUTC = Date.parse(`${dateKey}T${hms}Z`);
  const guess = new Date(Date.parse(`${dateKey}T00:00:00Z`));

  const wallClockAsUTC = (instant: Date): number => {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    }).formatToParts(instant);
    const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "00";
    // hour12:false can yield "24" at midnight; normalize.
    const hour = get("hour") === "24" ? "00" : get("hour");
    return Date.parse(
      `${get("year")}-${get("month")}-${get("day")}T${hour}:${get("minute")}:${get("second")}Z`,
    );
  };

  let instant = new Date(targetAsUTC - (wallClockAsUTC(guess) - guess.getTime()));
  // One corrective step in case the first guess crossed a zone transition.
  instant = new Date(instant.getTime() + (targetAsUTC - wallClockAsUTC(instant)));
  return instant;
}

/**
 * The phase windows of the pause on one specific calendar date (`dateKey`,
 * "YYYY-MM-DD" in the config timezone) — regardless of whether that night has
 * already ended. Lets the award claim rebuild tonight's meditation window for
 * the rest of the day, after resolveOccurrence has rolled to tomorrow.
 */
export function occurrenceOn(
  config: PauseConfig,
  dateKey: string,
): { pauseDate: string; phases: PhaseWindow[] } {
  const at = (hms: string) => zonedInstant(dateKey, hms, config.timezone);
  const lobbyStart = at(config.lobbyStart);
  const welcomeStart = at(config.welcomeStart);
  const meditationStart = at(config.meditationStart);
  const windowEnd = at(config.windowEnd);
  // The meditation runs exactly as long as its audio: the track *is* the event,
  // so where it ends is derived, never stored. It used to be its own wall-clock
  // column (`feedbackStart`), and a longer track uploaded into an untouched
  // window left the client cutting the session at the old length.
  //
  // Seconds are added to the *instant*, not to the wall-clock string: that is
  // the clock the audio actually plays on, and it stays right across a DST step.
  // Clamped at windowEnd so a misconfigured row can never invert the phases.
  const meditationEnd = new Date(
    Math.min(
      meditationStart.getTime() + config.meditationDurationSeconds * 1000,
      windowEnd.getTime(),
    ),
  );
  return {
    pauseDate: dateKey,
    phases: [
      { key: "lobby", startsAt: lobbyStart, endsAt: welcomeStart },
      { key: "welcome", startsAt: welcomeStart, endsAt: meditationStart },
      { key: "meditation", startsAt: meditationStart, endsAt: meditationEnd },
      { key: "feedback", startsAt: meditationEnd, endsAt: windowEnd },
    ],
  };
}

/**
 * Resolves the occurrence `now` belongs to: today's pause in the config
 * timezone, or tomorrow's once tonight's window has fully ended.
 */
export function resolveOccurrence(config: PauseConfig, now: Date): PauseOccurrence {
  const build = (dateKey: string) => occurrenceOn(config, dateKey);

  let occurrence = build(localDate(now, config.timezone));
  const windowEnd = occurrence.phases[occurrence.phases.length - 1]!.endsAt;
  if (now >= windowEnd) {
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    occurrence = build(localDate(tomorrow, config.timezone));
  }

  return {
    ...occurrence,
    phaseAt(at: Date): PausePhaseOrOff {
      const hit = occurrence.phases.find((p) => at >= p.startsAt && at < p.endsAt);
      return hit?.key ?? "offHours";
    },
  };
}

// Dev-only "always live" switch, set via POST /dev/pause/time-travel. While
// on, resolved time flows from just inside whatever window was opened and
// wraps back to the start on reaching the end — that window stays live until
// switched off, each pass elapsing like a real night. The window held here
// isn't always the meditation itself: it can also be the countdown arc that
// starts 15 minutes before the meditation and runs through its end, so the
// loop carries the card through "counting down" as well as "live". Held in
// memory on purpose: a server restart always returns to real time.
let liveWindow: { startMs: number; durationMs: number; sinceMs: number } | null = null;

/** Keeps a window perpetually open (null returns to real time). */
export function setLiveWindow(window: { startsAt: Date; endsAt: Date } | null): void {
  if (!window) {
    liveWindow = null;
    return;
  }
  const startMs = window.startsAt.getTime() + 2_000;
  liveWindow = {
    startMs,
    // 2s of headroom at both edges so a wrapped instant never touches endsAt.
    durationMs: Math.max(1_000, window.endsAt.getTime() - startMs - 2_000),
    sinceMs: Date.now(),
  };
}

/**
 * The instant "now" for everything Global Pause: the dev live loop when it is
 * on (and the environment allows overrides), otherwise real time.
 *
 * Every `serverNow` a route returns must come from here — clients sync their
 * clock to every response, so one route on real time would tear the loop down.
 */
export function resolveNow(): Date {
  if (!env.ALLOW_TIME_OVERRIDE || !liveWindow) return new Date();
  const elapsed = (Date.now() - liveWindow.sinceMs) % liveWindow.durationMs;
  return new Date(liveWindow.startMs + elapsed);
}
