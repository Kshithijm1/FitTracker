import { config as loadDotenv } from "dotenv";
import { z } from "zod";

// `NODE_ENV=test` loads `.env.test` (a separate local Postgres database)
// instead of the dev `.env`, so running tests never touches dev data.
loadDotenv({ path: process.env.NODE_ENV === "test" ? ".env.test" : ".env" });

/// An unset `.env` var and one explicitly set to "" both arrive as "" —
/// treat empty string as absent so `.optional()` fields don't reject a
/// blank-but-present line in `.env.example`-derived files.
const optionalString = () =>
  z.preprocess((value) => (value === "" ? undefined : value), z.string().optional());

/// Fails fast at boot if any required secret/config is missing or malformed
/// — never trust partially-configured env in an auth/health-data service.
const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().url(),

  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().positive().default(15 * 60),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),

  APPLE_BUNDLE_ID: z.string().min(1),
  APPLE_TEAM_ID: optionalString(),

  GEMINI_API_KEY: optionalString(),
});

export type Env = z.infer<typeof envSchema>;

function loadEnv(): Env {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("\n");
    throw new Error(`Invalid environment configuration:\n${issues}`);
  }
  return parsed.data;
}

export const env = loadEnv();
