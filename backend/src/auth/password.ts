import argon2 from "argon2";

/// Argon2id per PLAN.md §5 — the OWASP-recommended variant (resistant to
/// both GPU-cracking and side-channel attacks), used only for the
/// email/password fallback (Sign in with Apple is primary and needs no
/// password at all).
export async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, { type: argon2.argon2id });
}

export async function verifyPassword(hash: string, password: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, password);
  } catch {
    return false;
  }
}
