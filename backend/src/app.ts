import Fastify, { type FastifyInstance, type FastifyError } from "fastify";
import rateLimit from "@fastify/rate-limit";
import { env } from "./env.js";
import { authRoutes } from "./routes/auth.js";
import { syncRoutes } from "./routes/sync.js";
import { nutritionRoutes } from "./routes/nutrition.js";

export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger: env.NODE_ENV !== "test",
  });

  // Registered globally but inactive by default (`global: false`) so only
  // routes that opt in via `config.rateLimit` are throttled — currently
  // just the auth routes (PLAN.md §5).
  await app.register(rateLimit, { global: false });

  await app.register(authRoutes);
  await app.register(syncRoutes);
  await app.register(nutritionRoutes);

  app.get("/health", async () => ({ status: "ok" }));

  // Audit-friendly error responses: never leak stack traces or internal
  // messages to the client (PLAN.md §5).
  app.setErrorHandler((error: FastifyError, request, reply) => {
    request.log.error(error);
    const statusCode = error.statusCode ?? 500;
    if (statusCode >= 500) {
      return reply.code(statusCode).send({ error: "Internal server error" });
    }
    return reply.code(statusCode).send({ error: error.message });
  });

  return app;
}
