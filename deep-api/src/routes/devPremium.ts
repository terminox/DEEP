// Dev-only: flip a user's DEEP Premium entitlement without a purchase, so every
// premium-gated screen can be QA'd on a simulator. Registered only when
// ALLOW_DEV_ENTITLEMENT is on — the route does not exist anywhere real (same
// guard shape as the Global Pause time-travel routes).
//
//   POST /dev/premium { "email": "qa@deep.test", "active": true }
//   POST /dev/premium { "userId": "<uuid>", "active": true, "expiresInSeconds": 120 }
//   POST /dev/premium { "email": "qa@deep.test", "active": false }
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { env } from "../env.js";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { serializeEntitlement } from "../lib/entitlement.js";

const bodySchema = z
  .object({
    userId: z.string().uuid().optional(),
    email: z.string().email().optional(),
    active: z.boolean(),
    productId: z.string().min(1).default("deep.pro.yearly"),
    // Omit for a non-expiring grant; set it to watch an expiry happen.
    expiresInSeconds: z.number().int().positive().optional(),
    periodType: z.enum(["NORMAL", "TRIAL", "INTRO"]).default("NORMAL"),
  })
  .refine((b) => b.userId || b.email, { message: "userId or email required" });

export async function devPremiumRoutes(app: FastifyInstance) {
  if (!env.ALLOW_DEV_ENTITLEMENT) return;

  app.post("/dev/premium", async (req) => {
    const body = bodySchema.parse(req.body);
    const user = await prisma.user.findUnique({
      where: body.userId ? { id: body.userId } : { email: body.email!.toLowerCase() },
    });
    if (!user) throw ApiError.notFound("User not found");

    // Real clock on purpose (see lib/entitlement.ts). lastEventAt = now makes
    // this grant newer than any webhook already applied.
    const now = new Date();
    let row;
    if (body.active) {
      const expiresAt = body.expiresInSeconds
        ? new Date(now.getTime() + body.expiresInSeconds * 1000)
        : null;
      const data = {
        entitlementId: env.REVENUECAT_ENTITLEMENT_ID,
        productId: body.productId,
        store: "PROMOTIONAL",
        environment: "SANDBOX",
        periodType: body.periodType,
        expiresAt,
        gracePeriodExpiresAt: null,
        willRenew: false,
        billingIssueDetectedAt: null,
        unsubscribedAt: null,
        revokedAt: null,
        lastEventAt: now,
      };
      row = await prisma.subscription.upsert({
        where: { userId: user.id },
        create: { userId: user.id, ...data },
        update: data,
      });
    } else {
      await prisma.subscription.updateMany({
        where: { userId: user.id },
        data: { revokedAt: now, willRenew: false, lastEventAt: now },
      });
      row = await prisma.subscription.findUnique({ where: { userId: user.id } });
    }
    return { userId: user.id, entitlement: serializeEntitlement(row) };
  });
}
