// The pure rules of the hearts/sunlight economy: award values, per-kind and
// per-day caps, the day-key window for late-synced sessions and listens, the
// practice days a streak counts, pause-attendance coverage, and plant stage
// derivation. No I/O — everything here is
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

/**
 * The dayKey a finished track's award counts against. Clients that report
 * the moment playback finished (`completedAt`, e.g. a listen queued while
 * offline) count on that local day, up to 48h back; older clients send no
 * timestamp, which means "just now" — today in `timeZone`. A `completedAt`
 * ahead of `now` is a device clock running fast, not a replay: the listen
 * plainly just happened, so it counts today rather than being dropped. Null —
 * award withheld — only for a listen more than 48h old.
 */
export function listenAwardDayKey(
  completedAt: Date | undefined,
  timeZone: string,
  now: Date,
): string | null {
  if (!completedAt || completedAt.getTime() > now.getTime()) return localDate(now, timeZone);
  return sessionAwardDayKey(completedAt, timeZone, now);
}

/** An award ledger row, as much of one as `activityDayKeys` needs. */
export interface ActivityAwardRow {
  kind: AwardKind;
  dayKey: string;
  timezone: string;
  createdAt: Date;
}

/**
 * The user-local days ("YYYY-MM-DD", sorted, unique) on which the member
 * practised outside a DEEP Session — the days that keep a streak alive
 * alongside the sessions the app already knows about. A finished track
 * counts on its dayKey (already user-local); an attended pause on the local
 * date it was granted in the row's timezone, because its dayKey is the
 * global Bangkok pauseDate. Other kinds are not practice and are skipped.
 */
export function activityDayKeys(
  rows: ActivityAwardRow[],
  fallbackTimeZone = "Asia/Bangkok",
): string[] {
  const days = new Set<string>();
  for (const row of rows) {
    if (row.kind === "TRACK_COMPLETED") {
      days.add(row.dayKey);
    } else if (row.kind === "PAUSE_ATTENDED") {
      const tz = isValidTimeZone(row.timezone) ? row.timezone : fallbackTimeZone;
      days.add(localDate(row.createdAt, tz));
    }
  }
  return [...days].sort();
}

// Pause attendance is judged on presence beats (one per heartbeat landing in
// the meditation window). The numbers are tuned for the 20s beat cadence
// already-installed builds use, so a member who sat through the meditation
// earns even when one beat at either edge was dropped or they joined a little
// late — while a member who left early, or only blipped in, still does not.

/** Share of the meditation the member's evidence must cover. */
export const COVERAGE_RATIO = 0.75;
/** How long one beat vouches for presence after it lands (≈ one beat interval). */
export const BEAT_CREDIT_MS = 20_000;
/** Longest gap between beats the beat-count floor tolerates. */
export const MAX_BEAT_GAP_MS = 45_000;
/** The last beat must land within this of the meditation's end. */
export const END_SLACK_MS = 45_000;
/** Beats this soon after the meditation ends still count, clamped to its end. */
export const TAIL_GRACE_MS = 10_000;
/**
 * Beats this soon before the meditation starts still count, clamped to its
 * start — one 20s beat interval, so the lobby beat just before the start
 * stands in for a dropped first in-window beat.
 */
export const HEAD_GRACE_MS = 20_000;

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
 * The fewest beats that can honestly span the required coverage with no gap
 * longer than MAX_BEAT_GAP_MS (never fewer than 3, which rules out a blip):
 * 4 for the 132s meditation, 11 for a 10-minute one.
 */
export function minAttendanceBeats(window: MeditationWindow): number {
  const durationMs = window.endsAt.getTime() - window.startsAt.getTime();
  return Math.max(3, Math.ceil((COVERAGE_RATIO * durationMs) / MAX_BEAT_GAP_MS) + 1);
}

/**
 * Whether an attendance record covers the meditation window: enough beats to
 * prove the app stayed, a last beat near the end, and — crediting the last
 * beat with BEAT_CREDIT_MS of presence — at least COVERAGE_RATIO of the window
 * between the first beat and the end of that credit.
 */
export function attendanceCovers(
  window: MeditationWindow,
  attendance: AttendanceSpan,
): boolean {
  if (attendance.beats < minAttendanceBeats(window)) return false;
  const start = window.startsAt.getTime();
  const end = window.endsAt.getTime();
  const first = attendance.firstSeenAt.getTime();
  const last = attendance.lastSeenAt.getTime();
  if (last < end - END_SLACK_MS) return false;
  const covered = Math.min(end, last + BEAT_CREDIT_MS) - Math.max(start, first);
  return covered >= COVERAGE_RATIO * (end - start);
}

/**
 * The instant a heartbeat at `now` is recorded as attendance evidence: `now`
 * inside the meditation window; the window's start for a beat up to
 * HEAD_GRACE_MS before it (the last lobby beat vouches for being there as it
 * began); the window's end for a beat up to TAIL_GRACE_MS after it (the
 * closing beat often lands just past the end); and null — not evidence —
 * otherwise.
 */
export function attendanceInstant(window: MeditationWindow, now: Date): Date | null {
  const t = now.getTime();
  const start = window.startsAt.getTime();
  const end = window.endsAt.getTime();
  if (t < start - HEAD_GRACE_MS) return null;
  if (t < start) return window.startsAt;
  if (t <= end) return now;
  if (t <= end + TAIL_GRACE_MS) return window.endsAt;
  return null;
}

/** An occurrence, as much of one as the coverage rule needs to see. */
export interface AttendableOccurrence {
  slotId: string;
  phases: { key: string; startsAt: Date; endsAt: Date }[];
}

/**
 * The occurrence a heartbeat at `now` is evidence for, and the instant it is
 * recorded at — searched across the given occurrences (a day's) rather than
 * only the one under way. That matters at the tail: when the feedback phase
 * is zero-length, the occurrence is over the moment its meditation ends, so
 * "the current occurrence" has already moved on while the closing beat is
 * still inside the tail grace.
 */
export function attendanceTarget<O extends AttendableOccurrence>(
  occurrences: O[],
  now: Date,
): { occurrence: O; seenAt: Date } | null {
  for (const occurrence of occurrences) {
    const meditation = occurrence.phases.find((p) => p.key === "meditation");
    if (!meditation) continue;
    const seenAt = attendanceInstant(meditation, now);
    if (seenAt) return { occurrence, seenAt };
  }
  return null;
}

/**
 * The occurrence a member's evidence actually covers today, if any — what the
 * attendance award is granted on when a day holds more than one pause.
 *
 * Evidence is matched slot to slot rather than pooled across the day, and that
 * is the whole point: one span widened over two meditations (the start of the
 * morning, the end of the evening) would satisfy `attendanceCovers` for a
 * window nobody actually sat through. Pairing each span with its own slot makes
 * that impossible to express.
 *
 * The award itself stays per day — the caller keys it on pauseDate, and
 * PAUSE_ATTENDED's perDay of 1 means sitting through both earns once.
 */
export function coveredOccurrence<O extends AttendableOccurrence>(
  occurrences: O[],
  attendances: (AttendanceSpan & { slotId: string })[],
): O | null {
  for (const occurrence of occurrences) {
    const meditation = occurrence.phases.find((p) => p.key === "meditation");
    if (!meditation) continue;
    const attendance = attendances.find((a) => a.slotId === occurrence.slotId);
    if (attendance && attendanceCovers(meditation, attendance)) return occurrence;
  }
  return null;
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
