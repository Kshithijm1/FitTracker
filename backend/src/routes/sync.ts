import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { z } from "zod";
import { requireAuth } from "../auth/middleware.js";
import { db } from "../db/client.js";
import { changeCursors } from "../db/schema.js";
import { pushRequestSchema } from "../sync/schemas.js";
import { applyIncomingRecord, advanceCursor } from "../sync/engine.js";
import { pullChangesSince, maxUpdatedAt } from "../sync/pull.js";
import type { SyncableTableName } from "../db/schema.js";

const pullQuerySchema = z.object({
  cursor: z.coerce.date().optional(),
});

// Sync runs far more often than auth, so it gets a much higher ceiling —
// this exists to blunt a buggy/malicious client hammering the endpoint
// (API4: Unrestricted Resource Consumption), not to throttle normal use.
const SYNC_RATE_LIMIT = { max: 60, timeWindow: "1 minute" };

export async function syncRoutes(app: FastifyInstance): Promise<void> {
  app.post("/v1/sync/push", { preHandler: requireAuth, config: { rateLimit: SYNC_RATE_LIMIT } }, async (request, reply) => {
    const userId = request.userId!;
    const body = pushRequestSchema.safeParse(request.body);
    if (!body.success) {
      return reply.code(400).send({ error: "Invalid request body", details: body.error.flatten() });
    }

    const results = [];
    let newestUpdatedAt: Date | null = null;

    for (const [table, records] of Object.entries(body.data.changes) as [
      SyncableTableName,
      Record<string, unknown>[],
    ][]) {
      for (const record of records) {
        const result = await applyIncomingRecord(
          table,
          userId,
          record as { id: string; updatedAt: Date; deletedAt?: Date | null }
        );
        results.push(result);
        const updatedAt = record.updatedAt as Date;
        if (!newestUpdatedAt || updatedAt.getTime() > newestUpdatedAt.getTime()) {
          newestUpdatedAt = updatedAt;
        }
      }
    }

    await advanceCursor(userId, newestUpdatedAt);

    return reply.code(200).send({ results });
  });

  app.get("/v1/sync/pull", { preHandler: requireAuth, config: { rateLimit: SYNC_RATE_LIMIT } }, async (request, reply) => {
    const userId = request.userId!;
    const query = pullQuerySchema.safeParse(request.query);
    if (!query.success) {
      return reply.code(400).send({ error: "Invalid query params" });
    }

    const changes = await pullChangesSince(userId, query.data.cursor ?? null);
    const newCursor = maxUpdatedAt(changes) ?? query.data.cursor ?? null;

    return reply.code(200).send({ changes, cursor: newCursor });
  });

  app.get("/v1/sync/cursor", { preHandler: requireAuth }, async (request, reply) => {
    const userId = request.userId!;
    const [row] = await db.select().from(changeCursors).where(eq(changeCursors.userId, userId));
    return reply.code(200).send({ cursor: row?.cursor ?? null });
  });
}
