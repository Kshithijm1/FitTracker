import { createRemoteJWKSet, jwtVerify } from "jose";
import { env } from "../env.js";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";

// Cached across requests; `jose` handles key rotation/refetch internally.
const appleJWKS = createRemoteJWKSet(new URL(APPLE_JWKS_URL));

export interface AppleIdentity {
  appleUserId: string;
  email: string | null;
}

/// Verifies a Sign in with Apple identity token against Apple's public
/// JWKS (PLAN.md §5) — signature, issuer, and audience (our bundle ID) are
/// all checked so a token minted for a different app can't be replayed here.
export async function verifyAppleIdentityToken(identityToken: string): Promise<AppleIdentity> {
  const { payload } = await jwtVerify(identityToken, appleJWKS, {
    issuer: APPLE_ISSUER,
    audience: env.APPLE_BUNDLE_ID,
  });

  if (typeof payload.sub !== "string") {
    throw new Error("Apple identity token missing subject claim");
  }

  return {
    appleUserId: payload.sub,
    email: typeof payload.email === "string" ? payload.email : null,
  };
}
