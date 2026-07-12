import { z } from "zod";
import { AIUnavailableError, completeStructured } from "../ai/client.js";

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
/// — the escape hatch for foods not in USDA/OFF). Delegates to the shared
/// Gemini client; the Zod re-validation below is defense-in-depth, not the
/// primary guarantee (Gemini's responseSchema already constrains the shape).
export async function estimateMealMacros(description: string): Promise<NutritionEstimate> {
  let raw: unknown;
  try {
    raw = await completeStructured({
      system:
        "You estimate nutrition macros for a single freeform meal description. " +
        "Assume a typical single-serving portion unless the description states a quantity. " +
        "Respond with your best estimate even for vague descriptions, and set confidence accordingly.",
      prompt: description,
      schema: RESPONSE_JSON_SCHEMA,
      maxTokens: 256,
    });
  } catch (error) {
    if (error instanceof AIUnavailableError) throw new EstimateUnavailableError(error);
    throw error;
  }

  const result = estimateResponseSchema.safeParse(raw);
  if (!result.success) {
    throw new EstimateUnavailableError(result.error);
  }
  return result.data;
}
