import { describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { testApp, registerUser } from "./helpers.js";

describe("auth", () => {
  it("registers a new user and returns a session", async () => {
    const app: FastifyInstance = await testApp();
    const response = await app.inject({
      method: "POST",
      url: "/v1/auth/register",
      payload: { email: "alice@example.com", password: "correct-horse-battery-staple", displayName: "Alice" },
    });

    expect(response.statusCode).toBe(201);
    const body = response.json();
    expect(body.user.email).toBe("alice@example.com");
    expect(body.accessToken).toEqual(expect.any(String));
    expect(body.refreshToken).toEqual(expect.any(String));
  });

  it("rejects registering the same email twice", async () => {
    const app = await testApp();
    await registerUser(app, { email: "dupe@example.com" });

    const response = await app.inject({
      method: "POST",
      url: "/v1/auth/register",
      payload: { email: "dupe@example.com", password: "correct-horse-battery-staple", displayName: "Dupe" },
    });

    expect(response.statusCode).toBe(409);
  });

  it("logs in with correct credentials", async () => {
    const app = await testApp();
    await registerUser(app, { email: "bob@example.com", password: "correct-horse-battery-staple" });

    const response = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: "bob@example.com", password: "correct-horse-battery-staple" },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().accessToken).toEqual(expect.any(String));
  });

  it("rejects login with the wrong password", async () => {
    const app = await testApp();
    await registerUser(app, { email: "carol@example.com", password: "correct-horse-battery-staple" });

    const response = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: "carol@example.com", password: "wrong-password" },
    });

    expect(response.statusCode).toBe(401);
  });

  it("rejects login for an email that doesn't exist with the same error as a wrong password", async () => {
    const app = await testApp();
    const response = await app.inject({
      method: "POST",
      url: "/v1/auth/login",
      payload: { email: "nobody@example.com", password: "whatever12345" },
    });

    expect(response.statusCode).toBe(401);
    expect(response.json().error).toBe("Invalid email or password");
  });

  it("rejects a protected route without a bearer token", async () => {
    const app = await testApp();
    const response = await app.inject({ method: "DELETE", url: "/v1/me" });
    expect(response.statusCode).toBe(401);
  });

  it("allows DELETE /v1/me with a valid access token and revokes it after", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const deleteResponse = await app.inject({
      method: "DELETE",
      url: "/v1/me",
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(deleteResponse.statusCode).toBe(204);
  });

  describe("refresh token rotation", () => {
    it("rotates the refresh token and issues a new access token", async () => {
      const app = await testApp();
      const { refreshToken } = await registerUser(app);

      const response = await app.inject({
        method: "POST",
        url: "/v1/auth/refresh",
        payload: { refreshToken },
      });

      expect(response.statusCode).toBe(200);
      const body = response.json();
      expect(body.refreshToken).not.toBe(refreshToken);
    });

    it("rejects reuse of an already-rotated refresh token", async () => {
      const app = await testApp();
      const { refreshToken } = await registerUser(app);

      // First use rotates it successfully.
      await app.inject({ method: "POST", url: "/v1/auth/refresh", payload: { refreshToken } });

      // Second use of the SAME (now-stale) token is a reuse/replay attempt.
      const reuseResponse = await app.inject({
        method: "POST",
        url: "/v1/auth/refresh",
        payload: { refreshToken },
      });

      expect(reuseResponse.statusCode).toBe(401);
      expect(reuseResponse.json().error).toMatch(/reuse detected/i);
    });

    it("revokes the whole session family after a reuse is detected", async () => {
      const app = await testApp();
      const { refreshToken } = await registerUser(app);

      const rotated = await app.inject({ method: "POST", url: "/v1/auth/refresh", payload: { refreshToken } });
      const newRefreshToken = rotated.json().refreshToken;

      // Trigger reuse detection on the original token.
      await app.inject({ method: "POST", url: "/v1/auth/refresh", payload: { refreshToken } });

      // The legitimately-rotated token should now ALSO be revoked (family-wide).
      const response = await app.inject({
        method: "POST",
        url: "/v1/auth/refresh",
        payload: { refreshToken: newRefreshToken },
      });

      expect(response.statusCode).toBe(401);
    });

    it("rejects an unknown refresh token", async () => {
      const app = await testApp();
      const response = await app.inject({
        method: "POST",
        url: "/v1/auth/refresh",
        payload: { refreshToken: "not-a-real-token" },
      });
      expect(response.statusCode).toBe(401);
    });
  });

  describe("rate limiting", () => {
    it("throttles after 5 requests/minute on the login route", async () => {
      const app = await testApp();
      const attempt = () =>
        app.inject({
          method: "POST",
          url: "/v1/auth/login",
          payload: { email: "rate-limited@example.com", password: "whatever12345" },
        });

      const statuses: number[] = [];
      for (let i = 0; i < 6; i++) {
        statuses.push((await attempt()).statusCode);
      }

      expect(statuses.slice(0, 5).every((s) => s === 401)).toBe(true);
      expect(statuses[5]).toBe(429);
    });
  });
});
