import { randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "../db/client.js";
import { users } from "../db/schema.js";
import { verifyAppleIdentityToken } from "../auth/apple.js";
import { hashPassword, verifyPassword } from "../auth/password.js";
import {
  createSession,
  revokeAllSessionsForUser,
  revokeSession,
  rotateRefreshToken,
  RefreshTokenInvalidError,
  RefreshTokenReuseError,
} from "../auth/sessionService.js";
import { requireAuth } from "../auth/middleware.js";

// 5 requests/minute on every auth route (PLAN.md §5) — brute-force/credential-stuffing mitigation.
const AUTH_RATE_LIMIT = { max: 5, timeWindow: "1 minute" };

const appleSignInSchema = z.object({
  identityToken: z.string().min(1),
  displayName: z.string().min(1).max(80).optional(),
  deviceName: z.string().max(120).optional(),
});

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(10).max(200),
  displayName: z.string().min(1).max(80),
  deviceName: z.string().max(120).optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1).max(200),
  deviceName: z.string().max(120).optional(),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export async function authRoutes(app: FastifyInstance): Promise<void> {
  app.post("/v1/auth/apple", { config: { rateLimit: AUTH_RATE_LIMIT } }, async (request, reply) => {
    const body = appleSignInSchema.safeParse(request.body);
    if (!body.success) {
      return reply.code(400).send({ error: "Invalid request body" });
    }

    let identity;
    try {
      identity = await verifyAppleIdentityToken(body.data.identityToken);
    } catch {
      return reply.code(401).send({ error: "Invalid Apple identity token" });
    }

    let [user] = await db.select().from(users).where(eq(users.appleUserId, identity.appleUserId));
    if (!user) {
      [user] = await db
        .insert(users)
        .values({
          id: randomUUID(),
          appleUserId: identity.appleUserId,
          email: identity.email,
          displayName: body.data.displayName ?? "FitTrack User",
        })
        .returning();
    }
    if (!user) {
      return reply.code(500).send({ error: "Failed to create user" });
    }

    const session = await createSession(user.id, body.data.deviceName);
    return reply.code(200).send({ user: toPublicUser(user), ...session });
  });

  app.post("/v1/auth/register", { config: { rateLimit: AUTH_RATE_LIMIT } }, async (request, reply) => {
    const body = registerSchema.safeParse(request.body);
    if (!body.success) {
      return reply.code(400).send({ error: "Invalid request body" });
    }

    const [existing] = await db.select().from(users).where(eq(users.email, body.data.email));
    if (existing) {
      return reply.code(409).send({ error: "An account with this email already exists" });
    }

    const passwordHash = await hashPassword(body.data.password);
    const [user] = await db
      .insert(users)
      .values({
        id: randomUUID(),
        email: body.data.email,
        passwordHash,
        displayName: body.data.displayName,
      })
      .returning();
    if (!user) {
      return reply.code(500).send({ error: "Failed to create user" });
    }

    const session = await createSession(user.id, body.data.deviceName);
    return reply.code(201).send({ user: toPublicUser(user), ...session });
  });

  app.post("/v1/auth/login", { config: { rateLimit: AUTH_RATE_LIMIT } }, async (request, reply) => {
    const body = loginSchema.safeParse(request.body);
    if (!body.success) {
      return reply.code(400).send({ error: "Invalid request body" });
    }

    const [user] = await db.select().from(users).where(eq(users.email, body.data.email));
    // Constant-shape response whether the email exists or the password is
    // wrong — never reveal which one failed.
    if (!user?.passwordHash || !(await verifyPassword(user.passwordHash, body.data.password))) {
      return reply.code(401).send({ error: "Invalid email or password" });
    }

    const session = await createSession(user.id, body.data.deviceName);
    return reply.code(200).send({ user: toPublicUser(user), ...session });
  });

  app.post("/v1/auth/refresh", { config: { rateLimit: AUTH_RATE_LIMIT } }, async (request, reply) => {
    const body = refreshSchema.safeParse(request.body);
    if (!body.success) {
      return reply.code(400).send({ error: "Invalid request body" });
    }

    try {
      const session = await rotateRefreshToken(body.data.refreshToken);
      return reply.code(200).send(session);
    } catch (error) {
      if (error instanceof RefreshTokenReuseError || error instanceof RefreshTokenInvalidError) {
        return reply.code(401).send({ error: error.message });
      }
      throw error;
    }
  });

  app.post("/v1/auth/logout", { config: { rateLimit: AUTH_RATE_LIMIT } }, async (request, reply) => {
    const body = refreshSchema.safeParse(request.body);
    if (!body.success) {
      return reply.code(400).send({ error: "Invalid request body" });
    }
    await revokeSession(body.data.refreshToken);
    return reply.code(204).send();
  });

  app.delete("/v1/me", { preHandler: requireAuth }, async (request, reply) => {
    const userId = request.userId!;
    await revokeAllSessionsForUser(userId);
    await db.delete(users).where(eq(users.id, userId));
    return reply.code(204).send();
  });
}

function toPublicUser(user: typeof users.$inferSelect) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    unitPreference: user.unitPreference,
  };
}
