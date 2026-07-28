import "dotenv/config";
import { z } from "zod";

const schema = z.object({
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().default("file:./dev.db"),
  JWT_SECRET: z.string().min(16).default("development-secret-change-me"),
  OMDB_API_KEY: z.string().optional(),
  CORS_ORIGIN: z.string().default("*"),
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().int().positive().default(587),
  SMTP_USER: z.string().optional(),
  SMTP_PASSWORD: z.string().optional(),
  SMTP_FROM: z.string().default("Movie Tracker <no-reply@example.com>"),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development")
});

export const config = schema.parse(process.env);

if (
  config.NODE_ENV === "production" &&
  config.JWT_SECRET === "development-secret-change-me"
) {
  throw new Error("JWT_SECRET must be configured in production");
}
