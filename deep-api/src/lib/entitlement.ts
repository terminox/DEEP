// DEEP Premium entitlement: the one place that answers "is this person premium
// right now", and the wire shape the app reads it from.
//
// `isPremiumNow` is the ONLY premium predicate. Every route that gates on
// DEEP Premium goes through it (usually via `requestSubscription` below), never
// by reading Subscription columns itself.
//
// It reads the real wall clock. It must never use pauseSchedule's resolveNow():
// that is the dev time-travel clock, and a clock anyone can move on a dev
// server must not be able to mint premium.
import type { FastifyRequest } from "fastify";
import type { Subscription } from "@prisma/client";
import { prisma } from "../prisma.js";

/** The columns the premium question depends on (a whole row satisfies it). */
export type EntitlementRow = Pick<
  Subscription,
  | "productId"
  | "store"
  | "periodType"
  | "expiresAt"
  | "gracePeriodExpiresAt"
  | "willRenew"
  | "revokedAt"
>;

/**
 * Grace after expiry while the subscription is set to renew, so a renewal
 * webhook that lands a little late does not briefly lock out a paying member.
 * Never applied to a cancelled subscription — that one ends exactly on time.
 */
export const RENEWAL_SLACK_MS = 60 * 60 * 1000;

/** When access ends, or null for a non-expiring grant. Ignores revocation. */
function accessEndsAt(sub: EntitlementRow): Date | null {
  if (sub.expiresAt === null) return null;
  let end = sub.expiresAt.getTime();
  // A billing grace period keeps access past the paid-through date.
  if (sub.gracePeriodExpiresAt && sub.gracePeriodExpiresAt.getTime() > end) {
    end = sub.gracePeriodExpiresAt.getTime();
  }
  if (sub.willRenew) end += RENEWAL_SLACK_MS;
  return new Date(end);
}

export function isPremiumNow(
  sub: EntitlementRow | null | undefined,
  now: Date = new Date(),
): boolean {
  if (!sub) return false;
  // A refund (or other revocation) beats any expiry still in the future.
  if (sub.revokedAt) return false;
  const end = accessEndsAt(sub);
  if (end === null) return true;
  return now.getTime() < end.getTime();
}

export type EntitlementPayload = {
  active: boolean;
  productId: string | null;
  expiresAt: string | null;
  willRenew: boolean;
  /** NORMAL | TRIAL | INTRO | … — lets the app say "Trial". */
  periodType: string | null;
  inGracePeriod: boolean;
  /** APP_STORE | PLAY_STORE | PROMOTIONAL | … — decides "manage in the App Store". */
  store: string | null;
};

/**
 * The `entitlement` key sent beside `user`. A user with no subscription gets an
 * inactive object, never a missing key.
 */
export function serializeEntitlement(
  sub: EntitlementRow | null | undefined,
  now: Date = new Date(),
): EntitlementPayload {
  if (!sub) {
    return {
      active: false,
      productId: null,
      expiresAt: null,
      willRenew: false,
      periodType: null,
      inGracePeriod: false,
      store: null,
    };
  }
  const active = isPremiumNow(sub, now);
  return {
    active,
    productId: sub.productId,
    expiresAt: sub.expiresAt?.toISOString() ?? null,
    willRenew: sub.revokedAt ? false : sub.willRenew,
    periodType: sub.periodType,
    inGracePeriod:
      active &&
      sub.gracePeriodExpiresAt !== null &&
      sub.gracePeriodExpiresAt.getTime() > now.getTime(),
    store: sub.store,
  };
}

// ---- Per-request accessor ---------------------------------------------------

const perRequest = new WeakMap<FastifyRequest, Map<string, Promise<Subscription | null>>>();

/**
 * The caller's Subscription row, loaded at most once per request however many
 * handlers/hooks ask. Defaults to the authenticated user.
 */
export function requestSubscription(
  req: FastifyRequest,
  userId: string | undefined = req.auth?.sub,
): Promise<Subscription | null> {
  if (!userId) return Promise.resolve(null);
  let byUser = perRequest.get(req);
  if (!byUser) {
    byUser = new Map();
    perRequest.set(req, byUser);
  }
  let pending = byUser.get(userId);
  if (!pending) {
    pending = prisma.subscription.findUnique({ where: { userId } });
    byUser.set(userId, pending);
  }
  return pending;
}

/** Forget a memoized row after this request rewrote it. */
export function forgetRequestSubscription(req: FastifyRequest): void {
  perRequest.delete(req);
}

/** Whether the caller is DEEP Premium right now (real clock). */
export async function isRequestPremium(req: FastifyRequest): Promise<boolean> {
  return isPremiumNow(await requestSubscription(req));
}

/** The `entitlement` payload for a user, through the per-request accessor. */
export async function requestEntitlement(
  req: FastifyRequest,
  userId?: string,
): Promise<EntitlementPayload> {
  return serializeEntitlement(await requestSubscription(req, userId));
}
