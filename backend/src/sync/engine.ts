import { randomUUID } from "node:crypto";
import { eq } from "drizzle-orm";
import type { PgTable } from "drizzle-orm/pg-core";
import { db } from "../db/client.js";
import { SYNCABLE_TABLES, type SyncableTableName } from "../db/schema.js";

export type PushResultStatus = "applied" | "skipped_stale" | "rejected_not_owner";

export interface PushResult {
  table: SyncableTableName;
  id: string;
  status: PushResultStatus;
}

/**
 * Applies one incoming record with the conflict rule from PLAN.md §2:
 * per-record last-write-wins on `updatedAt`, tombstones win ties. Runs
 * per-record (not batched) so one bad row can't fail an entire push.
 */
export async function applyIncomingRecord(
  table: SyncableTableName,
  userId: string,
  record: Record<string, unknown> & { id: string; updatedAt: Date; deletedAt?: Date | null }
): Promise<PushResult> {
  const pgTable = SYNCABLE_TABLES[table] as PgTable & {
    id: unknown;
    userId: unknown;
    updatedAt: unknown;
  };

  const existingRows = await db
    .select()
    .from(pgTable as never)
    .where(eq(pgTable.id as never, record.id));
  const existing = existingRows[0] as
    | { id: string; userId: string; updatedAt: Date; deletedAt: Date | null }
    | undefined;

  if (existing && existing.userId !== userId) {
    return { table, id: record.id, status: "rejected_not_owner" };
  }

  if (!existing) {
    await db.insert(pgTable as never).values({ ...record, userId } as never);
    return { table, id: record.id, status: "applied" };
  }

  const incomingIsNewer = record.updatedAt.getTime() > existing.updatedAt.getTime();
  const isTombstoneTie =
    record.updatedAt.getTime() === existing.updatedAt.getTime() &&
    !!record.deletedAt &&
    !existing.deletedAt;

  if (!incomingIsNewer && !isTombstoneTie) {
    return { table, id: record.id, status: "skipped_stale" };
  }

  const { id: _id, ...updateFields } = record;
  await db
    .update(pgTable as never)
    .set(updateFields as never)
    .where(eq(pgTable.id as never, record.id));

  return { table, id: record.id, status: "applied" };
}

/** Advances the user's pull cursor to the newest `updatedAt` seen this push. */
export async function advanceCursor(userId: string, maxUpdatedAt: Date | null): Promise<void> {
  if (!maxUpdatedAt) return;

  const { changeCursors } = await import("../db/schema.js");
  const [existing] = await db.select().from(changeCursors).where(eq(changeCursors.userId, userId));

  if (!existing) {
    await db.insert(changeCursors).values({ userId, cursor: maxUpdatedAt });
    return;
  }
  if (!existing.cursor || maxUpdatedAt.getTime() > existing.cursor.getTime()) {
    await db.update(changeCursors).set({ cursor: maxUpdatedAt }).where(eq(changeCursors.userId, userId));
  }
}

export function randomId(): string {
  return randomUUID();
}
