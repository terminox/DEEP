import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { requireAuth } from "../auth/middleware.js";
import { serializeOnboardingConfig } from "../lib/serialize.js";

const putSchema = z.object({
  quizAnswers: z.record(z.string(), z.string()).default({}),
  mindTree: z.string().nullable().optional(),
  completed: z.boolean().default(false),
});

function serializeProfile(p: {
  quizAnswers: unknown;
  mindTree: string | null;
  completedAt: Date | null;
}) {
  return {
    quizAnswers: (p.quizAnswers ?? {}) as Record<string, string>,
    mindTree: p.mindTree,
    completed: p.completedAt != null,
    completedAt: p.completedAt ? p.completedAt.toISOString() : null,
  };
}

export async function onboardingRoutes(app: FastifyInstance) {
  // Public: the quiz questions + mind trees that drive the onboarding UI.
  app.get("/onboarding/config", async () => {
    const [questions, trees] = await Promise.all([
      prisma.quizQuestion.findMany({
        orderBy: { displayOrder: "asc" },
        include: { options: true },
      }),
      prisma.mindTree.findMany({ orderBy: { displayOrder: "asc" } }),
    ]);
    return serializeOnboardingConfig(questions, trees);
  });

  app.get("/me/onboarding", { preHandler: requireAuth }, async (req) => {
    const profile = await prisma.onboardingProfile.findUnique({
      where: { userId: req.auth!.sub },
    });
    if (!profile) {
      return { quizAnswers: {}, mindTree: null, completed: false, completedAt: null };
    }
    return serializeProfile(profile);
  });

  app.put("/me/onboarding", { preHandler: requireAuth }, async (req) => {
    const body = putSchema.parse(req.body);
    const userId = req.auth!.sub;
    const completedAt = body.completed ? new Date() : null;

    const profile = await prisma.onboardingProfile.upsert({
      where: { userId },
      create: {
        userId,
        quizAnswers: body.quizAnswers,
        mindTree: body.mindTree ?? null,
        completedAt,
      },
      update: {
        quizAnswers: body.quizAnswers,
        mindTree: body.mindTree ?? null,
        // Never un-complete an already-finished onboarding.
        ...(body.completed ? { completedAt: new Date() } : {}),
      },
    });
    return serializeProfile(profile);
  });
}
