// Content rules that must hold at publish time, not just when a field is typed.
// Staging means a value can be edited now and applied much later, so every check
// the routes used to do inline runs again against the state publish will create.
export interface PhaseTimes {
  lobbyStart: string;
  welcomeStart: string;
  meditationStart: string;
  feedbackStart: string;
  windowEnd: string;
}

/** The five Global Pause phases must be strictly increasing. */
export function phaseTimesIncreasing(t: PhaseTimes): boolean {
  const order = [t.lobbyStart, t.welcomeStart, t.meditationStart, t.feedbackStart, t.windowEnd];
  return order.every((time, i) => i === 0 || order[i - 1]! < time);
}

export const PHASE_ORDER_MESSAGE = "Phase times must be strictly increasing.";
