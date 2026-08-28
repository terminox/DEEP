import { z } from "zod";
import { DEFAULT_MEDIA_DIR } from "./lib/mediaFiles.js";

// Load .env (Node 22 built-in) before reading process.env. Prisma loads its
// own copy for CLI commands; this covers the app runtime.
try {
  process.loadEnvFile();
} catch {
  /* no .env file — rely on real environment variables */
}

const schema = z.object({
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(1),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  HOST: z.string().default("0.0.0.0"),
  PORT: z.coerce.number().int().positive().default(8080),
  // Pins the origin used for absolute media URLs. Leave unset in local dev so
  // those URLs follow whatever host the client reached us on (see lib/media.ts).
  // Production must set it — that is what stops the Host header being trusted.
  PUBLIC_BASE_URL: z.string().url().optional(),
  MEDIA_DIR: z.string().default(DEFAULT_MEDIA_DIR),
  ADMIN_BOOTSTRAP_EMAIL: z.string().email().optional(),
  ADMIN_BOOTSTRAP_PASSWORD: z.string().min(8).optional(),
  // Dev-only: enables the /dev/pause/time-travel route that shifts the Global
  // Pause phase clock. Must stay false anywhere real.
  ALLOW_TIME_OVERRIDE: z
    .string()
    .optional()
    .transform((v) => v === "true" || v === "1"),
  // Optional: enables real IP geolocation for Global Pause (see lib/geoip.ts). Falls
  // back to per-participant country-only presence when the file is missing.
  GEOIP_DB_PATH: z.string().default("./geoip/GeoLite2-City.mmdb"),
  // Only needed to run scripts/geoip-update.sh; never read at request time.
  MAXMIND_LICENSE_KEY: z.string().optional(),
});

export const env = schema.parse(process.env);
export type Env = z.infer<typeof schema>;
