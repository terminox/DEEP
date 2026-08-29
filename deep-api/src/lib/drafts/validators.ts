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

export interface MeditationWindow {
  meditationStart: string;
  windowEnd: string;
  meditationDurationSeconds: number;
}

/**
 * The meditation ends where its track does (lib/pauseSchedule.ts derives the
 * same instant), so a track longer than the room left in the window is a
 * misconfiguration to name rather than something to silently truncate.
 * Returns the complaint, or null when it fits.
 */
export function meditationOverrun(t: MeditationWindow): string | null {
  const end = secondsOfDay(t.meditationStart) + t.meditationDurationSeconds;
  if (end < secondsOfDay(t.windowEnd)) return null;
  return (
    `A ${t.meditationDurationSeconds}s meditation starting ${t.meditationStart} runs to ` +
    `${formatHms(end)}, past the window end ${t.windowEnd} — extend the window end.`
  );
}
