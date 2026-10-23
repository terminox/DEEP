// RevenueCat does not sign webhook bodies. It sends back, verbatim, the static
// `Authorization` header value configured on the webhook in its dashboard — so
// the whole check is "does this header equal our secret", done without leaking
// anything through timing.
//
// Both sides are SHA-256 hashed first so the comparison is always 32 bytes
// against 32 bytes: crypto.timingSafeEqual throws on a length mismatch, and
// that throw (or an early return on length) would itself reveal the secret's
// length. Never log the header or the secret.
import crypto from "node:crypto";

function digest(value: string): Buffer {
  return crypto.createHash("sha256").update(value, "utf8").digest();
}

/**
 * True when `presented` (the raw Authorization header, possibly absent or
 * repeated) equals `expected`, compared in constant time.
 */
export function webhookAuthMatches(
  presented: string | string[] | undefined,
  expected: string,
): boolean {
  // A repeated header is never what RevenueCat sends; refuse it, but still
  // spend the same hash + compare so the refusal is not faster.
  const value = typeof presented === "string" ? presented : "";
  const equal = crypto.timingSafeEqual(digest(value), digest(expected));
  return equal && typeof presented === "string";
}
