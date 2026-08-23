// The pure rules of the hearts/sunlight economy: award values, per-kind and
// per-day caps, the day-key window for late-synced sessions, pause-attendance
// coverage, and plant stage derivation. No I/O — everything here is
// unit-testable with plain values; the DB half lives in lib/awards.ts.
import { localDate } from "./pauseSchedule.js";

// Mirrors the Prisma AwardKind enum (string-compatible by construction) so
// this module stays importable without a generated client.
export type AwardKind =
  | "SESSION_COMPLETED"
  | "TRACK_COMPLETED"
  | "PAUSE_ATTENDED"
  | "PEACE_MESSAGE"
  | "DAILY_CHECKIN";

export interface AwardValue {
  hearts: number;
  sunlight: number;
  /** How many awards of this kind one user can earn per dayKey. */
  perDay: number;
}

// Hearts and sunlight are stored separately per kind on purpose: today they
// match everywhere, but the product reserves the right to diverge them.
export const AWARD_CONFIG: Record<AwardKind, AwardValue> = {
  SESSION_COMPLETED: { hearts: 1, sunlight: 1, perDay: 4 },
  TRACK_COMPLETED: { hearts: 1, sunlight: 1, perDay: 3 },
  PAUSE_ATTENDED: { hearts: 5, sunlight: 5, perDay: 1 },
  PEACE_MESSAGE: { hearts: 1, sunlight: 1, perDay: 1 },
  // Reserved: no endpoint grants this yet (daily check-in is deferred).
  DAILY_CHECKIN: { hearts: 1, sunlight: 1, perDay: 1 },
};

/** Hard ceiling on hearts earned per user per (tally) day, across all kinds. */
export const DAILY_HEARTS_CAP = 30;

export type CapReason = "kind_cap" | "daily_cap" | "duplicate";

export interface AwardDecision {
  granted: boolean;
  hearts: number;
  sunlight: number;
  cappedBy: Exclude<CapReason, "duplicate"> | null;
}

/**
 * Decides whether an award of `kind` may be granted given how many of that
 * kind the user already earned today and today's hearts tally. All-or-nothing
 * at the daily cap: if the full value doesn't fit under DAILY_HEARTS_CAP the
 * award grants zero rather than truncating.
 */
export function decideAward(
  kind: AwardKind,
  kindCountToday: number,
  heartsTallyToday: number,
): AwardDecision {
  const value = AWARD_CONFIG[kind];
  if (kindCountToday >= value.perDay) {
    return { granted: false, hearts: 0, sunlight: 0, cappedBy: "kind_cap" };
  }
  if (heartsTallyToday + value.hearts > DAILY_HEARTS_CAP) {
    return { granted: false, hearts: 0, sunlight: 0, cappedBy: "daily_cap" };
  }
  return { granted: true, hearts: value.hearts, sunlight: value.sunlight, cappedBy: null };
}

/** Sessions older than this at sync time earn nothing (still stored). */
export const SESSION_AWARD_MAX_AGE_MS = 48 * 60 * 60 * 1000;
/** Clock-skew slack for sessions stamped slightly in the future. */
export const SESSION_AWARD_FUTURE_SLACK_MS = 5 * 60 * 1000;

/**
 * The dayKey a completed session's award counts against: the user-local
 * calendar date of `completedAt`. Null — award withheld, session still
 * stored — when the session is more than 48h old or more than 5min in the
 * future relative to `now` (a replayed backlog or a broken clock).
 */
export function sessionAwardDayKey(
  completedAt: Date,
  timeZone: string,
  now: Date,
): string | null {
  const age = now.getTime() - completedAt.getTime();
  if (age > SESSION_AWARD_MAX_AGE_MS) return null;
  if (age < -SESSION_AWARD_FUTURE_SLACK_MS) return null;
  return localDate(completedAt, timeZone);
}

/** Presence-beat slack at each edge of the meditation window. */
export const ATTENDANCE_EDGE_SLACK_MS = 25_000;
/** Minimum heartbeats for an attendance to count (rules out a single blip). */
export const ATTENDANCE_MIN_BEATS = 4;

export interface MeditationWindow {
  startsAt: Date;
  endsAt: Date;
}

export interface AttendanceSpan {
  firstSeenAt: Date;
  lastSeenAt: Date;
  beats: number;
}

/**
 * Whether an attendance record covers the meditation window: joined within
 * 25s of the start, still present within 25s of the end, and enough beats in
 * between to prove the app actually stayed.
 */
export function attendanceCovers(
  window: MeditationWindow,
  attendance: AttendanceSpan,
): boolean {
  if (attendance.beats < ATTENDANCE_MIN_BEATS) return false;
  const joinedBy = window.startsAt.getTime() + ATTENDANCE_EDGE_SLACK_MS;
  const stayedUntil = window.endsAt.getTime() - ATTENDANCE_EDGE_SLACK_MS;
  return (
    attendance.firstSeenAt.getTime() <= joinedBy &&
    attendance.lastSeenAt.getTime() >= stayedUntil
  );
}

export interface StageThreshold {
  /** CUMULATIVE sunlight needed to reach the stage; first stage must be 0. */
  sunlightRequired: number;
  displayOrder: number;
}

/**
 * The index (into the displayOrder-sorted stage list) of the stage `sunlight`
 * has reached: the last stage whose threshold is met. Past the final
 * threshold the plant stays in its final form; 0 for an empty stage list.
 */
export function deriveStageIndex(stages: StageThreshold[], sunlight: number): number {
  const ordered = [...stages].sort((a, b) => a.displayOrder - b.displayOrder);
  let index = 0;
  for (let i = 0; i < ordered.length; i += 1) {
    if (ordered[i]!.sunlightRequired <= sunlight) index = i;
  }
  return index;
}

/**
 * Whether a stage list is coherent: in displayOrder order the first threshold
 * is exactly 0 and every later one is strictly greater than its predecessor.
 * An empty list is valid (a plant mid-authoring has no stages yet).
 */
export function validateThresholds(stages: StageThreshold[]): boolean {
  const ordered = [...stages].sort((a, b) => a.displayOrder - b.displayOrder);
  if (ordered.length === 0) return true;
  if (ordered[0]!.sunlightRequired !== 0) return false;
  for (let i = 1; i < ordered.length; i += 1) {
    if (ordered[i]!.sunlightRequired <= ordered[i - 1]!.sunlightRequired) return false;
  }
  return true;
}

/** True when `timeZone` is an IANA zone this runtime can actually resolve. */
export function isValidTimeZone(timeZone: string): boolean {
  if (!timeZone) return false;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone });
    return true;
  } catch {
    return false;
  }
}
