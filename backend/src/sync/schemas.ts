import { z } from "zod";
import type { SyncableTableName } from "../db/schema.js";

/// One Zod schema per syncable table, validating exactly the fields a
/// client is allowed to push. `userId` is deliberately absent from every
/// schema — it always comes from the authenticated request, never the
/// body (PLAN.md §5).
const base = {
  id: z.string().uuid(),
  updatedAt: z.coerce.date(),
  deletedAt: z.coerce.date().nullable().optional(),
};

const macroSet = z.object({
  kcal: z.number(),
  protein: z.number(),
  carbs: z.number(),
  fat: z.number(),
});

const serving = z.object({
  label: z.string(),
  grams: z.number(),
});

export const syncSchemas = {
  goals: z.object({
    ...base,
    calorieTarget: z.number().int(),
    proteinG: z.number().int(),
    carbsG: z.number().int(),
    fatG: z.number().int(),
    waterMl: z.number().int(),
    stepTarget: z.number().int(),
    weightGoalKg: z.number().nullable().optional(),
  }),
  exercises: z.object({
    ...base,
    name: z.string().min(1).max(120),
    muscleGroups: z.array(z.string()),
    equipment: z.string().min(1).max(60),
    isCustom: z.boolean(),
    archivedAt: z.coerce.date().nullable().optional(),
  }),
  routines: z.object({
    ...base,
    name: z.string().min(1).max(120),
    notes: z.string().max(2000),
    position: z.number().int(),
  }),
  routineItems: z.object({
    ...base,
    routineId: z.string().uuid(),
    exerciseId: z.string().uuid(),
    position: z.number().int(),
    targetSets: z.number().int(),
    targetReps: z.number().int(),
  }),
  workouts: z.object({
    ...base,
    startedAt: z.coerce.date(),
    finishedAt: z.coerce.date().nullable().optional(),
    routineId: z.string().uuid().nullable().optional(),
    notes: z.string().max(2000),
  }),
  workoutItems: z.object({
    ...base,
    workoutId: z.string().uuid(),
    exerciseId: z.string().uuid(),
    position: z.number().int(),
  }),
  setEntries: z.object({
    ...base,
    workoutItemId: z.string().uuid(),
    index: z.number().int(),
    weightKg: z.number(),
    reps: z.number().int(),
    rpe: z.number().nullable().optional(),
    isWarmup: z.boolean(),
    completedAt: z.coerce.date().nullable().optional(),
  }),
  personalRecords: z.object({
    ...base,
    exerciseId: z.string().uuid(),
    kind: z.enum(["weight", "reps", "volume", "e1RM"]),
    value: z.number(),
    setEntryId: z.string().uuid(),
    achievedAt: z.coerce.date(),
  }),
  weightEntries: z.object({
    ...base,
    date: z.coerce.date(),
    weightKg: z.number(),
  }),
  measurementEntries: z.object({
    ...base,
    date: z.coerce.date(),
    site: z.enum(["waist", "chest", "arm", "thigh", "hip", "neck", "calf"]),
    valueCm: z.number(),
  }),
  foodItems: z.object({
    ...base,
    name: z.string().min(1).max(200),
    brand: z.string().max(200).nullable().optional(),
    source: z.enum(["usda", "off", "custom", "estimate"]),
    barcode: z.string().max(64).nullable().optional(),
    per100g: macroSet,
    servings: z.array(serving),
    lastUsedAt: z.coerce.date().nullable().optional(),
    useCount: z.number().int(),
  }),
  savedMeals: z.object({
    ...base,
    name: z.string().min(1).max(120),
  }),
  savedMealItems: z.object({
    ...base,
    savedMealId: z.string().uuid(),
    foodItemId: z.string().uuid(),
    quantityG: z.number(),
  }),
  foodLogs: z.object({
    ...base,
    date: z.coerce.date(),
    slot: z.enum(["breakfast", "lunch", "dinner", "snack"]),
    foodItemId: z.string().uuid(),
    quantityG: z.number(),
    macroSnapshot: macroSet,
  }),
  waterEntries: z.object({
    ...base,
    date: z.coerce.date(),
    amountMl: z.number().int(),
  }),
  sleepEntries: z.object({
    ...base,
    date: z.coerce.date(),
    minutes: z.number().int(),
    source: z.enum(["manual", "healthkit"]),
  }),
} satisfies Record<SyncableTableName, z.ZodTypeAny>;

// Caps how many records one push can carry per table — a client with a huge
// backlog just makes more requests. Without this, a single request's array
// length is otherwise unbounded (API4: Unrestricted Resource Consumption).
const MAX_RECORDS_PER_TABLE = 500;

export const pushRequestSchema = z.object({
  changes: z
    .object(
      Object.fromEntries(
        Object.entries(syncSchemas).map(([table, schema]) => [
          table,
          z.array(schema).max(MAX_RECORDS_PER_TABLE).default([]),
        ])
      ) as unknown as Record<SyncableTableName, z.ZodTypeAny>
    )
    .partial(),
});

export type PushRequest = z.infer<typeof pushRequestSchema>;
