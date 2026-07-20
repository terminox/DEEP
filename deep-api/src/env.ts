import { z } from "zod";

// Load .env (Node 22 built-in) before reading process.env. Prisma loads its
// own copy for CLI commands; this covers the app runtime.
try {
  process.loadEnvFile();
} catch {
  /* no .env file — rely on real environment variables */
}

const schema = z.object({
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(1),
  ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
  HOST: z.string().default("0.0.0.0"),
  PORT: z.coerce.number().int().positive().default(8080),
  PUBLIC_BASE_URL: z.string().url().default("http://localhost:8080"),
  MEDIA_DIR: z.string().default("./media"),
  ADMIN_BOOTSTRAP_EMAIL: z.string().email().optional(),
  ADMIN_BOOTSTRAP_PASSWORD: z.string().min(8).optional(),
});

export const env = schema.parse(process.env);
export type Env = z.infer<typeof schema>;
