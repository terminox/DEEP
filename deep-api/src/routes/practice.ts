import type { FastifyInstance } from "fastify";
import { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireAuth } from "../auth/middleware.js";
import { sessionAwardDayKey } from "../lib/awardRules.js";
import { grantAward } from "../lib/awards.js";
import { requestTimezone, rememberTimezone, userDayKey } from "../lib/clientDay.js";
import { rewardSnapshot } from "../lib/rewardPayload.js";
import { resolveNow } from "../lib/pauseSchedule.js";
import { serializeAwardOutcome } from "../lib/serialize.js";

const sessionSchema = z.object({
  id: z.string().uuid(),
  title: z.string().min(1),
  durationSeconds: z.number().int().positive(),
  completedAt: z.string().datetime(),
});

const postSchema = z.object({
  sessions: z.array(sessionSchema).max(200),
});

function serializeSession(s: {
  id: string;
  title: string;
  durationSeconds: number;
  completedAt: Date;
}) {
  return {
    id: s.id,
    title: s.title,
    durationSeconds: s.durationSeconds,
    completedAt: s.completedAt.toISOString(),
  };
}

export async function practiceRoutes(app: FastifyInstance) {
  // Client-generated ids make this idempotent: resubmitting an already-synced
  // session lands on the primary key and is skipped. The award is attempted
  // for every awardable session regardless of whether the row was newly
  // created — a process can die between the session insert committing and
  // the award granting, and a retry that only awarded on genuinely-new rows
  // would silently lose that award forever. Attempting unconditionally is
  // safe and self-healing: the Award ledger's unique constraint turns a
  // repeat attempt into `granted: false, cappedBy: "duplicate"` rather than
  // a double-grant.
  app.post("/me/practice/sessions", { preHandler: requireAuth }, async (req) => {
    const body = postSchema.parse(req.body);
    const userId = req.auth!.sub;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { timezone: true },
    });
    const tz = requestTimezone(req, user?.timezone);
    rememberTimezone(userId, tz, user?.timezone);

    // Deterministic order (completedAt, then id) so a batch replays awards
    // identically no matter how the client happened to order the array.
    const ordered = body.sessions
      .map((s) => ({ ...s, completedAt: new Date(s.completedAt) }))
      .sort(
        (a, b) =>
          a.completedAt.getTime() - b.completedAt.getTime() || a.id.localeCompare(b.id),
      );

    const awards = [];
    for (const session of ordered) {
      try {
        await prisma.practiceSession.create({
          data: {
            id: session.id,
            userId,
            title: session.title,
            durationSeconds: session.durationSeconds,
            completedAt: session.completedAt,
          },
        });
      } catch (e) {
        if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
          // already synced — store nothing, but still attempt the grant
          // below: a prior attempt may have inserted the row and then died
          // before granting.
        } else {
          throw e;
        }
      }

      // Sessions older than 48h (or stamped in the future) store but earn
      // nothing: sessionAwardDayKey returns null for those.
      const dayKey = sessionAwardDayKey(session.completedAt, tz, resolveNow());
      if (!dayKey) continue;

      const outcome = await grantAward({
        userId,
        kind: "SESSION_COMPLETED",
        dayKey,
        sourceId: session.id,
        timezone: tz,
      });
      awards.push(serializeAwardOutcome(outcome));
    }

    // Wallet + plant fetched fresh AFTER the grants so they include them.
    const snapshot = await rewardSnapshot(userId, userDayKey(resolveNow(), tz));
    return {
      synced: body.sessions.map((s) => s.id),
      awards,
      ...snapshot,
    };
  });

  app.get("/me/practice/sessions", { preHandler: requireAuth }, async (req) => {
    const sessions = await prisma.practiceSession.findMany({
      where: { userId: req.auth!.sub },
      orderBy: { completedAt: "desc" },
      take: 1000,
    });
    return { sessions: sessions.map(serializeSession) };
  });
}
