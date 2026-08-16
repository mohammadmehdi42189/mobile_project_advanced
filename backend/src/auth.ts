import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { Role } from "@prisma/client";
import { config } from "./config.js";
import { prisma } from "./db.js";
import { AppError } from "./errors.js";

export type AuthUser = { id: string; role: Role };

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export function createToken(user: AuthUser, sessionDays = 30) {
  return jwt.sign(user, config.JWT_SECRET, { expiresIn: sessionDays * 24 * 60 * 60 });
}

export async function requireAuth(req: Request, _res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, "");
  if (!token) return next(new AppError(401, "Authentication required"));

  let payload: AuthUser;
  try {
    payload = jwt.verify(token, config.JWT_SECRET) as AuthUser;
  } catch {
    return next(new AppError(401, "Invalid or expired token"));
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: payload.id },
      select: { id: true, role: true, active: true }
    });
    if (!user?.active) {
      return next(new AppError(401, "Account is inactive or no longer exists"));
    }
    req.user = { id: user.id, role: user.role };
    next();
  } catch (error) {
    next(error);
  }
}

export function requireAdmin(req: Request, _res: Response, next: NextFunction) {
  if (req.user?.role !== Role.ADMIN) return next(new AppError(403, "Admin access required"));
  next();
}
