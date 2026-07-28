import nodemailer from "nodemailer";
import { config } from "./config.js";
import { AppError } from "./errors.js";

export function createEmailTransport() {
  if (!config.SMTP_HOST || !config.SMTP_USER || !config.SMTP_PASSWORD) {
    throw new AppError(503, "Email service is not configured");
  }
  return nodemailer.createTransport({
    host: config.SMTP_HOST,
    port: config.SMTP_PORT,
    secure: config.SMTP_SECURE,
    requireTLS: config.SMTP_REQUIRE_TLS,
    auth: { user: config.SMTP_USER, pass: config.SMTP_PASSWORD },
    tls: { minVersion: "TLSv1.2" }
  });
}

export async function sendPasswordReset(email: string, token: string) {
  const transport = createEmailTransport();
  await transport.sendMail({
    from: config.SMTP_FROM,
    to: email,
    subject: "Movie Tracker password reset",
    text: `Your password reset code is: ${token}\nThis code expires in 15 minutes.`
  });
}
