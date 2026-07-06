import Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";
import { env } from "../env.js";

const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });

/// Cheapest/fastest current Claude model — right fit for a small per-meal
/// macro estimate (PLAN.md §1). Never call this without ANTHROPIC_API_KEY
/// set; the key lives only server-side.
const ESTIMATE_MODEL = "claude-haiku-4-5";

const estimateResponseSchema = z.object({
  calories: z.number().nonnegative(),
  protein: z.number().nonnegative(),
  carbs: z.number().nonnegative(),
  fat: z.number().nonnegative(),
  confidence: z.enum(["low", "medium", "high"]),
});

export type NutritionEstimate = z.infer<typeof estimateResponseSchema>;

const RESPONSE_JSON_SCHEMA = {
  type: "object",
  properties: {
    calories: { type: "number", description: "Estimated total calories (kcal) for the whole described portion" },
    protein: { type: "number", description: "Estimated protein in grams" },
    carbs: { type: "number", description: "Estimated carbohydrates in grams" },
    fat: { type: "number", description: "Estimated fat in grams" },
    confidence: {
      type: "string",
      enum: ["low", "medium", "high"],
      description: "How confident this estimate is, given how specific the description was",
    },
  },
  required: ["calories", "protein", "carbs", "fat", "confidence"],
  additionalProperties: false,
} as const;

export class EstimateUnavailableError extends Error {
  constructor(cause?: unknown) {
    super("Nutrition estimate service unavailable");
    this.cause = cause;
  }
}

/// Freeform "2 eggs and toast" -> structured macro estimate (PLAN.md §1/§3
/// — the escape hatch for foods not in USDA/OFF). Uses `output_config.format`
/// (structured outputs) so the response is guaranteed to match the schema;
/// the Zod re-validation below is defense-in-depth, not the primary guarantee.
export async function estimateMealMacros(description: string): Promise<NutritionEstimate> {
  if (!env.ANTHROPIC_API_KEY) {
    throw new EstimateUnavailableError();
  }

  let response;
  try {
    response = await anthropic.messages.create({
      model: ESTIMATE_MODEL,
      max_tokens: 256,
      system:
        "You estimate nutrition macros for a single freeform meal description. " +
        "Assume a typical single-serving portion unless the description states a quantity. " +
        "Respond with your best estimate even for vague descriptions, and set confidence accordingly.",
      messages: [{ role: "user", content: description }],
      output_config: { format: { type: "json_schema", schema: RESPONSE_JSON_SCHEMA } },
    });
  } catch (error) {
    throw new EstimateUnavailableError(error);
  }

  const textBlock = response.content.find((block) => block.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new EstimateUnavailableError("No text content in model response");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(textBlock.text);
  } catch (error) {
    throw new EstimateUnavailableError(error);
  }

  const result = estimateResponseSchema.safeParse(parsed);
  if (!result.success) {
    throw new EstimateUnavailableError(result.error);
  }
  return result.data;
}
