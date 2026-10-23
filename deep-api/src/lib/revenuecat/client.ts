// Server-side read of a customer's standing from RevenueCat's REST API — the
// only way deep-api learns entitlement facts outside a webhook. The client app
// can ask for a refresh, but never supplies the facts itself.
//
// GET https://api.revenuecat.com/v1/subscribers/{app_user_id}
// https://www.revenuecat.com/docs/api-v1#tag/customers
import { ApiError } from "../errors.js";
import type { SubscriptionState } from "./derive.js";

const API_BASE = "https://api.revenuecat.com/v1";
const TIMEOUT_MS = 8_000;

type RestEntitlement = {
  expires_date?: string | null;
  grace_period_expires_date?: string | null;
  product_identifier?: string | null;
  purchase_date?: string | null;
};

type RestSubscription = {
  expires_date?: string | null;
  grace_period_expires_date?: string | null;
  period_type?: string | null;
  store?: string | null;
  is_sandbox?: boolean | null;
  unsubscribe_detected_at?: string | null;
  billing_issues_detected_at?: string | null;
  refunded_at?: string | null;
};

type RestNonSubscription = { store?: string | null; is_sandbox?: boolean | null };

export type RestSubscriber = {
  entitlements?: Record<string, RestEntitlement>;
  subscriptions?: Record<string, RestSubscription>;
  non_subscriptions?: Record<string, RestNonSubscription[]>;
};

function isoDate(s: string | null | undefined): Date | null {
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * Map a REST subscriber onto the same state shape the webhook path derives.
 * Null when RevenueCat has never granted this entitlement to the customer.
 * Pure — `now` stamps a refund whose date RevenueCat did not report.
 */
export function stateFromSubscriber(
  subscriber: RestSubscriber,
  entitlementId: string,
  now: Date,
): SubscriptionState | null {
  const ent = subscriber.entitlements?.[entitlementId];
  if (!ent) return null;
  const productId = ent.product_identifier ?? "unknown";
  const sub = subscriber.subscriptions?.[productId];
  const oneOff = subscriber.non_subscriptions?.[productId]?.at(-1);

  const expiresAt = isoDate(ent.expires_date ?? sub?.expires_date);
  const refundedAt = isoDate(sub?.refunded_at);
  const unsubscribedAt = isoDate(sub?.unsubscribe_detected_at);
  const sandbox = sub?.is_sandbox ?? oneOff?.is_sandbox ?? false;

  return {
    entitlementId,
    productId,
    // REST v1 reports lowercase ("app_store", "trial"); webhooks uppercase.
    store: (sub?.store ?? oneOff?.store ?? "unknown").toUpperCase(),
    environment: sandbox ? "SANDBOX" : "PRODUCTION",
    periodType: (sub?.period_type ?? "normal").toUpperCase(),
    expiresAt,
    gracePeriodExpiresAt: isoDate(ent.grace_period_expires_date ?? sub?.grace_period_expires_date),
    willRenew: Boolean(sub) && expiresAt !== null && !unsubscribedAt && !refundedAt,
    billingIssueDetectedAt: isoDate(sub?.billing_issues_detected_at),
    unsubscribedAt,
    revokedAt: refundedAt ? (refundedAt <= now ? refundedAt : now) : null,
  };
}

/** Fetch a customer from RevenueCat. Throws a 502 ApiError on any failure. */
export async function fetchSubscriber(appUserId: string, secretKey: string): Promise<RestSubscriber> {
  let res: Response;
  try {
    res = await fetch(`${API_BASE}/subscribers/${encodeURIComponent(appUserId)}`, {
      headers: { Authorization: `Bearer ${secretKey}`, Accept: "application/json" },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch {
    throw new ApiError(502, "revenuecat_unavailable", "Could not reach RevenueCat");
  }
  if (!res.ok) {
    throw new ApiError(502, "revenuecat_unavailable", `RevenueCat answered ${res.status}`);
  }
  const body = (await res.json()) as { subscriber?: RestSubscriber };
  return body.subscriber ?? {};
}
