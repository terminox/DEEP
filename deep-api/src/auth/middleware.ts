import type { FastifyReply, FastifyRequest } from "fastify";
import type { Role } from "@prisma/client";
import { ApiError } from "../lib/errors.js";
import { verifyAccessToken, type AccessClaims } from "./tokens.js";

declare module "fastify" {
  interface FastifyRequest {
    auth?: AccessClaims;
  }
}

function readBearer(req: FastifyRequest): AccessClaims {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    throw ApiError.unauthorized("Missing bearer token");
  }
  try {
    return verifyAccessToken(header.slice("Bearer ".length).trim());
  } catch {
    throw ApiError.unauthorized("Invalid or expired token");
  }
}

// preHandler: require any authenticated user.
export async function requireAuth(req: FastifyRequest, _reply: FastifyReply) {
  req.auth = readBearer(req);
}

// preHandler: no bearer token → anonymous (endpoints using this degrade
// gracefully, e.g. /pause/home falls back to non-personalized picks). A
// bearer token that is present but invalid or expired 401s exactly like
// requireAuth: silently downgrading it to anonymous meant clients never
// learned to refresh, and a signed-in member's pause heartbeats stopped
// leaving the attendance evidence their award is judged on.
export async function optionalAuth(req: FastifyRequest, _reply: FastifyReply) {
  if (!req.headers.authorization?.startsWith("Bearer ")) return;
  req.auth = readBearer(req);
}

// preHandler factory: require a specific role.
export function requireRole(role: Role) {
  return async (req: FastifyRequest, _reply: FastifyReply) => {
    const claims = readBearer(req);
    if (claims.role !== role) throw ApiError.forbidden();
    req.auth = claims;
  };
}
