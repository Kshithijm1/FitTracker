import { env } from "../env.js";

/// Shared Gemini access for all /v1/ai routes. Free tier (no billing
/// account required at this volume) — key lives only server-side, callers
/// degrade gracefully when it's absent (503), responses are schema-constrained.
const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models";

/// Free-tier, multimodal, fast — right for short coaching replies and
/// small structured extractions with an optional photo. The "-latest" alias
/// tracks whichever Flash model Google currently points it at (verified
/// against gemini-3.5-flash), so this doesn't need bumping by hand.
export const AI_MODEL = "gemini-flash-latest";

export class AIUnavailableError extends Error {
  constructor(cause?: unknown) {
    super("AI service unavailable");
    this.cause = cause;
  }
}

type ImageInput = { base64: string; mediaType: "image/jpeg" | "image/png" };

type GeminiPart = { text: string } | { inline_data: { mime_type: string; data: string } };

async function callGemini(options: {
  system: string;
  parts: GeminiPart[];
  maxTokens: number;
  responseSchema?: Record<string, unknown>;
}): Promise<string> {
  if (!env.GEMINI_API_KEY) throw new AIUnavailableError();

  const generationConfig: Record<string, unknown> = {
    maxOutputTokens: options.maxTokens,
    // These are short, single-turn tasks (chat reply, or a schema-constrained
    // extraction) — extended thinking only eats into maxOutputTokens (seen
    // consuming 400+ tokens on a trivial prompt) and risks truncating the
    // actual answer before it's produced, so it's turned off.
    thinkingConfig: { thinkingBudget: 0 },
  };
  if (options.responseSchema) {
    generationConfig.responseMimeType = "application/json";
    generationConfig.responseSchema = options.responseSchema;
  }

  let response;
  try {
    response = await fetch(`${GEMINI_BASE_URL}/${AI_MODEL}:generateContent`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: options.system }] },
        contents: [{ role: "user", parts: options.parts }],
        generationConfig,
      }),
    });
  } catch (error) {
    throw new AIUnavailableError(error);
  }

  if (!response.ok) {
    throw new AIUnavailableError(await response.text().catch(() => response.statusText));
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch (error) {
    throw new AIUnavailableError(error);
  }

  const text = (body as { candidates?: { content?: { parts?: { text?: string }[] } }[] })
    .candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string") {
    throw new AIUnavailableError("No text content in model response");
  }
  return text;
}

/// Converts our JSON Schema (as used for Anthropic-style structured
/// outputs) into the OpenAPI-subset schema Gemini's responseSchema expects
/// (uppercase type constants, no additionalProperties, nullable instead of
/// a type union).
function toGeminiSchema(schema: any): any {
  if (Array.isArray(schema.type)) {
    const nonNullType = schema.type.find((t: string) => t !== "null");
    return { ...toGeminiSchema({ ...schema, type: nonNullType }), nullable: schema.type.includes("null") };
  }
  const result: Record<string, unknown> = { type: String(schema.type).toUpperCase() };
  if (schema.description) result.description = schema.description;
  if (schema.enum) result.enum = schema.enum;
  if (schema.properties) {
    result.properties = Object.fromEntries(
      Object.entries(schema.properties as Record<string, unknown>).map(([key, value]) => [
        key,
        toGeminiSchema(value),
      ])
    );
  }
  if (schema.required) result.required = schema.required;
  if (schema.items) result.items = toGeminiSchema(schema.items);
  if (schema.maxItems !== undefined) result.maxItems = schema.maxItems;
  if (schema.minimum !== undefined) result.minimum = schema.minimum;
  return result;
}

/// Plain text completion (coach chat).
export async function completeText(options: {
  system: string;
  prompt: string;
  maxTokens?: number;
}): Promise<string> {
  return callGemini({
    system: options.system,
    parts: [{ text: options.prompt }],
    maxTokens: options.maxTokens ?? 700,
  });
}

/// Structured completion with an optional image, constrained to a JSON
/// schema via Gemini's responseSchema. Returns the parsed (but not yet
/// Zod-validated) object; callers re-validate as defense-in-depth.
export async function completeStructured(options: {
  system: string;
  prompt: string;
  schema: Record<string, unknown>;
  image?: ImageInput;
  maxTokens?: number;
}): Promise<unknown> {
  const parts: GeminiPart[] = [];
  if (options.image) {
    parts.push({ inline_data: { mime_type: options.image.mediaType, data: options.image.base64 } });
  }
  parts.push({ text: options.prompt });

  const text = await callGemini({
    system: options.system,
    parts,
    maxTokens: options.maxTokens ?? 1500,
    responseSchema: toGeminiSchema(options.schema),
  });

  try {
    return JSON.parse(text);
  } catch (error) {
    throw new AIUnavailableError(error);
  }
}
