// In-memory presence for the Global Pause lobby. Ephemeral by nature — counts
// self-heal within one heartbeat interval after a restart, which is fine for a
// single-instance deployment. Scale-out would move this to Redis.

const HEARTBEAT_TTL_MS = 60_000;
const RECENT_JOINS_CAP = 50;

interface PresenceEntry {
  countryISO: string | null;
  lastSeen: number;
}

interface RecentJoin {
  iso: string;
  at: number;
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

/** Records a beat. The first beat for a key (or after expiry) counts as a join. */
export function heartbeat(key: string, countryISO: string | null): { isNewJoin: boolean } {
  const now = Date.now();
  sweep(now);
  const isNewJoin = !entries.has(key);
  entries.set(key, { countryISO, lastSeen: now });
  if (isNewJoin && countryISO) {
    recentJoins.push({ iso: countryISO, at: now });
    if (recentJoins.length > RECENT_JOINS_CAP) recentJoins.shift();
  }
  return { isNewJoin };
}

export function leave(key: string) {
  entries.delete(key);
}

export function snapshot(): {
  total: number;
  byCountry: Record<string, number>;
  recentJoins: { iso: string; at: Date }[];
} {
  const now = Date.now();
  sweep(now);
  const byCountry: Record<string, number> = {};
  for (const entry of entries.values()) {
    if (!entry.countryISO) continue;
    byCountry[entry.countryISO] = (byCountry[entry.countryISO] ?? 0) + 1;
  }
  return {
    total: entries.size,
    byCountry,
    recentJoins: recentJoins.map((j) => ({ iso: j.iso, at: new Date(j.at) })),
  };
}
