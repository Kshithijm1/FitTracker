import { buildApp } from "../src/app.js";
import type { FastifyInstance } from "fastify";

export async function testApp(): Promise<FastifyInstance> {
  return buildApp();
}

export interface RegisteredUser {
  userId: string;
  accessToken: string;
  refreshToken: string;
}

export async function registerUser(
  app: FastifyInstance,
  overrides: Partial<{ email: string; password: string; displayName: string }> = {}
): Promise<RegisteredUser> {
  const response = await app.inject({
    method: "POST",
    url: "/v1/auth/register",
    payload: {
      email: overrides.email ?? `user-${crypto.randomUUID()}@example.com`,
      password: overrides.password ?? "correct-horse-battery-staple",
      displayName: overrides.displayName ?? "Test User",
    },
  });
  const body = response.json();
  return { userId: body.user.id, accessToken: body.accessToken, refreshToken: body.refreshToken };
}
