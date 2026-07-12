import { describe, expect, it } from "vitest";
import { testApp, registerUser } from "./helpers.js";

describe("nutrition estimate", () => {
  it("rejects without auth", async () => {
    const app = await testApp();
    const response = await app.inject({
      method: "POST",
      url: "/v1/nutrition/estimate",
      payload: { description: "2 eggs and toast" },
    });
    expect(response.statusCode).toBe(401);
  });

  it("rejects an empty description", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/nutrition/estimate",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { description: "" },
    });
    expect(response.statusCode).toBe(400);
  });

  it("returns 503 when the estimate service has no API key configured (test env)", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/nutrition/estimate",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { description: "2 eggs and toast" },
    });

    // .env.test ships no GEMINI_API_KEY — this exercises the real
    // "unavailable" path rather than mocking the Anthropic client.
    expect(response.statusCode).toBe(503);
  });
});
