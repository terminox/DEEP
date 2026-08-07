// A spread of world cities for dev-only presence stress testing (scatter and
// drip fake locations). Keeps injected points landing on population centers
// across every inhabited continent instead of filling the oceans, and gives
// drip joins a plausible countryISO for the recentJoins feed.

export interface WorldCity {
  lat: number;
  lon: number;
  iso: string;
}

export const WORLD_CITIES: WorldCity[] = [
  { lat: 13.7563, lon: 100.5018, iso: "TH" }, // Bangkok
  { lat: 35.6762, lon: 139.6503, iso: "JP" }, // Tokyo
  { lat: 37.5665, lon: 126.978, iso: "KR" }, // Seoul
  { lat: 1.3521, lon: 103.8198, iso: "SG" }, // Singapore
  { lat: -6.2088, lon: 106.8456, iso: "ID" }, // Jakarta
  { lat: 19.076, lon: 72.8777, iso: "IN" }, // Mumbai
  { lat: 28.7041, lon: 77.1025, iso: "IN" }, // Delhi
  { lat: 25.2048, lon: 55.2708, iso: "AE" }, // Dubai
  { lat: 41.0082, lon: 28.9784, iso: "TR" }, // Istanbul
  { lat: 32.0853, lon: 34.7818, iso: "IL" }, // Tel Aviv
  { lat: 55.7558, lon: 37.6173, iso: "RU" }, // Moscow
  { lat: 51.5074, lon: -0.1278, iso: "GB" }, // London
  { lat: 48.8566, lon: 2.3522, iso: "FR" }, // Paris
  { lat: 52.52, lon: 13.405, iso: "DE" }, // Berlin
  { lat: 40.4168, lon: -3.7038, iso: "ES" }, // Madrid
  { lat: 41.9028, lon: 12.4964, iso: "IT" }, // Rome
  { lat: 52.3676, lon: 4.9041, iso: "NL" }, // Amsterdam
  { lat: 59.3293, lon: 18.0686, iso: "SE" }, // Stockholm
  { lat: 52.2297, lon: 21.0122, iso: "PL" }, // Warsaw
  { lat: 6.5244, lon: 3.3792, iso: "NG" }, // Lagos
  { lat: -1.2921, lon: 36.8219, iso: "KE" }, // Nairobi
  { lat: 30.0444, lon: 31.2357, iso: "EG" }, // Cairo
  { lat: 5.6037, lon: -0.187, iso: "GH" }, // Accra
  { lat: -26.2041, lon: 28.0473, iso: "ZA" }, // Johannesburg
  { lat: 33.5731, lon: -7.5898, iso: "MA" }, // Casablanca
  { lat: 40.7128, lon: -74.006, iso: "US" }, // New York
  { lat: 34.0522, lon: -118.2437, iso: "US" }, // Los Angeles
  { lat: 41.8781, lon: -87.6298, iso: "US" }, // Chicago
  { lat: 43.6532, lon: -79.3832, iso: "CA" }, // Toronto
  { lat: 19.4326, lon: -99.1332, iso: "MX" }, // Mexico City
  { lat: -23.5505, lon: -46.6333, iso: "BR" }, // São Paulo
  { lat: -34.6037, lon: -58.3816, iso: "AR" }, // Buenos Aires
  { lat: 4.711, lon: -74.0721, iso: "CO" }, // Bogotá
  { lat: -12.0464, lon: -77.0428, iso: "PE" }, // Lima
  { lat: -33.4489, lon: -70.6693, iso: "CL" }, // Santiago
  { lat: -33.8688, lon: 151.2093, iso: "AU" }, // Sydney
  { lat: -37.8136, lon: 144.9631, iso: "AU" }, // Melbourne
  { lat: -36.8485, lon: 174.7633, iso: "NZ" }, // Auckland
  { lat: 14.5995, lon: 120.9842, iso: "PH" }, // Manila
  { lat: 10.8231, lon: 106.6297, iso: "VN" }, // Ho Chi Minh City
];

const JITTER_DEGREES = 2;

function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

function clampLat(v: number): number {
  return Math.min(90, Math.max(-90, v));
}

function clampLon(v: number): number {
  return Math.min(180, Math.max(-180, v));
}

/**
 * Picks a random world city and applies ±JITTER_DEGREES uniform jitter to
 * lat/lon independently, rounded to 0.1 like geoip's real lookups. Used by
 * both scatter (injectFake) and drip so stress-test participants land near
 * population centers instead of filling the oceans.
 */
export function jitteredWorldCity(): WorldCity {
  const city = WORLD_CITIES[Math.floor(Math.random() * WORLD_CITIES.length)]!;
  const lat = clampLat(city.lat + (Math.random() * 2 - 1) * JITTER_DEGREES);
  const lon = clampLon(city.lon + (Math.random() * 2 - 1) * JITTER_DEGREES);
  return { lat: round1(lat), lon: round1(lon), iso: city.iso };
}
