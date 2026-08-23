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
  // "Mind trees" are the plant catalog's published, non-premium defaults —
  // the key and field shape are unchanged, so old clients keep working.
  app.get("/onboarding/config", async () => {
    const [questions, trees] = await Promise.all([
      prisma.quizQuestion.findMany({
        orderBy: { displayOrder: "asc" },
        include: { options: true },
      }),
      prisma.plant.findMany({
        where: { isActive: true, isDefault: true, isPremium: false },
        orderBy: { displayOrder: "asc" },
      }),
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

    // The onboarding pick seeds the Mind Garden selection — but only when the
    // user hasn't chosen a plant yet (the garden's own choice always wins) and
    // the answer names a published, non-premium plant.
    if (body.mindTree) {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { selectedPlantId: true },
      });
      if (user && !user.selectedPlantId) {
        const plant = await prisma.plant.findFirst({
          where: { id: body.mindTree, isActive: true, isPremium: false },
          select: { id: true },
        });
        if (plant) {
          await prisma.$transaction([
            prisma.user.update({
              where: { id: userId },
              data: { selectedPlantId: plant.id },
            }),
            prisma.userPlantProgress.upsert({
              where: { userId_plantId: { userId, plantId: plant.id } },
              create: { userId, plantId: plant.id },
              update: {},
            }),
          ]);
        }
      }
    }

    return serializeProfile(profile);
  });
}
