import Anthropic from "@anthropic-ai/sdk";
import { env } from "../env.js";

/// Shared Claude access for all /v1/ai routes. Same posture as the
/// nutrition estimator: key lives only server-side, callers degrade
/// gracefully when it's absent (503), responses are schema-constrained.
const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });

/// Cheapest/fastest current model — right for short coaching replies and
/// small structured extractions. All heavy personal context stays compact
/// (the iOS client sends a plain-text stat block, not raw records).
export const AI_MODEL = "claude-haiku-4-5";

export class AIUnavailableError extends Error {
  constructor(cause?: unknown) {
    super("AI service unavailable");
    this.cause = cause;
  }
}

type ImageInput = { base64: string; mediaType: "image/jpeg" | "image/png" };

/// Plain text completion (coach chat).
export async function completeText(options: {
  system: string;
  prompt: string;
  maxTokens?: number;
}): Promise<string> {
  if (!env.ANTHROPIC_API_KEY) throw new AIUnavailableError();

  let response;
  try {
    response = await anthropic.messages.create({
      model: AI_MODEL,
      max_tokens: options.maxTokens ?? 700,
      system: options.system,
      messages: [{ role: "user", content: options.prompt }],
    });
  } catch (error) {
    throw new AIUnavailableError(error);
  }

  const textBlock = response.content.find((block) => block.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new AIUnavailableError("No text content in model response");
  }
  return textBlock.text;
}

/// Structured completion with an optional image, constrained to a JSON
/// schema via structured outputs. Returns the parsed (but not yet
/// Zod-validated) object; callers re-validate as defense-in-depth.
export async function completeStructured(options: {
  system: string;
  prompt: string;
  schema: Record<string, unknown>;
  image?: ImageInput;
  maxTokens?: number;
}): Promise<unknown> {
  if (!env.ANTHROPIC_API_KEY) throw new AIUnavailableError();

  const content: Anthropic.ContentBlockParam[] = [];
  if (options.image) {
    content.push({
      type: "image",
      source: {
        type: "base64",
        media_type: options.image.mediaType,
        data: options.image.base64,
      },
    });
  }
  content.push({ type: "text", text: options.prompt });

  let response;
  try {
    response = await anthropic.messages.create({
      model: AI_MODEL,
      max_tokens: options.maxTokens ?? 1500,
      system: options.system,
      messages: [{ role: "user", content }],
      output_config: { format: { type: "json_schema", schema: options.schema } },
    });
  } catch (error) {
    throw new AIUnavailableError(error);
  }

  const textBlock = response.content.find((block) => block.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new AIUnavailableError("No text content in model response");
  }
  try {
    return JSON.parse(textBlock.text);
  } catch (error) {
    throw new AIUnavailableError(error);
  }
}
