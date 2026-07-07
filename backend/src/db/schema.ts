import {
  pgTable,
  uuid,
  text,
  integer,
  doublePrecision,
  boolean,
  timestamp,
  jsonb,
  index,
  uniqueIndex,
} from "drizzle-orm/pg-core";

/**
 * Every syncable table shares this shape: client-generated `id` (offline-first —
 * never server-assigned), `userId` scoping, and `updatedAt`/`deletedAt` for the
 * LWW-with-tombstones conflict rule (PLAN.md §2). `dirty` is intentionally
 * client-only and has no server column.
 */
const syncableColumns = {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull(),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
};

export const users = pgTable("users", {
  id: uuid("id").primaryKey(),
  email: text("email").unique(),
  appleUserId: text("apple_user_id").unique(),
  passwordHash: text("password_hash"),
  displayName: text("display_name").notNull(),
  unitPreference: text("unit_preference", { enum: ["imperial", "metric"] })
    .notNull()
    .default("imperial"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const goals = pgTable("goals", {
  ...syncableColumns,
  calorieTarget: integer("calorie_target").notNull(),
  proteinG: integer("protein_g").notNull(),
  carbsG: integer("carbs_g").notNull(),
  fatG: integer("fat_g").notNull(),
  waterMl: integer("water_ml").notNull(),
  stepTarget: integer("step_target").notNull(),
  weightGoalKg: doublePrecision("weight_goal_kg"),
});

export const exercises = pgTable("exercises", {
  ...syncableColumns,
  name: text("name").notNull(),
  muscleGroups: jsonb("muscle_groups").$type<string[]>().notNull(),
  equipment: text("equipment").notNull(),
  isCustom: boolean("is_custom").notNull().default(true),
  archivedAt: timestamp("archived_at", { withTimezone: true }),
});

export const routines = pgTable("routines", {
  ...syncableColumns,
  name: text("name").notNull(),
  notes: text("notes").notNull().default(""),
  position: integer("position").notNull().default(0),
});

export const routineItems = pgTable("routine_items", {
  ...syncableColumns,
  routineId: uuid("routine_id").notNull().references(() => routines.id, { onDelete: "cascade" }),
  exerciseId: uuid("exercise_id").notNull(),
  position: integer("position").notNull(),
  targetSets: integer("target_sets").notNull().default(3),
  targetReps: integer("target_reps").notNull().default(8),
});

export const workouts = pgTable("workouts", {
  ...syncableColumns,
  startedAt: timestamp("started_at", { withTimezone: true }).notNull(),
  finishedAt: timestamp("finished_at", { withTimezone: true }),
  routineId: uuid("routine_id"),
  notes: text("notes").notNull().default(""),
});

export const workoutItems = pgTable("workout_items", {
  ...syncableColumns,
  workoutId: uuid("workout_id").notNull().references(() => workouts.id, { onDelete: "cascade" }),
  exerciseId: uuid("exercise_id").notNull(),
  position: integer("position").notNull(),
});

export const setEntries = pgTable("set_entries", {
  ...syncableColumns,
  workoutItemId: uuid("workout_item_id").notNull().references(() => workoutItems.id, { onDelete: "cascade" }),
  index: integer("index").notNull(),
  weightKg: doublePrecision("weight_kg").notNull(),
  reps: integer("reps").notNull(),
  rpe: doublePrecision("rpe"),
  isWarmup: boolean("is_warmup").notNull().default(false),
  completedAt: timestamp("completed_at", { withTimezone: true }),
});

export const personalRecords = pgTable("personal_records", {
  ...syncableColumns,
  exerciseId: uuid("exercise_id").notNull(),
  kind: text("kind", { enum: ["weight", "reps", "volume", "e1RM"] }).notNull(),
  value: doublePrecision("value").notNull(),
  setEntryId: uuid("set_entry_id").notNull(),
  achievedAt: timestamp("achieved_at", { withTimezone: true }).notNull(),
});

export const weightEntries = pgTable("weight_entries", {
  ...syncableColumns,
  date: timestamp("date", { withTimezone: true }).notNull(),
  weightKg: doublePrecision("weight_kg").notNull(),
});

export const measurementEntries = pgTable("measurement_entries", {
  ...syncableColumns,
  date: timestamp("date", { withTimezone: true }).notNull(),
  site: text("site", {
    enum: ["waist", "chest", "arm", "thigh", "hip", "neck", "calf"],
  }).notNull(),
  valueCm: doublePrecision("value_cm").notNull(),
});

// Progress photos are deliberately NOT synced (PLAN.md §2/§5) — no server table.

export const foodItems = pgTable("food_items", {
  ...syncableColumns,
  name: text("name").notNull(),
  brand: text("brand"),
  source: text("source", { enum: ["usda", "off", "custom", "estimate"] }).notNull(),
  barcode: text("barcode"),
  per100g: jsonb("per100g").$type<{ kcal: number; protein: number; carbs: number; fat: number }>().notNull(),
  servings: jsonb("servings").$type<{ label: string; grams: number }[]>().notNull().default([]),
  lastUsedAt: timestamp("last_used_at", { withTimezone: true }),
  useCount: integer("use_count").notNull().default(0),
});

export const savedMeals = pgTable("saved_meals", {
  ...syncableColumns,
  name: text("name").notNull(),
});

export const savedMealItems = pgTable("saved_meal_items", {
  ...syncableColumns,
  savedMealId: uuid("saved_meal_id").notNull().references(() => savedMeals.id, { onDelete: "cascade" }),
  foodItemId: uuid("food_item_id").notNull(),
  quantityG: doublePrecision("quantity_g").notNull(),
});

export const foodLogs = pgTable("food_logs", {
  ...syncableColumns,
  date: timestamp("date", { withTimezone: true }).notNull(),
  slot: text("slot", { enum: ["breakfast", "lunch", "dinner", "snack"] }).notNull(),
  foodItemId: uuid("food_item_id").notNull(),
  quantityG: doublePrecision("quantity_g").notNull(),
  macroSnapshot: jsonb("macro_snapshot").$type<{ kcal: number; protein: number; carbs: number; fat: number }>().notNull(),
});

export const waterEntries = pgTable("water_entries", {
  ...syncableColumns,
  date: timestamp("date", { withTimezone: true }).notNull(),
  amountMl: integer("amount_ml").notNull(),
});

export const sleepEntries = pgTable("sleep_entries", {
  ...syncableColumns,
  date: timestamp("date", { withTimezone: true }).notNull(),
  minutes: integer("minutes").notNull(),
  source: text("source", { enum: ["manual", "healthkit"] }).notNull().default("manual"),
});

// StepsCache is device-local only (PLAN.md §2) — no server table.

export const authSessions = pgTable(
  "auth_sessions",
  {
    id: uuid("id").primaryKey(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    refreshTokenHash: text("refresh_token_hash").notNull(),
    familyId: uuid("family_id").notNull(),
    deviceName: text("device_name").notNull().default("Unknown device"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
  },
  (table) => ({
    userIdx: index("auth_sessions_user_idx").on(table.userId),
    familyIdx: index("auth_sessions_family_idx").on(table.familyId),
    tokenHashIdx: uniqueIndex("auth_sessions_token_hash_idx").on(table.refreshTokenHash),
  })
);

/**
 * One cursor per user: the `updatedAt` of the newest record they've pulled
 * so far. `GET /v1/sync/pull` returns rows with `updatedAt` strictly after
 * this value across every syncable table and the client advances it to the
 * max `updatedAt` it received (PLAN.md §2 "per-user monotonic sync cursor").
 * A timestamp cursor is sufficient for a single-user-few-devices app; it
 * does not need the collision-proofing a shared multi-writer table would.
 */
export const changeCursors = pgTable("change_cursors", {
  userId: uuid("user_id")
    .primaryKey()
    .references(() => users.id, { onDelete: "cascade" }),
  cursor: timestamp("cursor", { withTimezone: true }),
});

export const SYNCABLE_TABLES = {
  goals,
  exercises,
  routines,
  routineItems,
  workouts,
  workoutItems,
  setEntries,
  personalRecords,
  weightEntries,
  measurementEntries,
  foodItems,
  savedMeals,
  savedMealItems,
  foodLogs,
  waterEntries,
  sleepEntries,
} as const;

export type SyncableTableName = keyof typeof SYNCABLE_TABLES;
