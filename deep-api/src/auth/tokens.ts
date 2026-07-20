import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import { env } from "../env.js";
import type { Role } from "@prisma/client";

export interface AccessClaims {
  sub: string; // user id
  role: Role;
  sid: string; // session id
}

export function signAccessToken(claims: AccessClaims): string {
  return jwt.sign(claims, env.JWT_SECRET, {
    expiresIn: env.ACCESS_TOKEN_TTL_SECONDS,
  });
}

export function verifyAccessToken(token: string): AccessClaims {
  return jwt.verify(token, env.JWT_SECRET) as AccessClaims;
}

// Opaque refresh tokens: a random secret handed to the client, only its
// SHA-256 hash is ever stored, so a DB leak can't be replayed.
export function generateRefreshToken(): string {
  return crypto.randomBytes(48).toString("base64url");
}

export function hashRefreshToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}
