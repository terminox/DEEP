import type { FastifyInstance } from "fastify";
import { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireAuth } from "../auth/middleware.js";
import { requestTimezone, rememberTimezone, userDayKey } from "../lib/clientDay.js";
import { walletSummary } from "../lib/awards.js";
import { resolveNow } from "../lib/pauseSchedule.js";
import { serializeSpend, serializeWallet } from "../lib/serialize.js";

// The hearts wallet: balance reads and spends (Compassion send/donate).
// Earning happens in the award-bearing routes; this file only reads and spends.

const spendSchema = z.object({
  // Client-generated so a retried request lands on the same row (idempotent).
  id: z.string().uuid(),
  amount: z.number().int().min(1).max(10000),
  // Opaque client catalog strings — the compassion category/project catalog
  // stays a client fixture; the server just records them.
  category: z.string().min(1).max(64),
  projectId: z.string().min(1).max(64).optional(),
});

// A P2002 aborts the surrounding Postgres transaction, so these outcomes have
// to travel out through a rollback rather than a return (same pattern as the
// award engine's DuplicateAwardSignal).
class DuplicateSpendSignal extends Error {
  constructor() {
    super("spend already processed");
    this.name = "DuplicateSpendSignal";
  }
}
class InsufficientHeartsSignal extends Error {
  constructor() {
    super("insufficient hearts");
    this.name = "InsufficientHeartsSignal";
  }
}

function storedTimezone(userId: string) {
  return prisma.user.findUnique({ where: { id: userId }, select: { timezone: true } });
}

export async function heartsRoutes(app: FastifyInstance) {
  app.get("/me/wallet", { preHandler: requireAuth }, async (req) => {
    const userId = req.auth!.sub;
    const user = await storedTimezone(userId);
    const tz = requestTimezone(req, user?.timezone);
    rememberTimezone(userId, tz, user?.timezone);

    const wallet = await walletSummary(userId, userDayKey(resolveNow(), tz));
    return { wallet: serializeWallet(wallet) };
  });

  app.post("/me/hearts/spend", { preHandler: requireAuth }, async (req) => {
    const body = spendSchema.parse(req.body);
    const userId = req.auth!.sub;
    const user = await storedTimezone(userId);
    const tz = requestTimezone(req, user?.timezone);
    rememberTimezone(userId, tz, user?.timezone);
    const dayKey = userDayKey(resolveNow(), tz);

    let spend;
    try {
      spend = await prisma.$transaction(async (tx) => {
        let created;
        try {
          created = await tx.heartSpend.create({
            data: {
              id: body.id,
              userId,
              amount: body.amount,
              category: body.category,
              projectId: body.projectId ?? null,
              createdAt: resolveNow(),
            },
          });
        } catch (e) {
          if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
            throw new DuplicateSpendSignal();
          }
          throw e;
        }

        // Conditional decrement: only a wallet that can afford it matches, so
        // the balance check and the debit are one atomic statement. Zero rows
        // (no wallet yet, or balance short) rolls the spend row back too.
        const debited = await tx.userWallet.updateMany({
          where: { userId, heartsBalance: { gte: body.amount } },
          data: {
            heartsBalance: { decrement: body.amount },
            heartsGiven: { increment: body.amount },
          },
        });
        if (debited.count === 0) throw new InsufficientHeartsSignal();

        return created;
      });
    } catch (e) {
      if (e instanceof DuplicateSpendSignal) {
        // Already processed — return the recorded spend and the current
        // wallet. A foreign id (another user's spend) is a real conflict.
        const existing = await prisma.heartSpend.findUnique({ where: { id: body.id } });
        if (!existing || existing.userId !== userId) {
          throw ApiError.conflict("Spend id already used", "spend_id_taken");
        }
        const wallet = await walletSummary(userId, dayKey);
        return { spend: serializeSpend(existing), wallet: serializeWallet(wallet) };
      }
      if (e instanceof InsufficientHeartsSignal) {
        throw ApiError.conflict("Not enough hearts", "insufficient_hearts");
      }
      throw e;
    }

    const wallet = await walletSummary(userId, dayKey);
    return { spend: serializeSpend(spend), wallet: serializeWallet(wallet) };
  });
}
