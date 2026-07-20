import type { Role } from "@prisma/client";
import { prisma } from "../prisma.js";
import { env } from "../env.js";
import { ApiError } from "../lib/errors.js";
import {
  signAccessToken,
  generateRefreshToken,
  hashRefreshToken,
} from "./tokens.js";

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

interface DeviceInfo {
  userAgent?: string | undefined;
  ip?: string | undefined;
}

function refreshExpiry(): Date {
  return new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
}

// Issue a brand-new session (login / signup).
export async function createSession(
  userId: string,
  role: Role,
  device: DeviceInfo,
): Promise<TokenPair> {
  const refreshToken = generateRefreshToken();
  const session = await prisma.authSession.create({
    data: {
      userId,
      refreshTokenHash: hashRefreshToken(refreshToken),
      userAgent: device.userAgent ?? null,
      ip: device.ip ?? null,
      expiresAt: refreshExpiry(),
    },
  });
  return {
    accessToken: signAccessToken({ sub: userId, role, sid: session.id }),
    refreshToken,
    expiresIn: env.ACCESS_TOKEN_TTL_SECONDS,
  };
}

// Rotate: exchange a refresh token for a fresh pair. Detects reuse of an
// already-rotated token and revokes the whole session as a safety response.
export async function rotateSession(
  refreshToken: string,
  device: DeviceInfo,
): Promise<TokenPair> {
  const presentedHash = hashRefreshToken(refreshToken);

  const session = await prisma.authSession.findFirst({
    where: {
      OR: [
        { refreshTokenHash: presentedHash },
        { prevRefreshTokenHash: presentedHash },
      ],
    },
    include: { user: true },
  });

  if (!session) throw ApiError.unauthorized("Invalid refresh token");

  // Reuse of the previous (already-rotated) token => compromise. Kill it.
  if (session.prevRefreshTokenHash === presentedHash) {
    await prisma.authSession.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });
    throw ApiError.unauthorized("Refresh token reuse detected", "token_reuse");
  }

  if (session.revokedAt) throw ApiError.unauthorized("Session revoked");
  if (session.expiresAt.getTime() < Date.now())
    throw ApiError.unauthorized("Session expired");

  const nextToken = generateRefreshToken();
  await prisma.authSession.update({
    where: { id: session.id },
    data: {
      refreshTokenHash: hashRefreshToken(nextToken),
      prevRefreshTokenHash: presentedHash,
      lastUsedAt: new Date(),
      userAgent: device.userAgent ?? session.userAgent,
      ip: device.ip ?? session.ip,
    },
  });

  return {
    accessToken: signAccessToken({
      sub: session.userId,
      role: session.user.role,
      sid: session.id,
    }),
    refreshToken: nextToken,
    expiresIn: env.ACCESS_TOKEN_TTL_SECONDS,
  };
}

export async function revokeSession(sessionId: string): Promise<void> {
  await prisma.authSession
    .update({ where: { id: sessionId }, data: { revokedAt: new Date() } })
    .catch(() => {
      /* already gone — logout is idempotent */
    });
}
