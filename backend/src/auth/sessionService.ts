import { randomUUID } from "node:crypto";
import { and, eq, isNull } from "drizzle-orm";
import { db } from "../db/client.js";
import { authSessions } from "../db/schema.js";
import { env } from "../env.js";
import { generateRefreshToken, hashRefreshToken, signAccessToken } from "./tokens.js";

export interface IssuedSession {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

function refreshExpiryDate(): Date {
  return new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
}

/// Starts a brand-new rotation lineage ("family") for a fresh login. Each
/// subsequent refresh rotates within the same family so reuse of a stale
/// token can be detected (PLAN.md §5).
export async function createSession(userId: string, deviceName = "Unknown device"): Promise<IssuedSession> {
  const refreshToken = generateRefreshToken();
  const familyId = randomUUID();

  await db.insert(authSessions).values({
    id: randomUUID(),
    userId,
    refreshTokenHash: hashRefreshToken(refreshToken),
    familyId,
    deviceName,
    expiresAt: refreshExpiryDate(),
  });

  return {
    accessToken: await signAccessToken(userId),
    refreshToken,
    expiresIn: env.JWT_ACCESS_TTL_SECONDS,
  };
}

export class RefreshTokenReuseError extends Error {
  constructor() {
    super("Refresh token reuse detected — session family revoked");
  }
}

export class RefreshTokenInvalidError extends Error {
  constructor() {
    super("Refresh token invalid, expired, or revoked");
  }
}

/// Rotates a refresh token: the presented token is immediately revoked and
/// replaced with a new one in the same family. If the presented hash
/// doesn't match any *active* session but does match a *revoked* one, that
/// is a stolen/replayed token — the entire family is revoked so every
/// device on that lineage is forced to re-authenticate (PLAN.md §5).
export async function rotateRefreshToken(presentedToken: string): Promise<IssuedSession> {
  const presentedHash = hashRefreshToken(presentedToken);

  const [active] = await db
    .select()
    .from(authSessions)
    .where(and(eq(authSessions.refreshTokenHash, presentedHash), isNull(authSessions.revokedAt)));

  if (!active) {
    const [revoked] = await db
      .select()
      .from(authSessions)
      .where(eq(authSessions.refreshTokenHash, presentedHash));

    if (revoked) {
      await db
        .update(authSessions)
        .set({ revokedAt: new Date() })
        .where(and(eq(authSessions.familyId, revoked.familyId), isNull(authSessions.revokedAt)));
      throw new RefreshTokenReuseError();
    }
    throw new RefreshTokenInvalidError();
  }

  if (active.expiresAt < new Date()) {
    throw new RefreshTokenInvalidError();
  }

  const newRefreshToken = generateRefreshToken();

  await db.transaction(async (tx) => {
    await tx.update(authSessions).set({ revokedAt: new Date() }).where(eq(authSessions.id, active.id));
    await tx.insert(authSessions).values({
      id: randomUUID(),
      userId: active.userId,
      refreshTokenHash: hashRefreshToken(newRefreshToken),
      familyId: active.familyId,
      deviceName: active.deviceName,
      expiresAt: refreshExpiryDate(),
    });
  });

  return {
    accessToken: await signAccessToken(active.userId),
    refreshToken: newRefreshToken,
    expiresIn: env.JWT_ACCESS_TTL_SECONDS,
  };
}

export async function revokeSession(presentedToken: string): Promise<void> {
  const presentedHash = hashRefreshToken(presentedToken);
  await db
    .update(authSessions)
    .set({ revokedAt: new Date() })
    .where(and(eq(authSessions.refreshTokenHash, presentedHash), isNull(authSessions.revokedAt)));
}

export async function revokeAllSessionsForUser(userId: string): Promise<void> {
  await db
    .update(authSessions)
    .set({ revokedAt: new Date() })
    .where(and(eq(authSessions.userId, userId), isNull(authSessions.revokedAt)));
}
