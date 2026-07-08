import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { requireAuth } from "../auth/middleware.js";
import { estimateMealMacros, EstimateUnavailableError } from "../nutrition/estimateClient.js";

const estimateRequestSchema = z.object({
  description: z.string().min(1).max(500),
});

// Generous enough for normal use, cheap enough to cap abuse of a paid
// upstream call (PLAN.md §5 rate-limiting posture, applied here too).
const ESTIMATE_RATE_LIMIT = { max: 20, timeWindow: "1 minute" };

export async function nutritionRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    "/v1/nutrition/estimate",
    { preHandler: requireAuth, config: { rateLimit: ESTIMATE_RATE_LIMIT } },
    async (request, reply) => {
      const body = estimateRequestSchema.safeParse(request.body);
      if (!body.success) {
        return reply.code(400).send({ error: "Invalid request body" });
      }

      try {
        const estimate = await estimateMealMacros(body.data.description);
        return reply.code(200).send(estimate);
      } catch (error) {
        if (error instanceof EstimateUnavailableError) {
          return reply.code(503).send({ error: "Estimate service temporarily unavailable" });
        }
        throw error;
      }
    }
  );
}
