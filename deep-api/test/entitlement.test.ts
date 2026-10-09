import { test } from "node:test";
import assert from "node:assert/strict";
import {
  isPremiumNow,
  serializeEntitlement,
  RENEWAL_SLACK_MS,
  type EntitlementRow,
} from "../src/lib/entitlement.js";

// isPremiumNow is the only place DEEP Premium is decided, so its boundaries are
// pinned here one second either side.

const EXPIRES = new Date("2026-11-01T00:00:00Z");
const SECOND = 1000;
const at = (base: Date, deltaMs: number) => new Date(base.getTime() + deltaMs);

function row(over: Partial<EntitlementRow> = {}): EntitlementRow {
  return {
    productId: "deep.pro.monthly",
    store: "APP_STORE",
    periodType: "NORMAL",
    expiresAt: EXPIRES,
    gracePeriodExpiresAt: null,
    willRenew: false,
    revokedAt: null,
    ...over,
  };
}

test("no subscription is never premium", () => {
  assert.equal(isPremiumNow(null, EXPIRES), false);
  assert.equal(isPremiumNow(undefined, EXPIRES), false);
});

test("a non-expiring grant is premium at any time", () => {
  const lifetime = row({ expiresAt: null });
  assert.equal(isPremiumNow(lifetime, new Date("2099-01-01T00:00:00Z")), true);
});

test("a cancelled subscription ends exactly at expiry", () => {
  const cancelled = row({ willRenew: false });
  assert.equal(isPremiumNow(cancelled, at(EXPIRES, -SECOND)), true, "one second before");
  assert.equal(isPremiumNow(cancelled, EXPIRES), false, "at the instant");
  assert.equal(isPremiumNow(cancelled, at(EXPIRES, SECOND)), false, "one second after");
});

test("renewal slack applies only while the subscription is set to renew", () => {
  const renewing = row({ willRenew: true });
  assert.equal(isPremiumNow(renewing, at(EXPIRES, SECOND)), true, "late renewal webhook");
  assert.equal(isPremiumNow(renewing, at(EXPIRES, RENEWAL_SLACK_MS - SECOND)), true);
  assert.equal(isPremiumNow(renewing, at(EXPIRES, RENEWAL_SLACK_MS + SECOND)), false);
  assert.equal(isPremiumNow(row({ willRenew: false }), at(EXPIRES, SECOND)), false);
});

test("a billing grace period extends access past expiry", () => {
  const grace = at(EXPIRES, 16 * 24 * 3600 * SECOND);
  const inGrace = row({ gracePeriodExpiresAt: grace });
  assert.equal(isPremiumNow(inGrace, at(EXPIRES, SECOND)), true);
  assert.equal(isPremiumNow(inGrace, at(grace, -SECOND)), true);
  assert.equal(isPremiumNow(inGrace, at(grace, SECOND)), false);
});

test("revocation beats a future expiry", () => {
  const refunded = row({ revokedAt: at(EXPIRES, -10 * 24 * 3600 * SECOND), willRenew: true });
  assert.equal(isPremiumNow(refunded, at(EXPIRES, -5 * 24 * 3600 * SECOND)), false);
  assert.equal(isPremiumNow(row({ expiresAt: null, revokedAt: EXPIRES }), EXPIRES), false);
});

test("the default clock is the real one", () => {
  assert.equal(isPremiumNow(row({ expiresAt: at(new Date(), 60 * SECOND) })), true);
  assert.equal(isPremiumNow(row({ expiresAt: at(new Date(), -60 * SECOND) })), false);
});

test("the dev time-travel clock cannot mint premium", async () => {
  // Turn time travel on (before env.ts is first imported) and hold the pause
  // clock in a window well before the row expired. resolveNow() moves; the
  // premium answer must not.
  process.env.ALLOW_TIME_OVERRIDE = "true";
  const { setLiveWindow, resolveNow } = await import("../src/lib/pauseSchedule.js");
  const lapsed = row({ expiresAt: at(new Date(), -60 * SECOND) });
  const past = new Date(Date.now() - 30 * 24 * 3600 * SECOND);
  setLiveWindow({ startsAt: past, endsAt: at(past, 3600 * SECOND) });
  try {
    assert.ok(resolveNow().getTime() < lapsed.expiresAt!.getTime(), "pause clock is travelling");
    assert.equal(isPremiumNow(lapsed), false);
    assert.equal(serializeEntitlement(lapsed).active, false);
  } finally {
    setLiveWindow(null);
  }
});

test("serializeEntitlement: no row is an inactive object, not a missing key", () => {
  assert.deepEqual(serializeEntitlement(null), {
    active: false,
    productId: null,
    expiresAt: null,
    willRenew: false,
    periodType: null,
    inGracePeriod: false,
    store: null,
  });
});

test("serializeEntitlement: wire shape for an active trial and a grace period", () => {
  const trial = serializeEntitlement(
    row({ periodType: "TRIAL", willRenew: true }),
    at(EXPIRES, -SECOND),
  );
  assert.deepEqual(trial, {
    active: true,
    productId: "deep.pro.monthly",
    expiresAt: "2026-11-01T00:00:00.000Z",
    willRenew: true,
    periodType: "TRIAL",
    inGracePeriod: false,
    store: "APP_STORE",
  });

  const grace = serializeEntitlement(
    row({ willRenew: true, gracePeriodExpiresAt: at(EXPIRES, 3 * 24 * 3600 * SECOND) }),
    at(EXPIRES, SECOND),
  );
  assert.equal(grace.active, true);
  assert.equal(grace.inGracePeriod, true);

  const revoked = serializeEntitlement(row({ willRenew: true, revokedAt: EXPIRES }), EXPIRES);
  assert.equal(revoked.active, false);
  assert.equal(revoked.willRenew, false, "a revoked subscription never reports renewing");
});
