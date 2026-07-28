import { randomBytes } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import process from "node:process";

const envPath = new URL("../.env", import.meta.url);

function parseEnv(content) {
  const values = {};
  for (const line of content.split(/\r?\n/)) {
    const match = line.match(/^([A-Z][A-Z0-9_]*)=(.*)$/);
    if (!match) continue;
    let value = match[2].trim();
    if (value.startsWith('"') && value.endsWith('"')) {
      value = value.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, "\\");
    }
    values[match[1]] = value;
  }
  return values;
}

function quote(value) {
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r?\n/g, "")}"`;
}

function prompt(label, current = "", hidden = false) {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    return Promise.resolve(current);
  }

  const displayed = current ? (hidden ? "configured" : current) : "";
  process.stdout.write(`${label}${displayed ? ` [${displayed}]` : ""}: `);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding("utf8");

  return new Promise((resolve) => {
    let input = "";

    const finish = () => {
      process.stdin.off("data", onData);
      process.stdin.setRawMode(false);
      process.stdin.pause();
      process.stdout.write("\n");
      resolve(input || current);
    };

    const onData = (data) => {
      for (const character of data) {
        if (character === "\u0003") {
          process.stdout.write("\n");
          process.exit(130);
        }
        if (character === "\r" || character === "\n") {
          finish();
          return;
        }
        if (character === "\u007f" || character === "\b") {
          if (input.length > 0) {
            input = input.slice(0, -1);
            process.stdout.write("\b \b");
          }
          continue;
        }
        if (character >= " ") {
          input += character;
          process.stdout.write(hidden ? "*" : character);
        }
      }
    };

    process.stdin.on("data", onData);
  });
}

const existing = existsSync(envPath)
  ? parseEnv(readFileSync(envPath, "utf8"))
  : {};

const values = {
  NODE_ENV: process.env.NODE_ENV ?? existing.NODE_ENV ?? "development",
  PORT: process.env.PORT ?? existing.PORT ?? "3000",
  DATABASE_URL: process.env.DATABASE_URL ?? existing.DATABASE_URL ?? "file:./dev.db",
  JWT_SECRET:
    process.env.JWT_SECRET ??
    (existing.JWT_SECRET && existing.JWT_SECRET !== "replace-with-a-long-random-secret"
      ? existing.JWT_SECRET
      : randomBytes(48).toString("base64url"))
};

values.OMDB_API_KEY = await prompt(
  "OMDb API key",
  process.env.OMDB_API_KEY ?? existing.OMDB_API_KEY,
  true
);
values.CORS_ORIGIN = await prompt(
  "Allowed CORS origin(s)",
  process.env.CORS_ORIGIN ?? existing.CORS_ORIGIN ?? "http://localhost"
);
values.SMTP_HOST = await prompt(
  "SMTP host",
  process.env.SMTP_HOST ?? existing.SMTP_HOST
);
values.SMTP_PORT = await prompt(
  "SMTP port",
  process.env.SMTP_PORT ?? existing.SMTP_PORT ?? "587"
);
values.SMTP_SECURE = await prompt(
  "Use implicit SMTP TLS (true/false)",
  process.env.SMTP_SECURE ?? existing.SMTP_SECURE ?? "false"
);
values.SMTP_REQUIRE_TLS = await prompt(
  "Require SMTP STARTTLS (true/false)",
  process.env.SMTP_REQUIRE_TLS ?? existing.SMTP_REQUIRE_TLS ?? "true"
);
values.SMTP_USER = await prompt(
  "SMTP username",
  process.env.SMTP_USER ?? existing.SMTP_USER
);
values.SMTP_PASSWORD = await prompt(
  "SMTP password",
  process.env.SMTP_PASSWORD ?? existing.SMTP_PASSWORD,
  true
);
values.SMTP_FROM = await prompt(
  "Sender",
  process.env.SMTP_FROM ??
    existing.SMTP_FROM ??
    "Movie Tracker <no-reply@example.com>"
);

const required = ["OMDB_API_KEY", "SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD"];
const missing = required.filter((key) => !values[key]);
if (missing.length > 0) {
  throw new Error(`Missing configuration: ${missing.join(", ")}`);
}

const order = [
  "NODE_ENV",
  "PORT",
  "DATABASE_URL",
  "JWT_SECRET",
  "OMDB_API_KEY",
  "CORS_ORIGIN",
  "SMTP_HOST",
  "SMTP_PORT",
  "SMTP_SECURE",
  "SMTP_REQUIRE_TLS",
  "SMTP_USER",
  "SMTP_PASSWORD",
  "SMTP_FROM"
];

const content = `${order.map((key) => `${key}=${quote(values[key])}`).join("\n")}\n`;
writeFileSync(envPath, content, { mode: 0o600 });
console.log("Created backend/.env with a generated JWT secret.");
