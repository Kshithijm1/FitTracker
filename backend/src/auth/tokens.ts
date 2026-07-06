import { randomBytes, createHash } from "node:crypto";
import { SignJWT, jwtVerify } from "jose";
import { env } from "../env.js";

const accessSecret = new TextEncoder().encode(env.JWT_ACCESS_SECRET);

export interface AccessTokenClaims {
  sub: string; // userId — the ONLY source of identity for authenticated routes (PLAN.md §5)
}

export async function signAccessToken(userId: string): Promise<string> {
  return new SignJWT({})
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(`${env.JWT_ACCESS_TTL_SECONDS}s`)
    .sign(accessSecret);
}

export async function verifyAccessToken(token: string): Promise<AccessTokenClaims> {
  const { payload } = await jwtVerify(token, accessSecret);
  if (typeof payload.sub !== "string") {
    throw new Error("Access token missing subject claim");
  }
  return { sub: payload.sub };
}

/// Opaque refresh tokens: 256 bits of randomness, never stored raw —
/// only a SHA-256 hash lives in `auth_sessions.refresh_token_hash`
/// (PLAN.md §5). The raw token is returned to the client exactly once.
export function generateRefreshToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashRefreshToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}
