import { beforeAll, describe, expect, it } from "vitest";
import request from "supertest";
import { Role } from "@prisma/client";
import { app } from "../src/app.js";
import { createToken } from "../src/auth.js";
import { prisma } from "../src/db.js";

beforeAll(async () => {
  await prisma.report.deleteMany();
  await prisma.listItem.deleteMany();
  await prisma.personalList.deleteMany();
  await prisma.episodeProgress.deleteMany();
  await prisma.comment.deleteMany();
  await prisma.rating.deleteMany();
  await prisma.watchItem.deleteMany();
  await prisma.passwordReset.deleteMany();
  await prisma.user.deleteMany();
  await prisma.media.deleteMany();
});

async function registerUser(suffix: string) {
  const response = await request(app).post("/api/v1/auth/register").send({
    name: `Test User ${suffix}`,
    username: `test_${suffix}`,
    email: `test_${suffix}@example.com`,
    password: "Password123!",
    sessionDays: 30
  });
  expect(response.status).toBe(201);
  return response.body as {
    token: string;
    user: { id: string; email: string; username: string; role: Role };
  };
}

async function cacheMedia(id: string, type: "movie" | "series", totalSeasons?: number) {
  return prisma.media.create({
    data: {
      id,
      type,
      title: `Cached ${id}`,
      totalSeasons: totalSeasons ?? null
    }
  });
}

describe("API", () => {
  it("reports health", async () => {
    const response = await request(app).get("/health");
    expect(response.status).toBe(200);
    expect(response.body.status).toBe("ok");
  });

  it("registers, logs in and protects profile", async () => {
    const registration = await registerUser("profile");
    expect(registration.user.username).toBe("test_profile");

    const profile = await request(app)
      .get("/api/v1/profile")
      .set("Authorization", `Bearer ${registration.token}`);
    expect(profile.status).toBe(200);
    expect(profile.body.email).toBe("test_profile@example.com");
    expect(profile.body.username).toBe("test_profile");

    const login = await request(app).post("/api/v1/auth/login").send({
      email: "test_profile@example.com",
      password: "Password123!",
      sessionDays: 7
    });
    expect(login.status).toBe(200);

    const denied = await request(app).get("/api/v1/profile");
    expect(denied.status).toBe(401);
  });

  it("rejects duplicate usernames", async () => {
    await registerUser("duplicate");
    const response = await request(app).post("/api/v1/auth/register").send({
      name: "Another User",
      username: "test_duplicate",
      email: "another@example.com",
      password: "Password123!"
    });
    expect(response.status).toBe(409);
  });

  it("rejects ratings outside the 1..5 range and accepts five stars", async () => {
    const registration = await registerUser("rating");
    await cacheMedia("tt0133093", "movie");

    for (const value of [0, 6]) {
      const invalid = await request(app)
        .put("/api/v1/ratings/tt0133093")
        .set("Authorization", `Bearer ${registration.token}`)
        .send({ value });
      expect(invalid.status).toBe(400);
    }

    const valid = await request(app)
      .put("/api/v1/ratings/tt0133093")
      .set("Authorization", `Bearer ${registration.token}`)
      .send({ value: 5 });
    expect(valid.status).toBe(200);
    expect(valid.body.value).toBe(5);
  });

  it("derives watched episode count on the server instead of trusting the client", async () => {
    const registration = await registerUser("watchcount");
    await cacheMedia("tt1000001", "series", 1);
    await prisma.episodeProgress.create({
      data: {
        userId: registration.user.id,
        mediaId: "tt1000001",
        season: 1,
        episode: 1
      }
    });

    const response = await request(app)
      .put("/api/v1/watchlist/tt1000001")
      .set("Authorization", `Bearer ${registration.token}`)
      .send({ status: "WATCHING", watchedEpisodes: 999 });

    expect(response.status).toBe(200);
    expect(response.body.watchedEpisodes).toBe(1);
  });

  it("rejects episode progress for a season outside the cached series range", async () => {
    const registration = await registerUser("episode");
    await cacheMedia("tt1000002", "series", 1);

    const response = await request(app)
      .put("/api/v1/episodes/tt1000002/999/999")
      .set("Authorization", `Bearer ${registration.token}`)
      .send({});

    expect(response.status).toBe(400);
    expect(await prisma.episodeProgress.count({
      where: { userId: registration.user.id, mediaId: "tt1000002" }
    })).toBe(0);
  });

  it("invalidates an existing token as soon as the account is deactivated", async () => {
    const registration = await registerUser("inactive");
    await prisma.user.update({
      where: { id: registration.user.id },
      data: { active: false }
    });

    const response = await request(app)
      .get("/api/v1/profile")
      .set("Authorization", `Bearer ${registration.token}`);
    expect(response.status).toBe(401);
  });

  it("uses the current database role instead of a stale role embedded in JWT", async () => {
    const registration = await registerUser("role");
    await prisma.user.update({
      where: { id: registration.user.id },
      data: { role: Role.ADMIN }
    });
    const adminToken = createToken({ id: registration.user.id, role: Role.ADMIN });

    const allowed = await request(app)
      .get("/api/v1/admin/stats")
      .set("Authorization", `Bearer ${adminToken}`);
    expect(allowed.status).toBe(200);

    await prisma.user.update({
      where: { id: registration.user.id },
      data: { role: Role.USER }
    });
    const denied = await request(app)
      .get("/api/v1/admin/stats")
      .set("Authorization", `Bearer ${adminToken}`);
    expect(denied.status).toBe(403);
  });
});
