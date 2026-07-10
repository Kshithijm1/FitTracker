import { describe, expect, it } from "vitest";
import { testApp, registerUser } from "./helpers.js";
import { htmlToText } from "../src/ai/safeFetch.js";

// A tiny valid-looking base64 payload (well over the 100-char minimum).
const FAKE_IMAGE_BASE64 = "aGVsbG8".repeat(40) + "=";

describe("ai routes", () => {
  it("rejects all AI routes without auth", async () => {
    const app = await testApp();
    for (const url of ["/v1/ai/chat", "/v1/ai/food-photo", "/v1/ai/equipment-photo", "/v1/ai/recipe-import"]) {
      const response = await app.inject({ method: "POST", url, payload: {} });
      expect(response.statusCode, url).toBe(401);
    }
  });

  it("validates the chat body", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/ai/chat",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { instructions: "", prompt: "" },
    });
    expect(response.statusCode).toBe(400);
  });

  it("returns 503 for chat when no API key is configured (test env)", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/ai/chat",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { instructions: "You are a coach.", prompt: "How am I doing?" },
    });
    expect(response.statusCode).toBe(503);
  });

  it("rejects a food photo that is not base64", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/ai/food-photo",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { imageBase64: "not base64!!! ***".repeat(20) },
    });
    expect(response.statusCode).toBe(400);
  });

  it("returns 503 for a valid photo body when no API key is configured", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/ai/equipment-photo",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { imageBase64: FAKE_IMAGE_BASE64, userContext: "goal: build muscle" },
    });
    expect(response.statusCode).toBe(503);
  });

  it("refuses recipe-import URLs that are not https", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/ai/recipe-import",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { source: "http://169.254.169.254/latest/meta-data" },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error).toMatch(/paste the recipe text/i);
  });

  it("refuses recipe-import URLs that resolve to private addresses", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/ai/recipe-import",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { source: "https://127.0.0.1/recipe" },
    });
    expect(response.statusCode).toBe(400);
  });

  it("treats pasted recipe text (no URL) as text and hits the AI path (503 without key)", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/ai/recipe-import",
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { source: "Chicken rice bowl: 200g chicken breast, 150g rice, serves 2" },
    });
    expect(response.statusCode).toBe(503);
  });
});

describe("htmlToText", () => {
  it("strips scripts, styles, and tags", () => {
    const html = "<html><script>evil()</script><style>.x{}</style><p>Two eggs &amp; toast</p></html>";
    expect(htmlToText(html)).toBe("Two eggs & toast");
  });

  it("caps output length", () => {
    expect(htmlToText("<p>" + "a".repeat(50_000) + "</p>", 1000)).toHaveLength(1000);
  });
});
