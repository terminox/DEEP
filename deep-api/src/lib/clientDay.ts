// Resolves which calendar day a request belongs to, in the user's own
// timezone. The app sends its IANA zone on every request as X-Device-Timezone;
// routes fall back to the user's last-seen zone, then the pause-config zone.
import type { FastifyRequest } from "fastify";
import { prisma } from "../prisma.js";
import { isValidTimeZone } from "./awardRules.js";
import { localDate } from "./pauseSchedule.js";

export const DEVICE_TIMEZONE_HEADER = "x-device-timezone";

/** Last-resort zone when the header and every fallback are missing/invalid. */
export const DEFAULT_TIMEZONE = "Asia/Bangkok";

/**
 * The request's effective IANA timezone: the validated X-Device-Timezone
 * header, else the first valid fallback (pass the user's stored
 * `User.timezone`, then the pause-config timezone), else Asia/Bangkok.
 */
export function requestTimezone(
  req: FastifyRequest,
  ...fallbacks: Array<string | null | undefined>
): string {
  const raw = req.headers[DEVICE_TIMEZONE_HEADER];
  const header = Array.isArray(raw) ? raw[0] : raw;
  for (const candidate of [header, ...fallbacks]) {
    if (candidate && isValidTimeZone(candidate)) return candidate;
  }
  return DEFAULT_TIMEZONE;
}

/** The "YYYY-MM-DD" dayKey `now` falls on in `timeZone`. */
export function userDayKey(now: Date, timeZone: string): string {
  return localDate(now, timeZone);
}

/**
 * Opportunistically records the device timezone on the user, fire-and-forget:
 * skips no-ops and invalid zones, and swallows failures — a lost update just
 * means the fallback zone is one request staler.
 */
export function rememberTimezone(
  userId: string,
  timeZone: string,
  current?: string | null,
): void {
  if (!isValidTimeZone(timeZone) || timeZone === current) return;
  void prisma.user
    .update({ where: { id: userId }, data: { timezone: timeZone } })
    .catch(() => {
      /* opportunistic — never let this fail a request */
    });
}
