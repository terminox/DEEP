import { prisma } from "./prisma.js";
import { env } from "./env.js";
import { hashPassword } from "./auth/password.js";

// Creates the first ADMIN from env if none exists yet — mirrors caregiver-api's
// bootstrap_admin_if_empty so a fresh DB has a usable admin login.
export async function bootstrapAdmin(log: {
  info: (msg: string) => void;
  warn: (msg: string) => void;
}) {
  if (!env.ADMIN_BOOTSTRAP_EMAIL || !env.ADMIN_BOOTSTRAP_PASSWORD) {
    log.warn("No ADMIN_BOOTSTRAP_* set — skipping admin bootstrap.");
    return;
  }
  const existing = await prisma.user.findFirst({ where: { role: "ADMIN" } });
  if (existing) return;

  const email = env.ADMIN_BOOTSTRAP_EMAIL.toLowerCase();
  await prisma.user.upsert({
    where: { email },
    update: { role: "ADMIN" },
    create: {
      email,
      passwordHash: await hashPassword(env.ADMIN_BOOTSTRAP_PASSWORD),
      displayName: "Deep Admin",
      role: "ADMIN",
    },
  });
  log.info(`Bootstrapped admin: ${email}`);
}
