// End-to-end proof of the DEEP Premium plumbing: the RevenueCat webhook's
// auth, idempotency and ordering rules, the refresh endpoint, the dev flip
// route, and the `entitlement` key on /me, login and signup.
//
// Drives the real HTTP routes with fastify inject() against a THROWAWAY
// database, and refuses to run against anything not named *_verify / *_test.
// RevenueCat's REST API is never contacted: global fetch is stubbed.
//
//   createdb deep_verify
//   DATABASE_URL="postgresql://.../deep_verify" npx prisma migrate deploy
//   DATABASE_URL="postgresql://.../deep_verify" npm run verify:revenuecat
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";

const dbName = (process.env.DATABASE_URL ?? "").split("?")[0]?.split("/").pop() ?? "";
if (!/_(verify|test)$/.test(dbName)) {
  console.error(
    `Refusing to run against database "${dbName}": name must end in _verify or _test.`,
  );
  process.exit(1);
}

// env.ts parses process.env once at import, so configure before importing
// anything that reaches it. (Real env vars beat .env, which never overrides.)
const WEBHOOK_AUTH = `Bearer verify-${crypto.randomBytes(16).toString("hex")}`;
const SECRET_KEY = "sk_verify_not_a_real_key";
process.env.REVENUECAT_WEBHOOK_AUTH = WEBHOOK_AUTH;
process.env.REVENUECAT_SECRET_API_KEY = SECRET_KEY;
process.env.REVENUECAT_ACCEPT_SANDBOX = "true";
process.env.ALLOW_DEV_ENTITLEMENT = "true";
delete process.env.REVENUECAT_ENTITLEMENT_ID;

const { buildApp } = await import("../src/app.js");
const { prisma } = await import("../src/prisma.js");
const { env } = await import("../src/env.js");
const { hashPassword } = await import("../src/auth/password.js");
const { refreshCooldown } = await import("../src/routes/revenuecat.js");

// Mutable view of the parsed env, for flipping flags mid-run.
const mutableEnv = env as unknown as Record<string, unknown>;

// ---- RevenueCat REST stub ----
type StubSubscriber = Record<string, unknown>;
const restSubscribers = new Map<string, StubSubscriber>();
const restCalls: { url: string; auth: string | null }[] = [];
const realFetch = globalThis.fetch;
globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
  const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
  if (!url.startsWith("https://api.revenuecat.com/")) return realFetch(input, init);
  const auth = new Headers(init?.headers).get("authorization");
  restCalls.push({ url, auth });
  const id = decodeURIComponent(url.split("/subscribers/")[1] ?? "");
  const subscriber = restSubscribers.get(id) ?? { entitlements: {}, subscriptions: {} };
  return new Response(JSON.stringify({ request_date_ms: Date.now(), subscriber }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}) as typeof fetch;

const pass = (msg: string) => console.log(`  ok  ${msg}`);
const json = (res: { body: string }) => JSON.parse(res.body);
const DAY = 24 * 3600 * 1000;
const NOW = Date.now();

function fixtureEvent(name: string): Record<string, unknown> {
  const url = new URL(`../test/fixtures/revenuecat/${name}.json`, import.meta.url);
  return JSON.parse(fs.readFileSync(url, "utf8")).event;
}

/** A fixture event re-aimed at `userId`, with a fresh id and live timestamps. */
function event(name: string, userId: string, over: Record<string, unknown> = {}) {
  return {
    api_version: "1.0",
    event: {
      ...fixtureEvent(name),
      id: crypto.randomUUID().toUpperCase(),
      app_user_id: userId,
      original_app_user_id: "$RCAnonymousID:0123456789abcdef0123456789abcdef",
      aliases: ["$RCAnonymousID:0123456789abcdef0123456789abcdef", userId],
      purchased_at_ms: NOW - 2 * DAY,
      expiration_at_ms: NOW + 28 * DAY,
      event_timestamp_ms: NOW - 2 * DAY,
      ...over,
    },
  };
}

async function main() {
  const app = buildApp();
  await app.ready();

  // null = send no Authorization header at all.
  const post = (body: unknown, authorization: string | null = WEBHOOK_AUTH) =>
    app.inject({
      method: "POST",
      url: "/webhooks/revenuecat",
      headers: authorization === null ? {} : { authorization },
      payload: body as Record<string, unknown>,
    });
  const outcomeOf = async (id: string) =>
    (await prisma.revenueCatEvent.findUnique({ where: { id } }))?.outcome;
  const subOf = (userId: string) => prisma.subscription.findUnique({ where: { userId } });

  // ---- Fixtures: two members via the real signup route, one admin ----
  const tag = crypto.randomBytes(4).toString("hex");
  const signup = async (name: string) => {
    const res = await app.inject({
      method: "POST",
      url: "/auth/signup",
      payload: { email: `${name}-${tag}@deep.test`, password: "password123", displayName: name },
    });
    assert.equal(res.statusCode, 200, `signup ${name}`);
    return json(res);
  };
  const alice = await signup("alice");
  const bob = await signup("bob");
  const aliceId: string = alice.user.id;
  const bobId: string = bob.user.id;
  const asAlice = { authorization: `Bearer ${alice.accessToken}` };
  const asBob = { authorization: `Bearer ${bob.accessToken}` };

  assert.deepEqual(alice.entitlement, {
    active: false,
    productId: null,
    expiresAt: null,
    willRenew: false,
    periodType: null,
    inGracePeriod: false,
    store: null,
  });
  assert.equal("entitlement" in alice.user, false, "entitlement is a sibling, not inside user");
  pass("0. signup returns an inactive entitlement beside user");

  // ---- 1. Bad / missing header: unrevealing 401, no state change ----
  const eventsBefore = await prisma.revenueCatEvent.count();
  const purchase = event("initial_purchase", aliceId, { period_type: "NORMAL" });
  for (const header of [null, "", "Bearer wrong", `${WEBHOOK_AUTH}x`]) {
    const res = await post(purchase, header);
    assert.equal(res.statusCode, 401);
    assert.deepEqual(json(res), {
      error: { code: "unauthorized", message: "Not authenticated" },
    });
  }
  assert.equal(await prisma.revenueCatEvent.count(), eventsBefore, "nothing recorded");
  assert.equal(await subOf(aliceId), null, "nothing applied");
  pass("1. wrong or missing Authorization → 401 with no detail, no state change");

  // ---- 2. A purchase applies; /me reports it ----
  let res = await post(purchase);
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).outcome, "applied");
  const first = await subOf(aliceId);
  assert.ok(first, "subscription row created");
  assert.equal(first.environment, "PRODUCTION");
  // The CAS upsert is raw SQL; instants must survive it exactly (no zone drift).
  assert.equal(first.expiresAt!.getTime(), purchase.event.expiration_at_ms);
  assert.equal(first.lastEventAt.getTime(), purchase.event.event_timestamp_ms);
  const me = json(await app.inject({ method: "GET", url: "/me", headers: asAlice }));
  assert.equal(me.entitlement.active, true);
  assert.equal(me.entitlement.productId, "deep.pro.monthly");
  assert.equal(me.entitlement.store, "APP_STORE");
  assert.equal(me.user.id, aliceId);
  pass("2. INITIAL_PURCHASE applies and GET /me reports an active entitlement");

  // ---- 3. Same event twice: state changes once, both 200 ----
  res = await post(purchase);
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).outcome, "duplicate");
  const again = await subOf(aliceId);
  assert.equal(again!.updatedAt.getTime(), first.updatedAt.getTime(), "row untouched");
  assert.equal(
    await prisma.revenueCatEvent.count({ where: { id: purchase.event.id } }),
    1,
    "one record",
  );
  pass("3. a re-delivered event is a 200 no-op");

  // ---- 4. An older event arriving late is recorded STALE, changes nothing ----
  const late = event("cancellation", aliceId, { event_timestamp_ms: NOW - 3 * DAY });
  res = await post(late);
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).outcome, "stale");
  assert.equal(await outcomeOf(late.event.id), "STALE");
  assert.equal((await subOf(aliceId))!.willRenew, true, "still renewing");
  pass("4. an out-of-order older CANCELLATION is recorded stale and changes nothing");

  // A newer cancellation does apply — and keeps access running.
  const cancel = event("cancellation", aliceId, { event_timestamp_ms: NOW - DAY });
  assert.equal(json(await post(cancel)).outcome, "applied");
  const cancelled = await subOf(aliceId);
  assert.equal(cancelled!.willRenew, false);
  assert.ok(cancelled!.unsubscribedAt);
  assert.equal(
    json(await app.inject({ method: "GET", url: "/me", headers: asAlice })).entitlement.active,
    true,
    "cancelled but paid through",
  );
  pass("4b. a newer CANCELLATION applies: no renewal, access runs to expiry");

  // ---- 5. Unknown user: recorded, 200 ----
  const stranger = crypto.randomUUID();
  const orphan = event("renewal", stranger, {
    aliases: ["$RCAnonymousID:ffffffffffffffffffffffffffffffff"],
    original_app_user_id: "$RCAnonymousID:ffffffffffffffffffffffffffffffff",
  });
  res = await post(orphan);
  assert.equal(res.statusCode, 200);
  assert.equal(await outcomeOf(orphan.event.id), "UNKNOWN_USER");
  assert.equal(await subOf(stranger), null);
  const anon = event("renewal", "$RCAnonymousID:abcdefabcdefabcdefabcdefabcdefab", {
    aliases: [],
    original_app_user_id: "$RCAnonymousID:abcdefabcdefabcdefabcdefabcdefab",
  });
  res = await post(anon);
  assert.equal(res.statusCode, 200, "a non-uuid app user id never reaches a uuid query");
  assert.equal(await outcomeOf(anon.event.id), "UNKNOWN_USER");
  pass("5. events for unknown (and anonymous) users are recorded and answered 200");

  // Alias resolution: app_user_id anonymous, the DEEP id only among aliases.
  const viaAlias = event("renewal", "$RCAnonymousID:1111111111111111111111111111111a", {
    aliases: ["$RCAnonymousID:1111111111111111111111111111111a", aliceId],
    event_timestamp_ms: NOW - DAY + 1000,
  });
  assert.equal(json(await post(viaAlias)).outcome, "applied");
  assert.equal((await prisma.revenueCatEvent.findUnique({ where: { id: viaAlias.event.id } }))!.userId, aliceId);
  assert.equal((await subOf(aliceId))!.willRenew, true, "renewal re-enabled renewing");
  pass("5b. a user is resolved through aliases when app_user_id is anonymous");

  // ---- 6. Unknown event type: recorded, 200 ----
  const future = event("future_thing", aliceId, { event_timestamp_ms: NOW });
  res = await post(future);
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).outcome, "unrecognised");
  assert.equal(await outcomeOf(future.event.id), "UNRECOGNISED");
  pass("6. an unrecognised event type is recorded and answered 200");

  // ---- 7. Sandbox flag honoured; environment stored on every record ----
  mutableEnv.REVENUECAT_ACCEPT_SANDBOX = false;
  const sandboxOff = event("initial_purchase", bobId, { environment: "SANDBOX" });
  res = await post(sandboxOff);
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).outcome, "sandbox_ignored");
  const ignored = await prisma.revenueCatEvent.findUnique({ where: { id: sandboxOff.event.id } });
  assert.equal(ignored!.environment, "SANDBOX");
  assert.equal(ignored!.userId, bobId, "still attributed, for the launch-day sweep");
  assert.equal(await subOf(bobId), null, "ignored sandbox event grants nothing");

  mutableEnv.REVENUECAT_ACCEPT_SANDBOX = true;
  const sandboxOn = event("initial_purchase", bobId, { environment: "SANDBOX" });
  assert.equal(json(await post(sandboxOn)).outcome, "applied");
  assert.equal((await subOf(bobId))!.environment, "SANDBOX");
  pass("7. sandbox events are ignored or applied per the flag, environment always stored");

  // ---- 8. A refund revokes despite a future expiry ----
  const refund = event("refund", aliceId, { event_timestamp_ms: NOW - 1000 });
  assert.equal(json(await post(refund)).outcome, "applied");
  const refunded = await subOf(aliceId);
  assert.ok(refunded!.revokedAt);
  assert.ok(refunded!.expiresAt! > new Date(), "expiry still in the future");
  const login = json(
    await app.inject({
      method: "POST",
      url: "/auth/login",
      payload: { email: `alice-${tag}@deep.test`, password: "password123" },
    }),
  );
  assert.equal(login.entitlement.active, false);
  assert.equal(login.entitlement.productId, "deep.pro.monthly");
  pass("8. a refund revokes immediately; login carries the (inactive) entitlement");

  // ---- 9. Transfer: from side revoked, to side fetched from RevenueCat ----
  const regrant = event("renewal", aliceId, { event_timestamp_ms: NOW - 500 });
  assert.equal(json(await post(regrant)).outcome, "applied");
  restSubscribers.set(bobId, {
    entitlements: {
      deep_premium: {
        expires_date: new Date(NOW + 365 * DAY).toISOString(),
        grace_period_expires_date: null,
        product_identifier: "deep.pro.yearly",
      },
    },
    subscriptions: {
      "deep.pro.yearly": {
        expires_date: new Date(NOW + 365 * DAY).toISOString(),
        period_type: "normal",
        store: "app_store",
        is_sandbox: false,
        unsubscribe_detected_at: null,
        billing_issues_detected_at: null,
        refunded_at: null,
      },
    },
  });
  const transfer = {
    api_version: "1.0",
    event: {
      ...fixtureEvent("transfer"),
      id: crypto.randomUUID().toUpperCase(),
      app_user_id: bobId,
      transferred_from: [aliceId, "$RCAnonymousID:0123456789abcdef0123456789abcdef"],
      transferred_to: [bobId],
      event_timestamp_ms: NOW - 100,
    },
  };
  restCalls.length = 0;
  assert.equal(json(await post(transfer)).outcome, "applied");
  assert.ok((await subOf(aliceId))!.revokedAt, "from side revoked");
  const bobSub = await subOf(bobId);
  assert.equal(bobSub!.productId, "deep.pro.yearly", "to side refreshed from RevenueCat");
  assert.equal(bobSub!.environment, "PRODUCTION");
  assert.equal(restCalls.length, 1);
  assert.equal(restCalls[0]!.auth, `Bearer ${SECRET_KEY}`);
  assert.ok(restCalls[0]!.url.endsWith(`/v1/subscribers/${encodeURIComponent(bobId)}`));
  pass("9. TRANSFER revokes the from side and re-fetches the to side server-side");

  // ---- 10. Refresh: authenticated, server-fetched, rate-limited ----
  res = await app.inject({ method: "POST", url: "/me/entitlement/refresh" });
  assert.equal(res.statusCode, 401, "refresh requires auth");

  refreshCooldown.reset();
  restSubscribers.delete(aliceId); // RevenueCat holds nothing for alice
  res = await app.inject({
    method: "POST",
    url: "/me/entitlement/refresh",
    headers: asAlice,
    // A client claim — must be ignored entirely.
    payload: { entitlement: { active: true, expiresAt: "2099-01-01T00:00:00Z" }, active: true },
  });
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).entitlement.active, false, "client claims are never trusted");

  res = await app.inject({ method: "POST", url: "/me/entitlement/refresh", headers: asAlice });
  assert.equal(res.statusCode, 429);
  assert.equal(json(res).error.code, "rate_limited");

  restSubscribers.set(bobId, {
    entitlements: {
      deep_premium: {
        expires_date: new Date(NOW + 7 * DAY).toISOString(),
        product_identifier: "deep.pro.monthly",
      },
    },
    subscriptions: {
      "deep.pro.monthly": {
        expires_date: new Date(NOW + 7 * DAY).toISOString(),
        period_type: "trial",
        store: "app_store",
        is_sandbox: false,
      },
    },
  });
  res = await app.inject({ method: "POST", url: "/me/entitlement/refresh", headers: asBob });
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).entitlement.periodType, "TRIAL");
  assert.equal((await subOf(bobId))!.productId, "deep.pro.monthly", "row rewritten");
  pass("10. refresh is authenticated, rate-limited, rewrites from RevenueCat, ignores client facts");

  // ---- 11. Unconfigured secrets degrade to 503, never boot failures ----
  mutableEnv.REVENUECAT_SECRET_API_KEY = undefined;
  refreshCooldown.reset();
  res = await app.inject({ method: "POST", url: "/me/entitlement/refresh", headers: asBob });
  assert.equal(res.statusCode, 503);
  assert.equal(json(res).error.code, "not_configured");
  mutableEnv.REVENUECAT_WEBHOOK_AUTH = undefined;
  res = await post(event("renewal", aliceId), WEBHOOK_AUTH);
  assert.equal(res.statusCode, 503);
  assert.equal(json(res).error.code, "not_configured");
  mutableEnv.REVENUECAT_WEBHOOK_AUTH = WEBHOOK_AUTH;
  mutableEnv.REVENUECAT_SECRET_API_KEY = SECRET_KEY;
  pass("11. unset webhook secret / REST key → 503 not_configured");

  // ---- 12. Dev flip route ----
  res = await app.inject({
    method: "POST",
    url: "/dev/premium",
    payload: { userId: aliceId, active: true },
  });
  assert.equal(res.statusCode, 200);
  assert.equal(json(res).entitlement.active, true);
  assert.equal(json(res).entitlement.expiresAt, null, "non-expiring grant");
  assert.equal(
    json(await app.inject({ method: "GET", url: "/me", headers: asAlice })).entitlement.active,
    true,
  );
  res = await app.inject({
    method: "POST",
    url: "/dev/premium",
    payload: { email: `alice-${tag}@deep.test`, active: false },
  });
  assert.equal(json(res).entitlement.active, false);
  assert.equal(
    json(await app.inject({ method: "GET", url: "/me", headers: asAlice })).entitlement.active,
    false,
  );
  pass("12. POST /dev/premium flips a user's entitlement on and off");

  mutableEnv.ALLOW_DEV_ENTITLEMENT = false;
  const guarded = buildApp();
  await guarded.ready();
  res = await guarded.inject({
    method: "POST",
    url: "/dev/premium",
    payload: { userId: aliceId, active: true },
  });
  assert.equal(res.statusCode, 404, "route does not exist without the flag");
  await guarded.close();
  pass("12b. /dev/premium is absent when ALLOW_DEV_ENTITLEMENT is off");

  // ---- 13. Admin user list is unchanged ----
  await prisma.user.create({
    data: {
      email: `admin-${tag}@deep.test`,
      passwordHash: await hashPassword("password123"),
      displayName: "Admin",
      role: "ADMIN",
    },
  });
  const adminLogin = json(
    await app.inject({
      method: "POST",
      url: "/admin/auth/login",
      payload: { email: `admin-${tag}@deep.test`, password: "password123" },
    }),
  );
  res = await app.inject({
    method: "GET",
    url: "/admin/users",
    headers: { authorization: `Bearer ${adminLogin.accessToken}` },
  });
  assert.equal(res.statusCode, 200);
  const listed = json(res).users.find((u: { id: string }) => u.id === aliceId);
  assert.ok(listed);
  assert.deepEqual(Object.keys(listed).sort(), ["createdAt", "displayName", "email", "id", "role"]);
  pass("13. GET /admin/users still works and carries no subscription state");

  console.log("\nAll RevenueCat end-to-end checks passed.");
  await app.close();
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error("\nFAILED:", e);
  await prisma.$disconnect();
  process.exit(1);
});
