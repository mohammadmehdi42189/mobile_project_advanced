import bcrypt from "bcryptjs";
import { PrismaClient, Role } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash("Admin123!", 12);
  await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: { username: "admin" },
    create: {
      email: "admin@example.com",
      username: "admin",
      name: "Administrator",
      passwordHash,
      role: Role.ADMIN
    }
  });
}

main().finally(() => prisma.$disconnect());
