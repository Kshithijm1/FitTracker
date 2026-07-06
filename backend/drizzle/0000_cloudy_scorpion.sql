CREATE TABLE "auth_sessions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"refresh_token_hash" text NOT NULL,
	"family_id" uuid NOT NULL,
	"device_name" text DEFAULT 'Unknown device' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "change_cursors" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"cursor" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "exercises" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"name" text NOT NULL,
	"muscle_groups" jsonb NOT NULL,
	"equipment" text NOT NULL,
	"is_custom" boolean DEFAULT true NOT NULL,
	"archived_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "food_items" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"name" text NOT NULL,
	"brand" text,
	"source" text NOT NULL,
	"barcode" text,
	"per100g" jsonb NOT NULL,
	"servings" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"last_used_at" timestamp with time zone,
	"use_count" integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE "food_logs" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"date" timestamp with time zone NOT NULL,
	"slot" text NOT NULL,
	"food_item_id" uuid NOT NULL,
	"quantity_g" double precision NOT NULL,
	"macro_snapshot" jsonb NOT NULL
);
--> statement-breakpoint
CREATE TABLE "goals" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"calorie_target" integer NOT NULL,
	"protein_g" integer NOT NULL,
	"carbs_g" integer NOT NULL,
	"fat_g" integer NOT NULL,
	"water_ml" integer NOT NULL,
	"step_target" integer NOT NULL,
	"weight_goal_kg" double precision
);
--> statement-breakpoint
CREATE TABLE "measurement_entries" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"date" timestamp with time zone NOT NULL,
	"site" text NOT NULL,
	"value_cm" double precision NOT NULL
);
--> statement-breakpoint
CREATE TABLE "personal_records" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"exercise_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"value" double precision NOT NULL,
	"set_entry_id" uuid NOT NULL,
	"achieved_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE "routine_items" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"routine_id" uuid NOT NULL,
	"exercise_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"target_sets" integer DEFAULT 3 NOT NULL,
	"target_reps" integer DEFAULT 8 NOT NULL
);
--> statement-breakpoint
CREATE TABLE "routines" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"name" text NOT NULL,
	"notes" text DEFAULT '' NOT NULL,
	"position" integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
CREATE TABLE "saved_meal_items" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"saved_meal_id" uuid NOT NULL,
	"food_item_id" uuid NOT NULL,
	"quantity_g" double precision NOT NULL
);
--> statement-breakpoint
CREATE TABLE "saved_meals" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"name" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "set_entries" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"workout_item_id" uuid NOT NULL,
	"index" integer NOT NULL,
	"weight_kg" double precision NOT NULL,
	"reps" integer NOT NULL,
	"rpe" double precision,
	"is_warmup" boolean DEFAULT false NOT NULL,
	"completed_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "sleep_entries" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"date" timestamp with time zone NOT NULL,
	"minutes" integer NOT NULL,
	"source" text DEFAULT 'manual' NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY NOT NULL,
	"email" text,
	"apple_user_id" text,
	"password_hash" text,
	"display_name" text NOT NULL,
	"unit_preference" text DEFAULT 'imperial' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_email_unique" UNIQUE("email"),
	CONSTRAINT "users_apple_user_id_unique" UNIQUE("apple_user_id")
);
--> statement-breakpoint
CREATE TABLE "water_entries" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"date" timestamp with time zone NOT NULL,
	"amount_ml" integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE "weight_entries" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"date" timestamp with time zone NOT NULL,
	"weight_kg" double precision NOT NULL
);
--> statement-breakpoint
CREATE TABLE "workout_items" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"workout_id" uuid NOT NULL,
	"exercise_id" uuid NOT NULL,
	"position" integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE "workouts" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	"started_at" timestamp with time zone NOT NULL,
	"finished_at" timestamp with time zone,
	"routine_id" uuid,
	"notes" text DEFAULT '' NOT NULL
);
--> statement-breakpoint
ALTER TABLE "auth_sessions" ADD CONSTRAINT "auth_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "change_cursors" ADD CONSTRAINT "change_cursors_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercises" ADD CONSTRAINT "exercises_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_items" ADD CONSTRAINT "food_items_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "food_logs" ADD CONSTRAINT "food_logs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "goals" ADD CONSTRAINT "goals_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "measurement_entries" ADD CONSTRAINT "measurement_entries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "personal_records" ADD CONSTRAINT "personal_records_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "routine_items" ADD CONSTRAINT "routine_items_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "routine_items" ADD CONSTRAINT "routine_items_routine_id_routines_id_fk" FOREIGN KEY ("routine_id") REFERENCES "public"."routines"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "routines" ADD CONSTRAINT "routines_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "saved_meal_items" ADD CONSTRAINT "saved_meal_items_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "saved_meal_items" ADD CONSTRAINT "saved_meal_items_saved_meal_id_saved_meals_id_fk" FOREIGN KEY ("saved_meal_id") REFERENCES "public"."saved_meals"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "saved_meals" ADD CONSTRAINT "saved_meals_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "set_entries" ADD CONSTRAINT "set_entries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "set_entries" ADD CONSTRAINT "set_entries_workout_item_id_workout_items_id_fk" FOREIGN KEY ("workout_item_id") REFERENCES "public"."workout_items"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sleep_entries" ADD CONSTRAINT "sleep_entries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "water_entries" ADD CONSTRAINT "water_entries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "weight_entries" ADD CONSTRAINT "weight_entries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_items" ADD CONSTRAINT "workout_items_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_items" ADD CONSTRAINT "workout_items_workout_id_workouts_id_fk" FOREIGN KEY ("workout_id") REFERENCES "public"."workouts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workouts" ADD CONSTRAINT "workouts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "auth_sessions_user_idx" ON "auth_sessions" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "auth_sessions_family_idx" ON "auth_sessions" USING btree ("family_id");--> statement-breakpoint
CREATE UNIQUE INDEX "auth_sessions_token_hash_idx" ON "auth_sessions" USING btree ("refresh_token_hash");