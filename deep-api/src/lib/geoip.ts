import maxmind, { type Reader, type CityResponse } from "maxmind";
import { env } from "../env.js";

// IP → coarse location for Global Pause presence. Backed by a local GeoLite2
// City mmdb (see scripts/geoip-update.sh); when the file isn't present, every
// lookup resolves to null and the caller falls back to country-only presence.

export interface GeoLocation {
  lat: number;
  lon: number;
  iso: string | null;
  /** MaxMind's continent code ("AS", "EU", …); null when the record omits it. */
  continent: string | null;
}

let reader: Reader<CityResponse> | null = null;
let openFailed = false;
let opening: Promise<Reader<CityResponse> | null> | null = null;

let fixedLocation: { lat: number; lon: number } | null = null;

/** Dev override: when set, lookup() returns this location for every IP. */
export function setFixedLocation(loc: { lat: number; lon: number } | null): void {
  fixedLocation = loc;
}

function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

async function getReader(): Promise<Reader<CityResponse> | null> {
  if (openFailed) return null;
  if (reader) return reader;
  if (!opening) {
    opening = maxmind
      .open<CityResponse>(env.GEOIP_DB_PATH, { watchForUpdates: true })
      .then((r) => {
        reader = r;
        return r;
      })
      .catch(() => {
        openFailed = true;
        console.warn(
          "geoip: GeoLite2 database not found at GEOIP_DB_PATH — Global Pause will fall back to country-only presence",
        );
        return null;
      });
  }
  return opening;
}

/** True for loopback, private, and link-local ranges (v4, v4-mapped v6, and v6). */
export function isPrivateIP(ip: string): boolean {
  const unwrapped = ip.startsWith("::ffff:") ? ip.slice(7) : ip;

  if (unwrapped.includes(".")) {
    const parts = unwrapped.split(".").map((p) => Number(p));
    if (parts.length !== 4 || parts.some((p) => Number.isNaN(p))) return false;
    const [a, b] = parts as [number, number, number, number];
    if (a === 127) return true; // 127.0.0.0/8
    if (a === 10) return true; // 10.0.0.0/8
    if (a === 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
    if (a === 192 && b === 168) return true; // 192.168.0.0/16
    if (a === 169 && b === 254) return true; // 169.254.0.0/16
    return false;
  }

  const lower = unwrapped.toLowerCase();
  if (lower === "::1") return true; // loopback
  if (/^fc[0-9a-f][0-9a-f]:/.test(lower) || /^fd[0-9a-f][0-9a-f]:/.test(lower)) return true; // fc00::/7
  if (/^fe[89ab][0-9a-f]:/.test(lower)) return true; // fe80::/10
  return false;
}

export async function lookup(ip: string): Promise<GeoLocation | null> {
  if (fixedLocation) {
    return {
      lat: round1(fixedLocation.lat),
      lon: round1(fixedLocation.lon),
      iso: null,
      continent: null,
    };
  }
  if (isPrivateIP(ip)) return null;

  const r = await getReader();
  if (!r) return null;

  const rec = r.get(ip);
  if (!rec?.location) return null;

  return {
    lat: round1(rec.location.latitude),
    lon: round1(rec.location.longitude),
    iso: rec.country?.iso_code ?? null,
    continent: rec.continent?.code ?? null,
  };
}
