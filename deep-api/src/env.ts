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
  // DEEP Premium (RevenueCat). All optional so local dev, `npm test` and the
  // verify scripts boot without them; each feature degrades to a 503
  // `not_configured` rather than failing at startup.
  //
  // The exact `Authorization` header value set on the webhook in the
  // RevenueCat dashboard. Unset → POST /webhooks/revenuecat answers 503.
  REVENUECAT_WEBHOOK_AUTH: z.string().min(1).optional(),
  // RevenueCat secret (sk_…) REST key, for POST /me/entitlement/refresh and
  // transfer reconciliation. Unset → refresh answers 503.
  REVENUECAT_SECRET_API_KEY: z.string().min(1).optional(),
  // The RevenueCat entitlement identifier that means DEEP Premium.
  REVENUECAT_ENTITLEMENT_ID: z.string().min(1).default("deep_premium"),
  // Apply SANDBOX webhook events. True while DEEP ships through TestFlight
  // (TestFlight purchases are sandbox); false from public launch. Ignored
  // events are still recorded.
  REVENUECAT_ACCEPT_SANDBOX: z
    .string()
    .optional()
    .transform((v) => v === "true" || v === "1"),
  // Dev-only: enables POST /dev/premium, which flips a user's DEEP Premium
  // entitlement without a purchase. Must stay false anywhere real.
  ALLOW_DEV_ENTITLEMENT: z
    .string()
    .optional()
    .transform((v) => v === "true" || v === "1"),
});

export const env = schema.parse(process.env);
export type Env = z.infer<typeof schema>;
