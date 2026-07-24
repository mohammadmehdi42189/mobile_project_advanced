import { Router } from "express";
import bcrypt from "bcryptjs";
import { Role, WatchStatus } from "@prisma/client";
import { z } from "zod";
import { prisma } from "./db.js";
import { createToken, requireAdmin, requireAuth } from "./auth.js";
import { AppError } from "./errors.js";
import { findMedia, searchMedia } from "./media-service.js";

export const routes = Router();

const credentials = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(72)
});

routes.post("/auth/register", async (req, res) => {
  const body = credentials.extend({ name: z.string().trim().min(2).max(60) }).parse(req.body);
  if (await prisma.user.findUnique({ where: { email: body.email.toLowerCase() } })) {
    throw new AppError(409, "Email is already registered");
  }
  const user = await prisma.user.create({
    data: {
      email: body.email.toLowerCase(),
      name: body.name,
      passwordHash: await bcrypt.hash(body.password, 12)
    },
    select: { id: true, email: true, name: true, role: true }
  });
  res.status(201).json({ user, token: createToken({ id: user.id, role: user.role }) });
});

routes.post("/auth/login", async (req, res) => {
  const body = credentials.parse(req.body);
  const user = await prisma.user.findUnique({ where: { email: body.email.toLowerCase() } });
  if (!user || !user.active || !(await bcrypt.compare(body.password, user.passwordHash))) {
    throw new AppError(401, "Invalid email or password");
  }
  res.json({
    user: { id: user.id, email: user.email, name: user.name, role: user.role },
    token: createToken({ id: user.id, role: user.role })
  });
});

routes.get("/profile", requireAuth, async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.user!.id },
    select: { id: true, email: true, name: true, role: true, createdAt: true }
  });
  res.json(user);
});

routes.get("/media/search", async (req, res) => {
  const query = z.object({
    q: z.string().trim().min(2),
    page: z.coerce.number().int().min(1).default(1),
    type: z.enum(["movie", "series"]).optional()
  }).parse(req.query);
  res.json(await searchMedia(query.q, query.page, query.type));
});

routes.get("/media/:id", async (req, res) => {
  res.json(await findMedia(z.string().regex(/^tt\d+$/).parse(req.params.id)));
});

routes.put("/watchlist/:mediaId", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const body = z.object({
    status: z.nativeEnum(WatchStatus),
    watchedEpisodes: z.number().int().min(0).default(0)
  }).parse(req.body);
  await findMedia(mediaId);
  const item = await prisma.watchItem.upsert({
    where: { userId_mediaId: { userId: req.user!.id, mediaId } },
    update: body,
    create: { userId: req.user!.id, mediaId, ...body },
    include: { media: true }
  });
  res.json(item);
});

routes.delete("/watchlist/:mediaId", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  await prisma.watchItem.deleteMany({ where: { userId: req.user!.id, mediaId } });
  res.status(204).end();
});

routes.get("/watchlist", requireAuth, async (req, res) => {
  res.json(await prisma.watchItem.findMany({
    where: { userId: req.user!.id },
    include: { media: true },
    orderBy: { updatedAt: "desc" }
  }));
});

routes.put("/ratings/:mediaId", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const { value } = z.object({ value: z.number().int().min(1).max(10) }).parse(req.body);
  await findMedia(mediaId);
  res.json(await prisma.rating.upsert({
    where: { userId_mediaId: { userId: req.user!.id, mediaId } },
    update: { value },
    create: { userId: req.user!.id, mediaId, value }
  }));
});

routes.post("/comments/:mediaId", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const { text } = z.object({ text: z.string().trim().min(1).max(1000) }).parse(req.body);
  await findMedia(mediaId);
  res.status(201).json(await prisma.comment.create({
    data: { userId: req.user!.id, mediaId, text }
  }));
});

routes.get("/media/:mediaId/comments", async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  res.json(await prisma.comment.findMany({
    where: { mediaId },
    include: { user: { select: { id: true, name: true } } },
    orderBy: { createdAt: "desc" }
  }));
});

routes.get("/activities", requireAuth, async (req, res) => {
  const [movies, series, ratings] = await Promise.all([
    prisma.watchItem.count({ where: { userId: req.user!.id, status: WatchStatus.COMPLETED, media: { type: "movie" } } }),
    prisma.watchItem.count({ where: { userId: req.user!.id, status: WatchStatus.COMPLETED, media: { type: "series" } } }),
    prisma.rating.aggregate({ where: { userId: req.user!.id }, _avg: { value: true } })
  ]);
  res.json({ watchedMovies: movies, watchedSeries: series, averageRating: ratings._avg.value ?? 0 });
});

routes.post("/lists", requireAuth, async (req, res) => {
  const { name } = z.object({ name: z.string().trim().min(1).max(80) }).parse(req.body);
  res.status(201).json(await prisma.personalList.create({
    data: { userId: req.user!.id, name }
  }));
});

routes.get("/lists", requireAuth, async (req, res) => {
  res.json(await prisma.personalList.findMany({
    where: { userId: req.user!.id },
    include: { items: { include: { media: true } } },
    orderBy: { createdAt: "desc" }
  }));
});

routes.put("/lists/:listId/items/:mediaId", requireAuth, async (req, res) => {
  const listId = z.string().min(1).parse(req.params.listId);
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const list = await prisma.personalList.findFirst({ where: { id: listId, userId: req.user!.id } });
  if (!list) throw new AppError(404, "List not found");
  await findMedia(mediaId);
  res.json(await prisma.listItem.upsert({
    where: { listId_mediaId: { listId, mediaId } },
    update: {},
    create: { listId, mediaId }
  }));
});

routes.delete("/lists/:listId", requireAuth, async (req, res) => {
  const listId = z.string().min(1).parse(req.params.listId);
  const result = await prisma.personalList.deleteMany({ where: { id: listId, userId: req.user!.id } });
  if (!result.count) throw new AppError(404, "List not found");
  res.status(204).end();
});

routes.post("/reports/comments/:commentId", requireAuth, async (req, res) => {
  const commentId = z.string().min(1).parse(req.params.commentId);
  const { reason } = z.object({ reason: z.string().trim().min(3).max(500) }).parse(req.body);
  res.status(201).json(await prisma.report.upsert({
    where: { userId_commentId: { userId: req.user!.id, commentId } },
    update: { reason, resolved: false },
    create: { userId: req.user!.id, commentId, reason }
  }));
});

routes.get("/admin/users", requireAuth, requireAdmin, async (_req, res) => {
  res.json(await prisma.user.findMany({
    select: { id: true, email: true, name: true, role: true, active: true, createdAt: true }
  }));
});

routes.patch("/admin/users/:id", requireAuth, requireAdmin, async (req, res) => {
  const id = z.string().min(1).parse(req.params.id);
  const body = z.object({ role: z.nativeEnum(Role).optional(), active: z.boolean().optional() }).parse(req.body);
  res.json(await prisma.user.update({
    where: { id },
    data: body,
    select: { id: true, email: true, name: true, role: true, active: true }
  }));
});

routes.delete("/admin/comments/:id", requireAuth, requireAdmin, async (req, res) => {
  const id = z.string().min(1).parse(req.params.id);
  await prisma.comment.delete({ where: { id } });
  res.status(204).end();
});

routes.get("/admin/stats", requireAuth, requireAdmin, async (_req, res) => {
  const [users, media, comments, ratings] = await Promise.all([
    prisma.user.count(),
    prisma.media.count(),
    prisma.comment.count(),
    prisma.rating.count()
  ]);
  res.json({ users, media, comments, ratings });
});

routes.get("/admin/reports", requireAuth, requireAdmin, async (_req, res) => {
  res.json(await prisma.report.findMany({
    include: {
      user: { select: { id: true, name: true, email: true } },
      comment: true
    },
    orderBy: { createdAt: "desc" }
  }));
});

routes.patch("/admin/reports/:id", requireAuth, requireAdmin, async (req, res) => {
  const id = z.string().min(1).parse(req.params.id);
  const { resolved } = z.object({ resolved: z.boolean() }).parse(req.body);
  res.json(await prisma.report.update({ where: { id }, data: { resolved } }));
});
