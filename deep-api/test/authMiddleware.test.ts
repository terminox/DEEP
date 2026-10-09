import { test } from "node:test";
import assert from "node:assert/strict";
import type { FastifyReply, FastifyRequest } from "fastify";
import jwt from "jsonwebtoken";

// env.ts parses process.env once at module-load time and requires a secret and
// a database URL; pin both before the middleware (and through it tokens.ts and
// env.ts) is imported — see test/upload.test.ts for the same trick. Nothing
// here touches the database.
process.env.JWT_SECRET = "test-secret";
process.env.DATABASE_URL ??= "postgresql://test@localhost:5432/test";
const { optionalAuth } = await import("../src/auth/middleware.js");
const { signAccessToken } = await import("../src/auth/tokens.js");

const CLAIMS = { sub: "user-1", role: "USER" as const, sid: "session-1" };

function request(authorization?: string): FastifyRequest {
  return { headers: authorization ? { authorization } : {} } as FastifyRequest;
}

const reply = {} as FastifyReply;

async function rejection(req: FastifyRequest) {
  return optionalAuth(req, reply).then(
    () => null,
    (e: { statusCode?: number }) => e.statusCode,
  );
}

test("no Authorization header stays anonymous", async () => {
  const req = request();
  await optionalAuth(req, reply);
  assert.equal(req.auth, undefined);
});

test("a valid bearer token attaches its claims", async () => {
  const req = request(`Bearer ${signAccessToken(CLAIMS)}`);
  await optionalAuth(req, reply);
  assert.equal(req.auth?.sub, "user-1");
  assert.equal(req.auth?.sid, "session-1");
});

test("an expired bearer token 401s, so the client refreshes", async () => {
  // THE regression: an aged-out token used to read as anonymous, and a
  // signed-in member's pause heartbeats then recorded no attendance.
  const expired = jwt.sign(
    { ...CLAIMS, exp: Math.floor(Date.now() / 1000) - 60 },
    process.env.JWT_SECRET!,
  );
  assert.equal(await rejection(request(`Bearer ${expired}`)), 401);
});

test("a garbage bearer token 401s", async () => {
  assert.equal(await rejection(request("Bearer not-a-jwt")), 401);
});

test("a token signed with another secret 401s", async () => {
  const forged = jwt.sign(CLAIMS, "some-other-secret");
  assert.equal(await rejection(request(`Bearer ${forged}`)), 401);
});

test("a non-Bearer scheme stays anonymous", async () => {
  const req = request("Basic dXNlcjpwYXNz");
  await optionalAuth(req, reply);
  assert.equal(req.auth, undefined);
});
