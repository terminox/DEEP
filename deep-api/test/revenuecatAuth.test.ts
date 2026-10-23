import { test } from "node:test";
import assert from "node:assert/strict";
import { webhookAuthMatches } from "../src/lib/revenuecat/auth.js";

const SECRET = "Bearer 9f3c2a7e5b1d4f60a8c2e4b6d8f0a1c3";

test("the exact configured header matches", () => {
  assert.equal(webhookAuthMatches(SECRET, SECRET), true);
});

test("a wrong, missing, empty or repeated header does not", () => {
  assert.equal(webhookAuthMatches("Bearer wrong", SECRET), false);
  assert.equal(webhookAuthMatches(undefined, SECRET), false);
  assert.equal(webhookAuthMatches("", SECRET), false);
  assert.equal(webhookAuthMatches([SECRET, SECRET], SECRET), false);
});

test("near misses do not match", () => {
  assert.equal(webhookAuthMatches(SECRET.slice(0, -1), SECRET), false, "prefix");
  assert.equal(webhookAuthMatches(`${SECRET} `, SECRET), false, "trailing space");
  assert.equal(webhookAuthMatches(SECRET.toLowerCase(), SECRET), false, "case");
});

test("a length mismatch neither throws nor short-circuits", () => {
  // timingSafeEqual throws on unequal lengths; hashing first must prevent that.
  assert.doesNotThrow(() => webhookAuthMatches("x", SECRET));
  assert.doesNotThrow(() => webhookAuthMatches("x".repeat(10_000), SECRET));
});
