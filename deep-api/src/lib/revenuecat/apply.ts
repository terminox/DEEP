// Applies RevenueCat truth to the database: webhook events (at-least-once,
// unordered) and server-side refreshes.
//
// Webhook rules, in order:
//   1. Record the event under RevenueCat's own id FIRST. A re-delivery
//      collides on that primary key and is a no-op that still answers 200.
//      (Inside the transaction, a concurrent duplicate blocks on the key until
//      the first commits, then sees it.)
//   2. Sandbox events are recorded but only applied when the sandbox flag is on.
//   3. Resolve the user via app_user_id → aliases → original_app_user_id; each
//      must be an existing User.id. Unknown users are recorded, never 4xx'd —
//      a 4xx makes RevenueCat retry forever; the record is the repair trail.
//   4. Write with a compare-and-set on lastEventAt, so an older event arriving
//      late is recorded as STALE and changes nothing.
//   5. Unknown event types are recorded and answered 200.
import crypto from "node:crypto";
import { Prisma, type RevenueCatEventOutcome, type Subscription } from "@prisma/client";
import { prisma } from "../../prisma.js";
import { stateFromSubscriber, fetchSubscriber } from "./client.js";
import {
  candidateUserIds,
  deriveFromEvent,
  eventTimestamp,
  isDeepUserId,
  type RevenueCatWebhookBody,
  type SubscriptionState,
} from "./derive.js";

type Db = Prisma.TransactionClient;

export type ApplyOptions = { entitlementId: string; acceptSandbox: boolean };

export type ApplyResult = {
  outcome: RevenueCatEventOutcome | "DUPLICATE";
  userId: string | null;
  /** Users whose standing must be re-fetched (the receiving side of a transfer). */
  refreshUserIds: string[];
};

/** The first candidate id that is an existing DEEP user, in candidate order. */
async function resolveUser(db: Db, candidates: string[]): Promise<string | null> {
  const found = await existingUsers(db, candidates);
  return found[0] ?? null;
}

async function existingUsers(db: Db, ids: string[]): Promise<string[]> {
  const candidates = ids.filter(isDeepUserId).map((s) => s.toLowerCase());
  if (candidates.length === 0) return [];
  const rows = await db.user.findMany({ where: { id: { in: candidates } }, select: { id: true } });
  const present = new Set(rows.map((r) => r.id));
  return [...new Set(candidates.filter((id) => present.has(id)))];
}

// Prisma's raw Date binding is timestamptz; the columns are UTC timestamps
// without a zone (Prisma's DateTime), so convert explicitly rather than lean
// on the session time zone.
function ts(d: Date | null): Prisma.Sql {
  return Prisma.sql`(${d ? d.toISOString() : null}::timestamptz AT TIME ZONE 'UTC')`;
}

/**
 * Upsert the user's row from `state`, but only if `at` is newer than the event
 * that last wrote it. One statement, so two deliveries racing for the same
 * user cannot both win. Returns whether the row was written.
 */
async function compareAndSet(
  db: Db,
  userId: string,
  s: SubscriptionState,
  at: Date,
): Promise<boolean> {
  const written = await db.$executeRaw`
    INSERT INTO "subscriptions" (
      "id", "userId", "entitlementId", "productId", "store", "environment", "periodType",
      "expiresAt", "gracePeriodExpiresAt", "willRenew", "billingIssueDetectedAt",
      "unsubscribedAt", "revokedAt", "lastEventAt", "createdAt", "updatedAt"
    ) VALUES (
      ${crypto.randomUUID()}, ${userId}, ${s.entitlementId}, ${s.productId}, ${s.store},
      ${s.environment}, ${s.periodType}, ${ts(s.expiresAt)}, ${ts(s.gracePeriodExpiresAt)},
      ${s.willRenew}, ${ts(s.billingIssueDetectedAt)}, ${ts(s.unsubscribedAt)},
      ${ts(s.revokedAt)}, ${ts(at)}, NOW() AT TIME ZONE 'UTC', NOW() AT TIME ZONE 'UTC'
    )
    ON CONFLICT ("userId") DO UPDATE SET
      "entitlementId" = EXCLUDED."entitlementId",
      "productId" = EXCLUDED."productId",
      "store" = EXCLUDED."store",
      "environment" = EXCLUDED."environment",
      "periodType" = EXCLUDED."periodType",
      "expiresAt" = EXCLUDED."expiresAt",
      "gracePeriodExpiresAt" = EXCLUDED."gracePeriodExpiresAt",
      "willRenew" = EXCLUDED."willRenew",
      "billingIssueDetectedAt" = EXCLUDED."billingIssueDetectedAt",
      "unsubscribedAt" = EXCLUDED."unsubscribedAt",
      "revokedAt" = EXCLUDED."revokedAt",
      "lastEventAt" = EXCLUDED."lastEventAt",
      "updatedAt" = EXCLUDED."updatedAt"
    WHERE "subscriptions"."lastEventAt" < EXCLUDED."lastEventAt"`;
  return written > 0;
}

/** Revoke access on rows older than `at` (the losing side of a transfer). */
async function revokeIfOlder(db: Db, userIds: string[], at: Date): Promise<number> {
  if (userIds.length === 0) return 0;
  const { count } = await db.subscription.updateMany({
    where: { userId: { in: userIds }, lastEventAt: { lt: at } },
    data: { revokedAt: at, willRenew: false, lastEventAt: at },
  });
  return count;
}

export async function applyWebhookEvent(
  body: RevenueCatWebhookBody,
  opts: ApplyOptions,
): Promise<ApplyResult> {
  const event = body.event;
  const at = eventTimestamp(event);
  const environment = event.environment ?? "PRODUCTION";
  const derivation = deriveFromEvent(event, opts.entitlementId);

  return prisma.$transaction(async (tx) => {
    // 1. Record first — the primary key is the idempotency key.
    const { count } = await tx.revenueCatEvent.createMany({
      data: [
        {
          id: event.id,
          type: event.type,
          environment,
          appUserId: event.app_user_id ?? "",
          eventAt: at,
          payload: body as unknown as Prisma.InputJsonValue,
          outcome: "APPLIED", // provisional; settled below
        },
      ],
      skipDuplicates: true,
    });
    if (count === 0) return { outcome: "DUPLICATE", userId: null, refreshUserIds: [] };

    let outcome: RevenueCatEventOutcome;
    let userId: string | null;
    let refreshUserIds: string[] = [];

    if (derivation.kind === "transfer") {
      const from = await existingUsers(tx, derivation.from);
      const to = await existingUsers(tx, derivation.to);
      userId = to[0] ?? from[0] ?? null;
      if (!userId) {
        outcome = "UNKNOWN_USER";
      } else if (environment === "SANDBOX" && !opts.acceptSandbox) {
        outcome = "SANDBOX_IGNORED";
      } else {
        await revokeIfOlder(tx, from, at);
        refreshUserIds = to;
        outcome = "APPLIED";
      }
    } else {
      userId = await resolveUser(tx, candidateUserIds(event));
      if (environment === "SANDBOX" && !opts.acceptSandbox) outcome = "SANDBOX_IGNORED";
      else if (derivation.kind === "unknown") outcome = "UNRECOGNISED";
      else if (derivation.kind === "irrelevant") outcome = "IRRELEVANT";
      else if (!userId) outcome = "UNKNOWN_USER";
      else outcome = (await compareAndSet(tx, userId, derivation.state, at)) ? "APPLIED" : "STALE";
    }

    await tx.revenueCatEvent.update({ where: { id: event.id }, data: { outcome, userId } });
    return { outcome, userId, refreshUserIds };
  });
}

export type RefreshOptions = ApplyOptions & { secretKey: string; now?: Date };

/**
 * Re-read a user's standing from RevenueCat's REST API and rewrite their row
 * unconditionally (it is fresher than any event so far, so lastEventAt = now).
 * Returns the row as it now stands, or null when there is none.
 */
export async function refreshSubscription(
  userId: string,
  opts: RefreshOptions,
): Promise<Subscription | null> {
  const now = opts.now ?? new Date();
  const subscriber = await fetchSubscriber(userId, opts.secretKey);
  let state = stateFromSubscriber(subscriber, opts.entitlementId, now);
  // Same gate as the webhook: a sandbox purchase grants nothing once sandbox
  // acceptance is off.
  if (state && state.environment === "SANDBOX" && !opts.acceptSandbox) state = null;

  if (!state) {
    // RevenueCat holds no such entitlement: any row we kept no longer stands.
    await prisma.subscription.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: now, willRenew: false, lastEventAt: now },
    });
    return prisma.subscription.findUnique({ where: { userId } });
  }

  const data = { ...state, lastEventAt: now };
  return prisma.subscription.upsert({
    where: { userId },
    create: { userId, ...data },
    update: data,
  });
}
