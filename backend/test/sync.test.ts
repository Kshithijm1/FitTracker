import { describe, expect, it } from "vitest";
import { randomUUID } from "node:crypto";
import { testApp, registerUser } from "./helpers.js";

async function push(app: Awaited<ReturnType<typeof testApp>>, accessToken: string, changes: unknown) {
  return app.inject({
    method: "POST",
    url: "/v1/sync/push",
    headers: { authorization: `Bearer ${accessToken}` },
    payload: { changes },
  });
}

async function pull(app: Awaited<ReturnType<typeof testApp>>, accessToken: string, cursor?: string) {
  return app.inject({
    method: "GET",
    url: cursor ? `/v1/sync/pull?cursor=${encodeURIComponent(cursor)}` : "/v1/sync/pull",
    headers: { authorization: `Bearer ${accessToken}` },
  });
}

describe("sync", () => {
  it("rejects push and pull without auth", async () => {
    const app = await testApp();
    expect((await push(app, "", {})).statusCode).toBe(401);
    expect((await pull(app, "")).statusCode).toBe(401);
  });

  it("applies a brand-new record on first push", async () => {
    const app = await testApp();
    const { accessToken } = await registerUser(app);
    const id = randomUUID();

    const response = await push(app, accessToken, {
      weightEntries: [{ id, updatedAt: "2026-01-01T00:00:00Z", date: "2026-01-01T00:00:00Z", weightKg: 80 }],
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().results[0]).toMatchObject({ id, status: "applied" });
  });

  it("pull returns everything pushed, scoped to the authenticated user", async () => {
    const app = await testApp();
    const alice = await registerUser(app, { email: "alice-sync@example.com" });
    const bob = await registerUser(app, { email: "bob-sync@example.com" });
    const id = randomUUID();

    await push(app, alice.accessToken, {
      weightEntries: [{ id, updatedAt: "2026-01-01T00:00:00Z", date: "2026-01-01T00:00:00Z", weightKg: 80 }],
    });

    const aliceResult = await pull(app, alice.accessToken);
    expect(aliceResult.json().changes.weightEntries).toHaveLength(1);

    const bobResult = await pull(app, bob.accessToken);
    expect(bobResult.json().changes.weightEntries ?? []).toHaveLength(0);
  });

  describe("last-write-wins conflict resolution (PLAN.md §2)", () => {
    it("a newer updatedAt overwrites an older one", async () => {
      const app = await testApp();
      const { accessToken } = await registerUser(app);
      const id = randomUUID();

      await push(app, accessToken, {
        weightEntries: [{ id, updatedAt: "2026-01-01T00:00:00Z", date: "2026-01-01T00:00:00Z", weightKg: 80 }],
      });
      const second = await push(app, accessToken, {
        weightEntries: [{ id, updatedAt: "2026-01-02T00:00:00Z", date: "2026-01-02T00:00:00Z", weightKg: 79 }],
      });

      expect(second.json().results[0].status).toBe("applied");

      const result = await pull(app, accessToken);
      expect(result.json().changes.weightEntries[0].weightKg).toBe(79);
    });

    it("an older (stale) updatedAt is rejected and does not overwrite", async () => {
      const app = await testApp();
      const { accessToken } = await registerUser(app);
      const id = randomUUID();

      await push(app, accessToken, {
        weightEntries: [{ id, updatedAt: "2026-01-02T00:00:00Z", date: "2026-01-02T00:00:00Z", weightKg: 79 }],
      });
      const stale = await push(app, accessToken, {
        weightEntries: [{ id, updatedAt: "2026-01-01T00:00:00Z", date: "2026-01-01T00:00:00Z", weightKg: 999 }],
      });

      expect(stale.json().results[0].status).toBe("skipped_stale");

      const result = await pull(app, accessToken);
      expect(result.json().changes.weightEntries[0].weightKg).toBe(79);
    });

    it("a tombstone wins over a non-deleted update at the exact same updatedAt", async () => {
      const app = await testApp();
      const { accessToken } = await registerUser(app);
      const id = randomUUID();
      const sameTimestamp = "2026-01-01T00:00:00.000Z";

      await push(app, accessToken, {
        weightEntries: [{ id, updatedAt: sameTimestamp, date: sameTimestamp, weightKg: 80 }],
      });
      const tombstone = await push(app, accessToken, {
        weightEntries: [
          { id, updatedAt: sameTimestamp, date: sameTimestamp, weightKg: 80, deletedAt: sameTimestamp },
        ],
      });

      expect(tombstone.json().results[0].status).toBe("applied");

      const result = await pull(app, accessToken);
      expect(result.json().changes.weightEntries[0].deletedAt).not.toBeNull();
    });

    it("an update does not win over an existing tombstone at the same timestamp", async () => {
      const app = await testApp();
      const { accessToken } = await registerUser(app);
      const id = randomUUID();
      const sameTimestamp = "2026-01-01T00:00:00.000Z";

      await push(app, accessToken, {
        weightEntries: [
          { id, updatedAt: sameTimestamp, date: sameTimestamp, weightKg: 80, deletedAt: sameTimestamp },
        ],
      });
      const nonDeletedUpdate = await push(app, accessToken, {
        weightEntries: [{ id, updatedAt: sameTimestamp, date: sameTimestamp, weightKg: 999 }],
      });

      expect(nonDeletedUpdate.json().results[0].status).toBe("skipped_stale");

      const result = await pull(app, accessToken);
      expect(result.json().changes.weightEntries[0].deletedAt).not.toBeNull();
    });

    it("rejects a push that targets a record id owned by a different user", async () => {
      const app = await testApp();
      const alice = await registerUser(app, { email: "alice-owner@example.com" });
      const bob = await registerUser(app, { email: "bob-owner@example.com" });
      const id = randomUUID();

      await push(app, alice.accessToken, {
        weightEntries: [{ id, updatedAt: "2026-01-01T00:00:00Z", date: "2026-01-01T00:00:00Z", weightKg: 80 }],
      });

      const attack = await push(app, bob.accessToken, {
        weightEntries: [{ id, updatedAt: "2026-01-02T00:00:00Z", date: "2026-01-02T00:00:00Z", weightKg: 1 }],
      });

      expect(attack.json().results[0].status).toBe("rejected_not_owner");

      const aliceResult = await pull(app, alice.accessToken);
      expect(aliceResult.json().changes.weightEntries[0].weightKg).toBe(80);
    });
  });

  describe("cursor pagination", () => {
    it("pull with a cursor only returns records updated after it", async () => {
      const app = await testApp();
      const { accessToken } = await registerUser(app);

      await push(app, accessToken, {
        weightEntries: [
          { id: randomUUID(), updatedAt: "2026-01-01T00:00:00Z", date: "2026-01-01T00:00:00Z", weightKg: 80 },
        ],
      });
      const firstPull = await pull(app, accessToken);
      const cursor = firstPull.json().cursor;

      await push(app, accessToken, {
        weightEntries: [
          { id: randomUUID(), updatedAt: "2026-01-02T00:00:00Z", date: "2026-01-02T00:00:00Z", weightKg: 81 },
        ],
      });

      const secondPull = await pull(app, accessToken, cursor);
      expect(secondPull.json().changes.weightEntries).toHaveLength(1);
      expect(secondPull.json().changes.weightEntries[0].weightKg).toBe(81);
    });
  });
});
