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

// preHandler: attach claims when a valid bearer token is present, stay
// anonymous otherwise. Never 401s — endpoints using this degrade gracefully
// (e.g. /pause/home falls back to non-personalized picks).
export async function optionalAuth(req: FastifyRequest, _reply: FastifyReply) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) return;
  try {
    req.auth = verifyAccessToken(header.slice("Bearer ".length).trim());
  } catch {
    // Invalid/expired token → anonymous rather than an error.
  }
}

// preHandler factory: require a specific role.
export function requireRole(role: Role) {
  return async (req: FastifyRequest, _reply: FastifyReply) => {
    const claims = readBearer(req);
    if (claims.role !== role) throw ApiError.forbidden();
    req.auth = claims;
  };
}
