// Content rules that must hold at publish time, not just when a field is typed.
// Staging means a value can be edited now and applied much later, so every check
// the routes used to do inline runs again against the state publish will create.
import { formatHms, secondsOfDay } from "../pauseSchedule.js";

export interface PhaseTimes {
  lobbyStart: string;
  welcomeStart: string;
  meditationStart: string;
  windowEnd: string;
}

/** The four Global Pause phase boundaries must be strictly increasing. */
export function phaseTimesIncreasing(t: PhaseTimes): boolean {
  const order = [t.lobbyStart, t.welcomeStart, t.meditationStart, t.windowEnd];
  return order.every((time, i) => i === 0 || order[i - 1]! < time);
}

export const PHASE_ORDER_MESSAGE = "Phase times must be strictly increasing.";

export const NO_SLOTS_MESSAGE = "The Global Pause needs at least one session time.";

/**
 * How a session is named in an error an admin has to act on. The meditation
 * start is what the admin screen sorts and thinks by, so "the 08:10 session"
 * points at exactly one row without needing an id anyone can read.
 */
export function slotName(slot: PhaseTimes): string {
  return `the ${slot.meditationStart.slice(0, 5)} session`;
}

/**
 * The meditation ends where its track does (lib/pauseSchedule.ts derives the
 * same instant), so a track longer than the room left in the window is a
 * misconfiguration to name rather than something to silently truncate.
 * Returns the complaint, or null when it fits.
 *
 * The length lives on the config and the window on a slot, so this is a
 * cross-record rule: a longer track can overrun some sessions and not others,
 * and every write path that can move either side has to run it against the
 * whole set. `scheduleProblems` is that one place.
 */
export function meditationOverrun(
  slot: PhaseTimes,
  meditationDurationSeconds: number,
): string | null {
  const end = secondsOfDay(slot.meditationStart) + meditationDurationSeconds;
  if (end < secondsOfDay(slot.windowEnd)) return null;
  return (
    `In ${slotName(slot)}, a ${meditationDurationSeconds}s meditation starting ` +
    `${slot.meditationStart} runs to ${formatHms(end)}, past its window end ` +
    `${slot.windowEnd} — extend that session's window end.`
  );
}

/**
 * Sessions may touch — one window ending exactly where the next begins is well
 * defined, since at that instant the earlier occurrence has ended and the later
 * one wins — but they must not overlap. That is what keeps at most one session
 * live at any moment, which in turn is what lets presence stay a single global
 * tally rather than something scoped per occurrence.
 *
 * Compared as "HH:mm:ss" strings, which is sound: a session cannot wrap past
 * midnight, and a DST step can only compress or widen the gap between two
 * sessions, never invert them. Resist "fixing" this into instant arithmetic
 * over a year of dates.
 */
export function slotOverlap(slots: PhaseTimes[]): string | null {
  const ordered = [...slots].sort((a, b) => a.lobbyStart.localeCompare(b.lobbyStart));
  for (let i = 1; i < ordered.length; i += 1) {
    const prev = ordered[i - 1]!;
    const next = ordered[i]!;
    if (next.lobbyStart < prev.windowEnd) {
      return (
        `${slotName(next)} opens at ${next.lobbyStart}, before ${slotName(prev)} ` +
        `closes at ${prev.windowEnd} — sessions cannot overlap.`
      );
    }
  }
  return null;
}

/** A session that ends after midnight cannot be expressed as wall-clock times. */
export function slotWrapsMidnight(slot: PhaseTimes): boolean {
  return slot.windowEnd <= slot.lobbyStart;
}

/**
 * Presence is in-memory with a 60s TTL (lib/pausePresence.ts), so a session
 * opening within a minute of the previous one closing inherits its stragglers
 * in the live count. Worth saying out loud; not worth refusing.
 */
const PRESENCE_BLEED_SECONDS = 60;

function tightGaps(slots: PhaseTimes[]): string[] {
  const ordered = [...slots].sort((a, b) => a.lobbyStart.localeCompare(b.lobbyStart));
  const out: string[] = [];
  for (let i = 1; i < ordered.length; i += 1) {
    const prev = ordered[i - 1]!;
    const next = ordered[i]!;
    const gap = secondsOfDay(next.lobbyStart) - secondsOfDay(prev.windowEnd);
    if (gap >= 0 && gap < PRESENCE_BLEED_SECONDS) {
      out.push(
        `${slotName(next)} opens ${gap}s after ${slotName(prev)} closes; people ` +
          `still counted from the earlier one will show in its live count for up ` +
          `to a minute.`,
      );
    }
  }
  return out;
}

/**
 * Every schedule rule at once, against the set as it will actually stand.
 *
 * The single entry point on purpose: the meditation's length lives on the
 * config and the windows live on the slots, so no rule here can be checked
 * against one record in isolation. Both the admin write path (against live rows
 * overlaid with every staged draft) and the publish path (against live rows
 * overlaid with the *chosen* drafts) call this — different sets, same rules.
 */
export function scheduleProblems(
  slots: PhaseTimes[],
  meditationDurationSeconds: number,
): { blockers: string[]; warnings: string[] } {
  const blockers: string[] = [];

  if (slots.length === 0) blockers.push(NO_SLOTS_MESSAGE);

  for (const slot of slots) {
    if (slotWrapsMidnight(slot)) {
      blockers.push(
        `${slotName(slot)} ends at ${slot.windowEnd}, at or before it opens at ` +
          `${slot.lobbyStart} — a session cannot run past midnight.`,
      );
      continue;
    }
    if (!phaseTimesIncreasing(slot)) {
      blockers.push(`In ${slotName(slot)}: ${PHASE_ORDER_MESSAGE}`);
      continue;
    }
    const overrun = meditationOverrun(slot, meditationDurationSeconds);
    if (overrun) blockers.push(overrun);
  }

  const overlap = slotOverlap(slots);
  if (overlap) blockers.push(overlap);

  return { blockers, warnings: tightGaps(slots) };
}
