// Pure translation from a RevenueCat webhook event to the Subscription row it
// implies. No I/O, no clock — everything comes from the payload.
//
// The resulting state is read from the payload's own fields (expiration,
// grace period, period type, store, environment, product). The event type is
// used only to *classify*: does it grant/extend access, is it metadata that
// leaves access running, does it revoke access now, is it a transfer, or is it
// something we do not know? RevenueCat ships new types, so "unknown" is a
// normal answer, never an error.
//
// Event format: https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields

/** The subset of a RevenueCat webhook `event` object we read. */
export type RevenueCatEvent = {
  id: string;
  type: string;
  app_user_id?: string | null;
  original_app_user_id?: string | null;
  aliases?: string[] | null;
  product_id?: string | null;
  new_product_id?: string | null;
  entitlement_ids?: string[] | null;
  /** Deprecated single-entitlement field; still read as a fallback. */
  entitlement_id?: string | null;
  period_type?: string | null;
  purchased_at_ms?: number | null;
  expiration_at_ms?: number | null;
  grace_period_expiration_at_ms?: number | null;
  event_timestamp_ms?: number | null;
  environment?: string | null;
  store?: string | null;
  cancel_reason?: string | null;
  expiration_reason?: string | null;
  transferred_from?: string[] | null;
  transferred_to?: string[] | null;
};

export type RevenueCatWebhookBody = { api_version?: string; event: RevenueCatEvent };

/** Everything a Subscription row holds apart from user, CAS key and bookkeeping. */
export type SubscriptionState = {
  entitlementId: string;
  productId: string;
  store: string;
  environment: string;
  periodType: string;
  expiresAt: Date | null;
  gracePeriodExpiresAt: Date | null;
  willRenew: boolean;
  billingIssueDetectedAt: Date | null;
  unsubscribedAt: Date | null;
  revokedAt: Date | null;
};

export type EventClass = "grant" | "metadata" | "revoke" | "transfer" | "ignored" | "unknown";

const GRANT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
  "REFUND_REVERSED",
]);
// Access keeps running until the payload's own expiry (+ grace).
const METADATA_TYPES = new Set([
  "CANCELLATION", // auto-renew turned off — unless it is a refund, see below
  "UNCANCELLATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
  "PRODUCT_CHANGE",
]);
// Known types that never concern an entitlement's standing.
const IGNORED_TYPES = new Set([
  "TEST",
  "SUBSCRIBER_ALIAS",
  "INVOICE_ISSUANCE",
  "VIRTUAL_CURRENCY_TRANSACTION",
]);

/** RevenueCat's cancel_reason for a refund issued through support/the store. */
const REFUND_CANCEL_REASON = "CUSTOMER_SUPPORT";

export function classifyEvent(event: Pick<RevenueCatEvent, "type" | "cancel_reason">): EventClass {
  const type = event.type;
  if (type === "CANCELLATION" && event.cancel_reason === REFUND_CANCEL_REASON) return "revoke";
  if (type === "EXPIRATION") return "revoke";
  if (type === "TRANSFER") return "transfer";
  if (GRANT_TYPES.has(type)) return "grant";
  if (METADATA_TYPES.has(type)) return "metadata";
  if (IGNORED_TYPES.has(type)) return "ignored";
  return "unknown";
}

export type Derivation =
  | { kind: "state"; eventClass: "grant" | "metadata" | "revoke"; state: SubscriptionState }
  | { kind: "transfer"; from: string[]; to: string[] }
  /** A known type, or an event for a different entitlement — nothing to apply. */
  | { kind: "irrelevant" }
  /** A type we do not know, or a payload too malformed to trust. */
  | { kind: "unknown" };

function msDate(ms: number | null | undefined): Date | null {
  return typeof ms === "number" && Number.isFinite(ms) ? new Date(ms) : null;
}

/** When the event happened, per RevenueCat — the compare-and-set key. */
export function eventTimestamp(event: RevenueCatEvent): Date {
  return (
    msDate(event.event_timestamp_ms) ??
    msDate(event.purchased_at_ms) ??
    // No timestamp at all: treat as older than anything applied, so it can
    // never overwrite real state.
    new Date(0)
  );
}

function concernsEntitlement(event: RevenueCatEvent, entitlementId: string): boolean {
  if (Array.isArray(event.entitlement_ids)) return event.entitlement_ids.includes(entitlementId);
  return event.entitlement_id === entitlementId;
}

// Only these may stand without an expiry (a lifetime purchase / promotional
// grant). A subscription event with no expiration is malformed, and treating it
// as non-expiring would hand out premium forever.
function mayBeNonExpiring(event: RevenueCatEvent): boolean {
  return event.type === "NON_RENEWING_PURCHASE" || event.store === "PROMOTIONAL";
}

export function deriveFromEvent(event: RevenueCatEvent, entitlementId: string): Derivation {
  const eventClass = classifyEvent(event);

  if (eventClass === "unknown") return { kind: "unknown" };
  if (eventClass === "ignored") return { kind: "irrelevant" };
  if (eventClass === "transfer") {
    // Transfers carry no product data: the from side loses access, the to
    // side's standing has to be fetched.
    return {
      kind: "transfer",
      from: (event.transferred_from ?? []).filter((s) => typeof s === "string"),
      to: (event.transferred_to ?? []).filter((s) => typeof s === "string"),
    };
  }
  if (!concernsEntitlement(event, entitlementId)) return { kind: "irrelevant" };

  const at = eventTimestamp(event);
  const expiresAt = msDate(event.expiration_at_ms);
  if (expiresAt === null && eventClass !== "revoke" && !mayBeNonExpiring(event)) {
    return { kind: "unknown" };
  }

  const productId =
    (event.type === "PRODUCT_CHANGE" ? event.new_product_id : null) ?? event.product_id ?? "unknown";

  const base: SubscriptionState = {
    entitlementId,
    productId,
    store: event.store ?? "UNKNOWN",
    environment: event.environment ?? "PRODUCTION",
    periodType: event.period_type ?? "NORMAL",
    expiresAt,
    gracePeriodExpiresAt: msDate(event.grace_period_expiration_at_ms),
    willRenew: false,
    billingIssueDetectedAt: null,
    unsubscribedAt: null,
    revokedAt: null,
  };

  if (eventClass === "grant") {
    return {
      kind: "state",
      eventClass,
      state: {
        ...base,
        // A one-off purchase or a non-expiring grant has nothing to renew.
        willRenew: event.type !== "NON_RENEWING_PURCHASE" && expiresAt !== null,
      },
    };
  }

  if (eventClass === "revoke") {
    // Refund or expiry: access ends now, whatever expiry the payload names.
    return { kind: "state", eventClass, state: { ...base, willRenew: false, revokedAt: at } };
  }

  // Metadata: access keeps running to the payload's expiry (+ grace).
  const state = { ...base };
  switch (event.type) {
    case "CANCELLATION":
      state.willRenew = false;
      if (event.cancel_reason === "BILLING_ERROR") state.billingIssueDetectedAt = at;
      else state.unsubscribedAt = at;
      break;
    case "BILLING_ISSUE":
      // The store keeps retrying; it renews if the payment method recovers.
      state.willRenew = true;
      state.billingIssueDetectedAt = at;
      break;
    case "SUBSCRIPTION_PAUSED":
      state.willRenew = false;
      break;
    default: // UNCANCELLATION, PRODUCT_CHANGE
      state.willRenew = true;
  }
  return { kind: "state", eventClass, state };
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Whether an app user id could be a DEEP User.id (anonymous RC ids never are). */
export function isDeepUserId(id: unknown): id is string {
  return typeof id === "string" && UUID_RE.test(id);
}

/**
 * The ids to try, in order, when finding the DEEP user an event is about:
 * app_user_id, then its aliases, then original_app_user_id. Anything that is
 * not uuid-shaped (e.g. `$RCAnonymousID:…`) is dropped before any query.
 */
export function candidateUserIds(event: RevenueCatEvent): string[] {
  const ordered = [event.app_user_id, ...(event.aliases ?? []), event.original_app_user_id];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const id of ordered) {
    if (!isDeepUserId(id)) continue;
    const key = id.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(key);
  }
  return out;
}
