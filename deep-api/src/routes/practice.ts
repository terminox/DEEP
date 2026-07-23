import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireAuth } from "../auth/middleware.js";

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
  // session is a no-op via skipDuplicates rather than an error.
  app.post("/me/practice/sessions", { preHandler: requireAuth }, async (req) => {
    const body = postSchema.parse(req.body);
    const userId = req.auth!.sub;

    await prisma.practiceSession.createMany({
      data: body.sessions.map((s) => ({
        ...s,
        userId,
        completedAt: new Date(s.completedAt),
      })),
      skipDuplicates: true,
    });

    return { synced: body.sessions.map((s) => s.id) };
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
