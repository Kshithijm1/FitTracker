import type { FastifyReply, FastifyRequest } from "fastify";
import { verifyAccessToken } from "./tokens.js";

declare module "fastify" {
  interface FastifyRequest {
    userId?: string;
  }
}

/// Every protected route uses this preHandler. `request.userId` is the
/// ONLY source of identity for authenticated routes (PLAN.md §5) — route
/// handlers must never trust a userId from the request body.
export async function requireAuth(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const header = request.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    return reply.code(401).send({ error: "Missing bearer token" });
  }

  try {
    const claims = await verifyAccessToken(header.slice("Bearer ".length));
    request.userId = claims.sub;
  } catch {
    return reply.code(401).send({ error: "Invalid or expired access token" });
  }
}
