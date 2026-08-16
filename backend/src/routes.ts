import { Router } from "express";
import bcrypt from "bcryptjs";
import { createHash, randomBytes } from "node:crypto";
import { Role, WatchStatus } from "@prisma/client";
import { z } from "zod";
import { prisma } from "./db.js";
import { createToken, requireAdmin, requireAuth } from "./auth.js";
import { AppError } from "./errors.js";
import { sendPasswordReset } from "./email-service.js";
import { findMedia, findSeason, searchMedia } from "./media-service.js";

export const routes = Router();

const credentials = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(72),
  sessionDays: z.number().int().min(1).max(30).default(30)
});

const usernameSchema = z.string()
  .trim()
  .min(3)
  .max(30)
  .regex(/^[a-zA-Z0-9_.]+$/, "Username may only contain letters, numbers, dots and underscores");

routes.post("/auth/register", async (req, res) => {
  const body = credentials.extend({
    name: z.string().trim().min(2).max(60),
    username: usernameSchema,
    bio: z.string().trim().max(300).default(""),
    avatarUrl: z.string().url().nullable().optional()
  }).parse(req.body);
  if (await prisma.user.findUnique({ where: { email: body.email.toLowerCase() } })) {
    throw new AppError(409, "Email is already registered");
  }
  const username = body.username.toLowerCase();
  if (await prisma.user.findUnique({ where: { username } })) {
    throw new AppError(409, "Username is already registered");
  }
  const user = await prisma.user.create({
    data: {
      email: body.email.toLowerCase(),
      username,
      name: body.name,
      bio: body.bio,
      avatarUrl: body.avatarUrl,
      passwordHash: await bcrypt.hash(body.password, 12)
    },
    select: {
      id: true,
      email: true,
      username: true,
      name: true,
      bio: true,
      avatarUrl: true,
      role: true
    }
  });
  res.status(201).json({
    user,
    token: createToken({ id: user.id, role: user.role }, body.sessionDays)
  });
});

routes.post("/auth/login", async (req, res) => {
  const body = credentials.parse(req.body);
  const user = await prisma.user.findUnique({ where: { email: body.email.toLowerCase() } });
  if (!user || !user.active || !(await bcrypt.compare(body.password, user.passwordHash))) {
    throw new AppError(401, "Invalid email or password");
  }
  res.json({
    user: {
      id: user.id,
      email: user.email,
      username: user.username,
      name: user.name,
      bio: user.bio,
      avatarUrl: user.avatarUrl,
      role: user.role
    },
    token: createToken({ id: user.id, role: user.role }, body.sessionDays)
  });
});

routes.post("/auth/password-reset/request", async (req, res) => {
  const email = z.string().email().parse(req.body.email).toLowerCase();
  const user = await prisma.user.findUnique({ where: { email } });
  if (user) {
    const token = randomBytes(4).toString("hex").toUpperCase();
    await prisma.passwordReset.create({
      data: {
        email,
        tokenHash: createHash("sha256").update(token).digest("hex"),
        expiresAt: new Date(Date.now() + 15 * 60 * 1000)
      }
    });
    await sendPasswordReset(email, token);
  }
  res.status(204).end();
});

routes.post("/auth/password-reset/confirm", async (req, res) => {
  const body = z.object({
    email: z.string().email(),
    token: z.string().length(8),
    password: z.string().min(8).max(72)
  }).parse(req.body);
  const tokenHash = createHash("sha256").update(body.token.toUpperCase()).digest("hex");
  const reset = await prisma.passwordReset.findFirst({
    where: {
      email: body.email.toLowerCase(),
      tokenHash,
      usedAt: null,
      expiresAt: { gt: new Date() }
    }
  });
  if (!reset) throw new AppError(400, "Invalid or expired reset code");
  await prisma.$transaction([
    prisma.user.update({
      where: { email: body.email.toLowerCase() },
      data: { passwordHash: await bcrypt.hash(body.password, 12) }
    }),
    prisma.passwordReset.update({ where: { id: reset.id }, data: { usedAt: new Date() } })
  ]);
  res.status(204).end();
});

routes.get("/profile", requireAuth, async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.user!.id },
    select: {
      id: true,
      email: true,
      username: true,
      name: true,
      bio: true,
      avatarUrl: true,
      role: true,
      createdAt: true
    }
  });
  res.json(user);
});

routes.patch("/profile", requireAuth, async (req, res) => {
  const body = z.object({
    name: z.string().trim().min(2).max(60).optional(),
    bio: z.string().trim().max(300).optional(),
    avatarUrl: z.string().url().nullable().optional()
  }).parse(req.body);
  res.json(await prisma.user.update({
    where: { id: req.user!.id },
    data: body,
    select: {
      id: true,
      email: true,
      username: true,
      name: true,
      bio: true,
      avatarUrl: true,
      role: true,
      createdAt: true
    }
  }));
});

routes.get("/media/search", async (req, res) => {
  const query = z.object({
    q: z.string().trim().min(2),
    page: z.coerce.number().int().min(1).default(1),
    type: z.enum(["movie", "series"]).optional(),
    year: z.coerce.number().int().min(1888).max(2100).optional()
  }).parse(req.query);
  res.json(await searchMedia(query.q, query.page, query.type, query.year));
});

routes.get("/media/:id", async (req, res) => {
  res.json(await findMedia(z.string().regex(/^tt\d+$/).parse(req.params.id)));
});

routes.get("/media/:id/seasons/:season", async (req, res) => {
  const id = z.string().regex(/^tt\d+$/).parse(req.params.id);
  const season = z.coerce.number().int().min(1).parse(req.params.season);
  res.json(await findSeason(id, season));
});

routes.put("/watchlist/:mediaId", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const body = z.object({
    status: z.nativeEnum(WatchStatus)
  }).parse(req.body);
  await findMedia(mediaId);
  const watchedEpisodes = await prisma.episodeProgress.count({
    where: { userId: req.user!.id, mediaId }
  });
  const item = await prisma.watchItem.upsert({
    where: { userId_mediaId: { userId: req.user!.id, mediaId } },
    update: { ...body, watchedEpisodes },
    create: { userId: req.user!.id, mediaId, ...body, watchedEpisodes },
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

routes.get("/episodes/progress", requireAuth, async (req, res) => {
  res.json(await prisma.episodeProgress.findMany({
    where: { userId: req.user!.id },
    orderBy: [{ mediaId: "asc" }, { season: "asc" }, { episode: "asc" }]
  }));
});

routes.put("/episodes/:mediaId/:season/:episode", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const season = z.coerce.number().int().min(1).parse(req.params.season);
  const episode = z.coerce.number().int().min(1).parse(req.params.episode);
  await validateEpisode(mediaId, season, episode);
  const result = await prisma.$transaction(async transaction => {
    const progress = await transaction.episodeProgress.upsert({
      where: {
        userId_mediaId_season_episode: {
          userId: req.user!.id,
          mediaId,
          season,
          episode
        }
      },
      update: { watchedAt: new Date() },
      create: { userId: req.user!.id, mediaId, season, episode }
    });
    const watchedEpisodes = await transaction.episodeProgress.count({
      where: { userId: req.user!.id, mediaId }
    });
    await transaction.watchItem.upsert({
      where: { userId_mediaId: { userId: req.user!.id, mediaId } },
      update: { status: WatchStatus.WATCHING, watchedEpisodes },
      create: {
        userId: req.user!.id,
        mediaId,
        status: WatchStatus.WATCHING,
        watchedEpisodes
      }
    });
    return progress;
  });
  res.json(result);
});

routes.delete("/episodes/:mediaId/:season/:episode", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const season = z.coerce.number().int().min(1).parse(req.params.season);
  const episode = z.coerce.number().int().min(1).parse(req.params.episode);
  await prisma.$transaction(async transaction => {
    await transaction.episodeProgress.deleteMany({
      where: { userId: req.user!.id, mediaId, season, episode }
    });
    const watchedEpisodes = await transaction.episodeProgress.count({
      where: { userId: req.user!.id, mediaId }
    });
    await transaction.watchItem.updateMany({
      where: { userId: req.user!.id, mediaId },
      data: { watchedEpisodes }
    });
  });
  res.status(204).end();
});

async function validateEpisode(mediaId: string, season: number, episode: number) {
  const media = await findMedia(mediaId);
  if (media.type !== "series") {
    throw new AppError(400, "Episode progress is only available for series");
  }
  if (media.totalSeasons && season > media.totalSeasons) {
    throw new AppError(400, "Season does not exist for this series");
  }
  const seasonData = await findSeason(mediaId, season);
  if (!seasonData.episodes.some(item => item.episode === episode)) {
    throw new AppError(400, "Episode does not exist in this season");
  }
}

routes.put("/ratings/:mediaId", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const { value } = z.object({ value: z.number().int().min(1).max(5) }).parse(req.body);
  await findMedia(mediaId);
  const rating = await prisma.rating.upsert({
    where: { userId_mediaId: { userId: req.user!.id, mediaId } },
    update: { value: value * 2 },
    create: { userId: req.user!.id, mediaId, value: value * 2 }
  });
  res.json({ ...rating, value });
});

routes.get("/ratings", requireAuth, async (req, res) => {
  const ratings = await prisma.rating.findMany({
    where: { userId: req.user!.id },
    include: { media: true },
    orderBy: { updatedAt: "desc" }
  });
  res.json(ratings.map(item => ({
    ...item,
    value: Math.round(item.value / 2)
  })));
});

routes.get("/media/:mediaId/ratings", async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const ratings = await prisma.rating.groupBy({
    by: ["value"],
    where: { mediaId },
    _count: { value: true }
  });
  const normalizedCounts = new Map<number, number>();
  for (const item of ratings) {
    const normalizedValue = Math.round(item.value / 2);
    if (normalizedValue < 1 || normalizedValue > 5) continue;
    normalizedCounts.set(
      normalizedValue,
      (normalizedCounts.get(normalizedValue) ?? 0) + item._count.value
    );
  }
  const total = [...normalizedCounts.values()].reduce((sum, count) => sum + count, 0);
  res.json({
    total,
    distribution: Object.fromEntries(
      Array.from({ length: 5 }, (_, index) => {
        const value = index + 1;
        const count = normalizedCounts.get(value) ?? 0;
        return [value, total ? Math.round(count * 10000 / total) / 100 : 0];
      })
    )
  });
});

routes.post("/comments/:mediaId", requireAuth, async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const body = z.object({
    text: z.string().trim().min(1).max(1000),
    spoiler: z.boolean().default(false)
  }).parse(req.body);
  await findMedia(mediaId);
  res.status(201).json(await prisma.comment.create({
    data: { userId: req.user!.id, mediaId, ...body }
  }));
});

routes.get("/comments", requireAuth, async (req, res) => {
  res.json(await prisma.comment.findMany({
    where: { userId: req.user!.id },
    include: { media: true },
    orderBy: { createdAt: "desc" }
  }));
});

routes.patch("/comments/:id", requireAuth, async (req, res) => {
  const id = z.string().min(1).parse(req.params.id);
  const body = z.object({
    text: z.string().trim().min(1).max(1000).optional(),
    spoiler: z.boolean().optional()
  }).refine(value => value.text !== undefined || value.spoiler !== undefined).parse(req.body);
  const result = await prisma.comment.updateMany({
    where: { id, userId: req.user!.id },
    data: body
  });
  if (!result.count) throw new AppError(404, "Comment not found");
  res.json(await prisma.comment.findUnique({ where: { id } }));
});

routes.delete("/comments/:id", requireAuth, async (req, res) => {
  const id = z.string().min(1).parse(req.params.id);
  const result = await prisma.comment.deleteMany({ where: { id, userId: req.user!.id } });
  if (!result.count) throw new AppError(404, "Comment not found");
  res.status(204).end();
});

routes.get("/media/:mediaId/comments", async (req, res) => {
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  res.json(await prisma.comment.findMany({
    where: { mediaId },
    include: {
      user: { select: { id: true, name: true, avatarUrl: true } }
    },
    orderBy: { createdAt: "desc" }
  }));
});

routes.get("/activities", requireAuth, async (req, res) => {
  const [movies, series, ratings, completed, watchedEpisodes] = await Promise.all([
    prisma.watchItem.count({ where: { userId: req.user!.id, status: WatchStatus.COMPLETED, media: { type: "movie" } } }),
    prisma.watchItem.count({ where: { userId: req.user!.id, status: WatchStatus.COMPLETED, media: { type: "series" } } }),
    prisma.rating.aggregate({ where: { userId: req.user!.id }, _avg: { value: true } }),
    prisma.watchItem.findMany({
      where: { userId: req.user!.id, status: WatchStatus.COMPLETED },
      include: { media: true }
    }),
    prisma.episodeProgress.count({ where: { userId: req.user!.id } })
  ]);
  const genres = completed
    .flatMap(item => item.media.genres?.split(",").map(genre => genre.trim()) ?? []);
  const genreCounts = genres.reduce<Record<string, number>>((counts, genre) => {
    counts[genre] = (counts[genre] ?? 0) + 1;
    return counts;
  }, {});
  const favoriteGenre = Object.entries(genreCounts)
    .sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;
  const totalWatchMinutes = completed.reduce(
    (total, item) => total + (item.media.runtimeMinutes ?? 0),
    0
  ) + watchedEpisodes * 45;
  res.json({
    watchedMovies: movies,
    watchedSeries: series,
    watchedEpisodes,
    totalWatchMinutes,
    favoriteGenre,
    averageRating: (ratings._avg.value ?? 0) / 2
  });
});

routes.post("/lists", requireAuth, async (req, res) => {
  const { name } = z.object({ name: z.string().trim().min(1).max(80) }).parse(req.body);
  res.status(201).json(await prisma.personalList.upsert({
    where: { userId_name: { userId: req.user!.id, name } },
    update: {},
    create: { userId: req.user!.id, name }
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

routes.delete("/lists/:listId/items/:mediaId", requireAuth, async (req, res) => {
  const listId = z.string().min(1).parse(req.params.listId);
  const mediaId = z.string().regex(/^tt\d+$/).parse(req.params.mediaId);
  const list = await prisma.personalList.findFirst({ where: { id: listId, userId: req.user!.id } });
  if (!list) throw new AppError(404, "List not found");
  await prisma.listItem.deleteMany({ where: { listId, mediaId } });
  res.status(204).end();
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
