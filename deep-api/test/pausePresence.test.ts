import { test } from "node:test";
import assert from "node:assert/strict";
import * as presence from "../src/lib/pausePresence.js";
import { jitteredWorldCity, WORLD_CITIES } from "../src/lib/fakeCities.js";

function distanceToNearestCity(lat: number, lon: number): number {
  let min = Infinity;
  for (const city of WORLD_CITIES) {
    const d = Math.max(Math.abs(lat - city.lat), Math.abs(lon - city.lon));
    if (d < min) min = d;
  }
  return min;
}

test("jitteredWorldCity stays within valid lat/lon bounds and near a known city", () => {
  for (let i = 0; i < 200; i++) {
    const { lat, lon, iso } = jitteredWorldCity();
    assert.ok(lat >= -90 && lat <= 90, `lat ${lat} out of bounds`);
    assert.ok(lon >= -180 && lon <= 180, `lon ${lon} out of bounds`);
    assert.ok(WORLD_CITIES.some((c) => c.iso === iso), `iso ${iso} not a known city`);
    assert.ok(distanceToNearestCity(lat, lon) <= 3, `(${lat}, ${lon}) not within 3° of a city`);
  }
});

test("injectFake seeds presences whose coords land near a known city", () => {
  presence.injectFake(30);
  const snap = presence.snapshot();
  assert.ok(snap.points.length > 0);
  for (const p of snap.points) {
    assert.ok(p.lat >= -90 && p.lat <= 90);
    assert.ok(p.lon >= -180 && p.lon <= 180);
    // Clustering can average two nearby jittered cities together, so allow
    // a little more slack than the raw per-sample bound.
    assert.ok(distanceToNearestCity(p.lat, p.lon) <= 4, `cluster (${p.lat}, ${p.lon}) too far from any city`);
  }
});

test("injectDripJoin lands a fake participant in recentJoins with lat/lon", () => {
  const before = presence.snapshot().recentJoins.length;
  presence.injectDripJoin();
  const after = presence.snapshot();
  assert.equal(after.recentJoins.length, before + 1);
  const join = after.recentJoins[after.recentJoins.length - 1]!;
  assert.ok(typeof join.lat === "number");
  assert.ok(typeof join.lon === "number");
  assert.ok(WORLD_CITIES.some((c) => c.iso === join.iso));
});

test("injectDripJoin called N times produces N recentJoins entries", () => {
  const before = presence.snapshot().recentJoins.length;
  for (let i = 0; i < 5; i++) presence.injectDripJoin();
  const after = presence.snapshot().recentJoins.length;
  assert.equal(after, before + 5);
});

// The one timing-dependent test in this file (per CLAUDE.md guidance to
// prefer testing the pure injection path directly and keep timing tests
// cheap). Covers pacing, self-stop after N, cancellation, and replacement in
// one pass with generous margins to avoid flakiness.
test("startDrip paces joins, stops after N, and a new drip replaces a running one", async () => {
  const count = () => presence.snapshot().recentJoins.length;

  // Pacing + self-stop: 2 joins, 300ms apart.
  let before = count();
  presence.startDrip(2, 300);
  await new Promise((r) => setTimeout(r, 100));
  assert.equal(count(), before, "no join before the first interval elapses");
  await new Promise((r) => setTimeout(r, 400));
  assert.equal(count(), before + 1, "first join lands after one interval");
  await new Promise((r) => setTimeout(r, 400));
  assert.equal(count(), before + 2, "second join lands, then the timer stops itself");
  await new Promise((r) => setTimeout(r, 500));
  assert.equal(count(), before + 2, "no further joins after N");

  // Cancellation: stopDrip mid-flight.
  before = count();
  presence.startDrip(10, 200);
  await new Promise((r) => setTimeout(r, 250));
  presence.stopDrip();
  const afterStop = count();
  assert.ok(afterStop < before + 10, "fewer than N joins landed before cancellation");
  await new Promise((r) => setTimeout(r, 500));
  assert.equal(count(), afterStop, "no more joins arrive once stopped");

  // Replacement: a new drip cancels/replaces one already running.
  presence.startDrip(10, 200);
  await new Promise((r) => setTimeout(r, 250));
  before = count();
  presence.startDrip(1, 200);
  await new Promise((r) => setTimeout(r, 700));
  assert.equal(count(), before + 1, "only the replacement drip's join lands");
});

test("heartbeat returns the resolved location for a join and preserves it on refresh", () => {
  const key = `anon:test-${Math.random().toString(36).slice(2, 8)}`;
  const join = presence.heartbeat(key, "JP", { lat: 35.7, lon: 139.7 });
  assert.equal(join.isNewJoin, true);
  assert.deepEqual(join.location, { lat: 35.7, lon: 139.7 });

  const refresh = presence.heartbeat(key, "JP");
  assert.equal(refresh.isNewJoin, false);
  assert.deepEqual(refresh.location, { lat: 35.7, lon: 139.7 });
});

test("heartbeat returns null location when none resolves for a join", () => {
  const key = `anon:test-${Math.random().toString(36).slice(2, 8)}`;
  const join = presence.heartbeat(key, "US", null);
  assert.equal(join.location, null);
});

test("heartbeat derives a continent from the device country when the IP can't be placed", () => {
  const key = `anon:test-${Math.random().toString(36).slice(2, 8)}`;
  const before = presence.snapshot().byContinent.AS ?? 0;
  presence.heartbeat(key, "JP", null, null);
  assert.equal(presence.snapshot().byContinent.AS ?? 0, before + 1);
  presence.leave(key);
  assert.equal(presence.snapshot().byContinent.AS ?? 0, before, "leaving gives the seat back");
});

test("an IP-resolved continent wins over the device country", () => {
  // A Thai phone pausing from Paris is pausing in Europe.
  const key = `anon:test-${Math.random().toString(36).slice(2, 8)}`;
  const before = presence.snapshot().byContinent;
  const beforeEU = before.EU ?? 0;
  const beforeAS = before.AS ?? 0;
  presence.heartbeat(key, "TH", { lat: 48.9, lon: 2.4 }, "EU");
  const after = presence.snapshot().byContinent;
  assert.equal(after.EU ?? 0, beforeEU + 1);
  assert.equal(after.AS ?? 0, beforeAS);
  presence.leave(key);
});

test("a refresh beat keeps the continent resolved at join", () => {
  const key = `anon:test-${Math.random().toString(36).slice(2, 8)}`;
  const beforeEU = presence.snapshot().byContinent.EU ?? 0;
  const beforeAS = presence.snapshot().byContinent.AS ?? 0;
  presence.heartbeat(key, "TH", { lat: 48.9, lon: 2.4 }, "EU");
  // Refresh beats skip the geo lookup entirely, so both trailing arguments
  // are omitted — the entry must not fall back to the device's country.
  presence.heartbeat(key, "TH");
  const after = presence.snapshot().byContinent;
  assert.equal(after.EU ?? 0, beforeEU + 1);
  assert.equal(after.AS ?? 0, beforeAS);
  presence.leave(key);
});

test("a nonsense continent code from geo falls back to the device country", () => {
  const key = `anon:test-${Math.random().toString(36).slice(2, 8)}`;
  const before = presence.snapshot().byContinent.SA ?? 0;
  presence.heartbeat(key, "BR", null, "XX");
  assert.equal(presence.snapshot().byContinent.SA ?? 0, before + 1);
  presence.leave(key);
});

test("scatter fakes tally by continent without touching byCountry", () => {
  const before = presence.snapshot();
  presence.injectFake(20);
  const after = presence.snapshot();
  assert.deepEqual(after.byCountry, before.byCountry, "scatter fakes stay out of byCountry");
  const sum = (tally: Record<string, number>) =>
    Object.values(tally).reduce((total, n) => total + n, 0);
  assert.equal(sum(after.byContinent), sum(before.byContinent) + 20);
});
