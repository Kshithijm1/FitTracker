import { and, eq, gt } from "drizzle-orm";
import type { PgTable } from "drizzle-orm/pg-core";
import { db } from "../db/client.js";
import { SYNCABLE_TABLES, type SyncableTableName } from "../db/schema.js";

export type PullChanges = Partial<Record<SyncableTableName, Record<string, unknown>[]>>;

/**
 * Returns every row changed for this user since `cursor` (exclusive),
 * across all syncable tables. Tombstoned rows (`deletedAt` set) are
 * included so the client can apply the delete locally too.
 */
export async function pullChangesSince(userId: string, cursor: Date | null): Promise<PullChanges> {
  const changes: PullChanges = {};

  for (const tableName of Object.keys(SYNCABLE_TABLES) as SyncableTableName[]) {
    const pgTable = SYNCABLE_TABLES[tableName] as PgTable & { userId: unknown; updatedAt: unknown };

    const whereClause = cursor
      ? and(eq(pgTable.userId as never, userId), gt(pgTable.updatedAt as never, cursor))
      : eq(pgTable.userId as never, userId);

    const rows = await db.select().from(pgTable as never).where(whereClause);
    if (rows.length > 0) {
      changes[tableName] = rows as Record<string, unknown>[];
    }
  }

  return changes;
}

/** The new cursor to hand back to the client: the newest `updatedAt` across everything just pulled. */
export function maxUpdatedAt(changes: PullChanges): Date | null {
  let max: Date | null = null;
  for (const rows of Object.values(changes)) {
    for (const row of rows ?? []) {
      const updatedAt = row.updatedAt as Date;
      if (!max || updatedAt.getTime() > max.getTime()) {
        max = updatedAt;
      }
    }
  }
  return max;
}
