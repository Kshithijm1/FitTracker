import { afterAll, beforeEach } from "vitest";
import { sql } from "drizzle-orm";
import { db, pool } from "../src/db/client.js";

const ALL_TABLES = [
  "auth_sessions",
  "change_cursors",
  "food_logs",
  "saved_meal_items",
  "saved_meals",
  "food_items",
  "measurement_entries",
  "weight_entries",
  "personal_records",
  "set_entries",
  "workout_items",
  "workouts",
  "routine_items",
  "routines",
  "exercises",
  "water_entries",
  "sleep_entries",
  "goals",
  "users",
];

beforeEach(async () => {
  await db.execute(sql.raw(`TRUNCATE TABLE ${ALL_TABLES.join(", ")} CASCADE`));
});

afterAll(async () => {
  await pool.end();
});
