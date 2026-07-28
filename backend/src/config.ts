import "dotenv/config";
import { z } from "zod";

const optionalText = z.preprocess(
  (value) => (typeof value === "string" && value.trim() === "" ? undefined : value),
  z.string().trim().min(1).optional()
);

const booleanValue = (defaultValue: "true" | "false") =>
  z
    .enum(["true", "false"])
    .default(defaultValue)
    .transform((value) => value === "true");

const schema = z.object({
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().default("file:./dev.db"),
  JWT_SECRET: z.string().min(16).default("development-secret-change-me"),
  OMDB_API_KEY: optionalText,
  CORS_ORIGIN: z.string().default("*"),
  SMTP_HOST: optionalText,
  SMTP_PORT: z.coerce.number().int().positive().default(587),
  SMTP_SECURE: booleanValue("false"),
  SMTP_REQUIRE_TLS: booleanValue("true"),
  SMTP_USER: optionalText,
  SMTP_PASSWORD: optionalText,
  SMTP_FROM: z.string().default("Movie Tracker <no-reply@example.com>"),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development")
});

export const config = schema
  .superRefine((value, context) => {
    if (value.NODE_ENV !== "production") return;

    const required = [
      ["OMDB_API_KEY", value.OMDB_API_KEY],
      ["SMTP_HOST", value.SMTP_HOST],
      ["SMTP_USER", value.SMTP_USER],
      ["SMTP_PASSWORD", value.SMTP_PASSWORD]
    ] as const;

    for (const [key, field] of required) {
      if (!field) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: [key],
          message: `${key} is required in production`
        });
      }
    }

    if (
      value.JWT_SECRET === "development-secret-change-me" ||
      value.JWT_SECRET.length < 32
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["JWT_SECRET"],
        message: "JWT_SECRET must contain at least 32 characters in production"
      });
    }

    if (value.CORS_ORIGIN === "*") {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["CORS_ORIGIN"],
        message: "CORS_ORIGIN must be restricted in production"
      });
    }
  })
  .parse(process.env);
