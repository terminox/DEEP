import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import {
  candidateUserIds,
  classifyEvent,
  deriveFromEvent,
  eventTimestamp,
  type RevenueCatWebhookBody,
  type SubscriptionState,
} from "../src/lib/revenuecat/derive.js";
import { stateFromSubscriber } from "../src/lib/revenuecat/client.js";
import { isPremiumNow } from "../src/lib/entitlement.js";

// State derivation over RevenueCat webhook payloads shaped like the documented
// event format (test/fixtures/revenuecat/*.json).

const ENTITLEMENT = "deep_premium";
const USER = "6f1c2b9e-3d4a-4f5b-8c7d-1e2f3a4b5c6d";
const OTHER = "0b8e4c2a-6d1f-4a3e-9b7c-5e2d8f1a4c6b";

function fixture(name: string): RevenueCatWebhookBody {
  const url = new URL(`./fixtures/revenuecat/${name}.json`, import.meta.url);
  return JSON.parse(fs.readFileSync(url, "utf8"));
}

function stateOf(name: string): { eventClass: string; state: SubscriptionState } {
  const d = deriveFromEvent(fixture(name).event, ENTITLEMENT);
  assert.equal(d.kind, "state", `${name} derives a state`);
  if (d.kind !== "state") throw new Error("unreachable");
  return d;
}

const NOV_1 = new Date("2026-11-01T00:00:00Z");

test("INITIAL_PURCHASE (trial) grants until the payload's expiry", () => {
  const { eventClass, state } = stateOf("initial_purchase");
  assert.equal(eventClass, "grant");
  assert.deepEqual(state, {
    entitlementId: ENTITLEMENT,
    productId: "deep.pro.monthly",
    store: "APP_STORE",
    environment: "PRODUCTION",
    periodType: "TRIAL",
    expiresAt: new Date(1788825600000),
    gracePeriodExpiresAt: null,
    willRenew: true,
    billingIssueDetectedAt: null,
    unsubscribedAt: null,
    revokedAt: null,
  });
  assert.equal(eventTimestamp(fixture("initial_purchase").event).getTime(), 1788220801234);
});

test("RENEWAL extends to the new period and clears any earlier trouble", () => {
  const { eventClass, state } = stateOf("renewal");
  assert.equal(eventClass, "grant");
  assert.equal(state.periodType, "NORMAL");
  assert.equal(state.expiresAt?.toISOString(), NOV_1.toISOString());
  assert.equal(state.willRenew, true);
  assert.equal(state.revokedAt, null);
  assert.equal(state.billingIssueDetectedAt, null);
});

test("CANCELLATION (unsubscribe) is metadata: access runs to expiry, then stops", () => {
  const { eventClass, state } = stateOf("cancellation");
  assert.equal(eventClass, "metadata");
  assert.equal(state.willRenew, false);
  assert.equal(state.unsubscribedAt?.getTime(), 1791072000000);
  assert.equal(state.revokedAt, null);
  assert.equal(isPremiumNow(state, new Date(NOV_1.getTime() - 1000)), true);
  assert.equal(isPremiumNow(state, new Date(NOV_1.getTime() + 1000)), false, "no slack once cancelled");
});

test("a refund CANCELLATION (CUSTOMER_SUPPORT) revokes immediately", () => {
  const { eventClass, state } = stateOf("refund");
  assert.equal(eventClass, "revoke");
  assert.equal(state.revokedAt?.getTime(), 1791417600000);
  assert.equal(state.willRenew, false);
  // The payload still names a future expiry; revocation beats it.
  assert.equal(isPremiumNow(state, new Date(1791417600000 + 1000)), false);
});

test("EXPIRATION revokes", () => {
  const { eventClass, state } = stateOf("expiration");
  assert.equal(eventClass, "revoke");
  assert.ok(state.revokedAt);
  assert.equal(isPremiumNow(state, new Date(1793491260000)), false);
});

test("BILLING_ISSUE keeps access through the grace period", () => {
  const { eventClass, state } = stateOf("billing_issue");
  assert.equal(eventClass, "metadata");
  assert.equal(state.billingIssueDetectedAt?.getTime(), 1793491300000);
  assert.equal(state.gracePeriodExpiresAt?.getTime(), 1794873600000);
  assert.equal(isPremiumNow(state, new Date(1794873600000 - 1000)), true, "inside grace");
  assert.equal(
    isPremiumNow(state, new Date(1794873600000 + 2 * 3600 * 1000)),
    false,
    "past grace (and slack)",
  );
});

test("PRODUCT_CHANGE keeps access and takes the new product id", () => {
  const { eventClass, state } = stateOf("product_change");
  assert.equal(eventClass, "metadata");
  assert.equal(state.productId, "deep.pro.yearly");
  assert.equal(state.willRenew, true);
});

test("TRANSFER carries both sides, no product data", () => {
  const d = deriveFromEvent(fixture("transfer").event, ENTITLEMENT);
  assert.deepEqual(d, {
    kind: "transfer",
    from: [USER, "$RCAnonymousID:8069238d6049ce87cc529853916d624c"],
    to: [OTHER],
  });
});

test("an invented future event type is unknown, not an error", () => {
  const body = fixture("future_thing");
  assert.equal(classifyEvent(body.event), "unknown");
  assert.deepEqual(deriveFromEvent(body.event, ENTITLEMENT), { kind: "unknown" });
});

test("events for another entitlement, and dashboard TEST events, are irrelevant", () => {
  const other = { ...fixture("renewal").event, entitlement_ids: ["something_else"] };
  assert.deepEqual(deriveFromEvent(other, ENTITLEMENT), { kind: "irrelevant" });
  const unmapped = { ...fixture("renewal").event, entitlement_ids: null };
  assert.deepEqual(deriveFromEvent(unmapped, ENTITLEMENT), { kind: "irrelevant" });
  const testEvent = { ...fixture("renewal").event, type: "TEST" };
  assert.deepEqual(deriveFromEvent(testEvent, ENTITLEMENT), { kind: "irrelevant" });
});

test("a subscription event with no expiry is never read as a lifetime grant", () => {
  const broken = { ...fixture("renewal").event, expiration_at_ms: null };
  assert.deepEqual(deriveFromEvent(broken, ENTITLEMENT), { kind: "unknown" });
  const lifetime = {
    ...fixture("initial_purchase").event,
    type: "NON_RENEWING_PURCHASE",
    expiration_at_ms: null,
  };
  const d = deriveFromEvent(lifetime, ENTITLEMENT);
  assert.equal(d.kind, "state");
  if (d.kind === "state") {
    assert.equal(d.state.expiresAt, null);
    assert.equal(d.state.willRenew, false);
  }
});

test("user candidates: app_user_id, aliases, original — uuids only, deduped", () => {
  assert.deepEqual(candidateUserIds(fixture("initial_purchase").event), [USER]);
  assert.deepEqual(
    candidateUserIds({
      id: "x",
      type: "RENEWAL",
      app_user_id: "$RCAnonymousID:abc",
      aliases: [OTHER, "not-a-uuid", USER],
      original_app_user_id: USER,
    }),
    [OTHER, USER],
  );
});

test("REST subscriber maps onto the same state shape", () => {
  const now = new Date("2026-10-10T00:00:00Z");
  const state = stateFromSubscriber(
    {
      entitlements: {
        deep_premium: {
          expires_date: "2026-11-01T00:00:00Z",
          grace_period_expires_date: null,
          product_identifier: "deep.pro.monthly",
          purchase_date: "2026-10-01T00:00:00Z",
        },
      },
      subscriptions: {
        "deep.pro.monthly": {
          expires_date: "2026-11-01T00:00:00Z",
          period_type: "trial",
          store: "app_store",
          is_sandbox: true,
          unsubscribe_detected_at: null,
          billing_issues_detected_at: null,
          refunded_at: null,
        },
      },
    },
    ENTITLEMENT,
    now,
  );
  assert.deepEqual(state, {
    entitlementId: ENTITLEMENT,
    productId: "deep.pro.monthly",
    store: "APP_STORE",
    environment: "SANDBOX",
    periodType: "TRIAL",
    expiresAt: NOV_1,
    gracePeriodExpiresAt: null,
    willRenew: true,
    billingIssueDetectedAt: null,
    unsubscribedAt: null,
    revokedAt: null,
  });
  assert.equal(stateFromSubscriber({ entitlements: {} }, ENTITLEMENT, now), null);
});
