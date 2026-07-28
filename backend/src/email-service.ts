import nodemailer from "nodemailer";
import { config } from "./config.js";
import { AppError } from "./errors.js";

export async function sendPasswordReset(email: string, token: string) {
  if (!config.SMTP_HOST || !config.SMTP_USER || !config.SMTP_PASSWORD) {
    throw new AppError(503, "Email service is not configured");
  }
  const transport = nodemailer.createTransport({
    host: config.SMTP_HOST,
    port: config.SMTP_PORT,
    secure: config.SMTP_PORT === 465,
    auth: { user: config.SMTP_USER, pass: config.SMTP_PASSWORD }
  });
  await transport.sendMail({
    from: config.SMTP_FROM,
    to: email,
    subject: "Movie Tracker password reset",
    text: `Your password reset code is: ${token}\nThis code expires in 15 minutes.`
  });
}
