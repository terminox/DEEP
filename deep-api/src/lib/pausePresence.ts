// In-memory presence for the Global Pause lobby. Ephemeral by nature — counts
// self-heal within one heartbeat interval after a restart, which is fine for a
// single-instance deployment. Scale-out would move this to Redis.

import { clusterPoints } from "./geoCluster.js";
import { jitteredWorldCity } from "./fakeCities.js";

const HEARTBEAT_TTL_MS = 60_000;
const RECENT_JOINS_CAP = 50;

type Location = { lat: number; lon: number };

interface PresenceEntry {
  countryISO: string | null;
  lastSeen: number;
  location: Location | null;
}

interface RecentJoin {
  iso: string;
  at: number;
  lat?: number;
  lon?: number;
}

const entries = new Map<string, PresenceEntry>();
const recentJoins: RecentJoin[] = [];

function sweep(now: number) {
  for (const [key, entry] of entries) {
    if (now - entry.lastSeen > HEARTBEAT_TTL_MS) entries.delete(key);
  }
  while (recentJoins.length > 0 && now - recentJoins[0]!.at > HEARTBEAT_TTL_MS) {
    recentJoins.shift();
  }
}

/** True if `key` currently holds an unexpired presence entry. */
export function isActive(key: string): boolean {
  sweep(Date.now());
  return entries.has(key);
}

/**
 * Records a beat. The first beat for a key (or after expiry) counts as a join.
 * `location` is only meaningful on a join: pass the geo-looked-up location (or
 * null when it couldn't be resolved) for a new key. Omit it (undefined) on a
 * refresh beat to preserve whatever location the entry already has.
 */
export function heartbeat(
  key: string,
  countryISO: string | null,
  location?: Location | null,
): { isNewJoin: boolean; location: Location | null } {
  const now = Date.now();
  sweep(now);
  const isNewJoin = !entries.has(key);
  const resolvedLocation = isNewJoin
    ? (location ?? null)
    : (location ?? entries.get(key)!.location);
  entries.set(key, { countryISO, lastSeen: now, location: resolvedLocation });
  if (isNewJoin && countryISO) {
    const join: RecentJoin = { iso: countryISO, at: now };
    if (resolvedLocation) {
      join.lat = resolvedLocation.lat;
      join.lon = resolvedLocation.lon;
    }
    recentJoins.push(join);
    if (recentJoins.length > RECENT_JOINS_CAP) recentJoins.shift();
  }
  return { isNewJoin, location: resolvedLocation };
}

export function leave(key: string) {
  entries.delete(key);
}

/**
 * Seeds `n` fake presences for the dev scatter route, jittered around world
 * cities so points land on population centers instead of open ocean. They
 * expire via the normal TTL.
 */
export function injectFake(n: number): void {
  const now = Date.now();
  for (let i = 0; i < n; i++) {
    const key = `anon:fake-${i}-${Math.random().toString(36).slice(2, 8)}`;
    const { lat, lon } = jitteredWorldCity();
    entries.set(key, { countryISO: null, lastSeen: now, location: { lat, lon } });
  }
}

let dripTimer: ReturnType<typeof setInterval> | null = null;

/** Cancels any fake-participant drip in flight (dev tooling only). No-op if none is running. */
export function stopDrip(): void {
  if (dripTimer) {
    clearInterval(dripTimer);
    dripTimer = null;
  }
}

/**
 * Injects one fake participant through the real join path: a fresh
 * `anon:fake-drip-*` key heartbeats in at a jittered world city, landing in
 * recentJoins with lat/lon/iso like a genuine device would. Exported
 * separately from `startDrip` so tests can exercise the pure injection logic
 * without depending on timers.
 */
export function injectDripJoin(): void {
  const { lat, lon, iso } = jitteredWorldCity();
  const key = `anon:fake-drip-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  heartbeat(key, iso, { lat, lon });
}

/**
 * Starts a dev-only drip: one fake join every `intervalMs`, `n` total, each
 * going through `injectDripJoin`. Replaces any drip already in flight, and
 * stops itself after the nth injection.
 */
export function startDrip(n: number, intervalMs: number): void {
  stopDrip();
  let injected = 0;
  dripTimer = setInterval(() => {
    injectDripJoin();
    injected++;
    if (injected >= n) stopDrip();
  }, intervalMs);
}

export function snapshot(): {
  total: number;
  byCountry: Record<string, number>;
  unlocatedByCountry: Record<string, number>;
  recentJoins: { iso: string; at: Date; lat?: number; lon?: number }[];
  points: { lat: number; lon: number; count: number }[];
} {
  const now = Date.now();
  sweep(now);
  const byCountry: Record<string, number> = {};
  const unlocatedByCountry: Record<string, number> = {};
  const locations: Location[] = [];
  for (const entry of entries.values()) {
    if (entry.location) locations.push(entry.location);
    if (!entry.countryISO) continue;
    byCountry[entry.countryISO] = (byCountry[entry.countryISO] ?? 0) + 1;
    if (!entry.location) {
      unlocatedByCountry[entry.countryISO] = (unlocatedByCountry[entry.countryISO] ?? 0) + 1;
    }
  }
  return {
    total: entries.size,
    byCountry,
    unlocatedByCountry,
    recentJoins: recentJoins.map((j) => ({
      iso: j.iso,
      at: new Date(j.at),
      ...(j.lat !== undefined ? { lat: j.lat, lon: j.lon } : {}),
    })),
    points: clusterPoints(locations),
  };
}
