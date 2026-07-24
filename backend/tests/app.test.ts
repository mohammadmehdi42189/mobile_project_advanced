import { beforeAll, describe, expect, it } from "vitest";
import request from "supertest";
import { app } from "../src/app.js";
import { prisma } from "../src/db.js";

beforeAll(async () => {
  await prisma.comment.deleteMany();
  await prisma.rating.deleteMany();
  await prisma.watchItem.deleteMany();
  await prisma.user.deleteMany();
});

describe("API", () => {
  it("reports health", async () => {
    const response = await request(app).get("/health");
    expect(response.status).toBe(200);
    expect(response.body.status).toBe("ok");
  });

  it("registers, logs in and protects profile", async () => {
    const registration = await request(app).post("/api/v1/auth/register").send({
      name: "Test User",
      email: "test@example.com",
      password: "Password123!"
    });
    expect(registration.status).toBe(201);

    const profile = await request(app)
      .get("/api/v1/profile")
      .set("Authorization", `Bearer ${registration.body.token}`);
    expect(profile.status).toBe(200);
    expect(profile.body.email).toBe("test@example.com");

    const denied = await request(app).get("/api/v1/profile");
    expect(denied.status).toBe(401);
  });

  it("rejects invalid ratings before contacting the movie service", async () => {
    const login = await request(app).post("/api/v1/auth/login").send({
      email: "test@example.com",
      password: "Password123!"
    });
    const response = await request(app)
      .put("/api/v1/ratings/tt0133093")
      .set("Authorization", `Bearer ${login.body.token}`)
      .send({ value: 11 });
    expect(response.status).toBe(400);
  });
});
