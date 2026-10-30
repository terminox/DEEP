import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { optionalAuth, requireAuth } from "../auth/middleware.js";
import {
  isPlantLocked,
  markVariesByCaller,
  requestContentAccess,
} from "../lib/premiumContent.js";
import { requestTimezone, rememberTimezone, userDayKey } from "../lib/clientDay.js";
import { walletSummary } from "../lib/awards.js";
import { resolveNow } from "../lib/pauseSchedule.js";
import {
  serializeGarden,
  serializePlantWithStages,
  serializeWallet,
} from "../lib/serialize.js";

// The Mind Garden: the user's selected plant with its growth stages and
// per-plant sunlight, plus the plant catalog the picker browses.

/**
 * The `{ garden, wallet }` body GET and PUT both return. `selectedPlantId` is
 * the caller's already-loaded selection; when null the first active,
 * non-premium default plant is assigned (and persisted, matching the award
 * engine's resolveCreditPlant) so a fresh account sees a plant immediately.
 * A selected plant that later went premium or inactive keeps serving — the
 * user's progress is never yanked out from under them. This is deliberate,
 * and it is DEEP Premium's grandfathering: the selected plant is loaded with
 * no premium filter, serializes as never locked, and (via its progress row)
 * stays selectable after a lapse. `garden` is null only when the catalog has
 * no eligible plant at all.
 */
async function gardenPayload(
  userId: string,
  selectedPlantId: string | null,
  dayKey: string,
) {
  let plantId = selectedPlantId;
  if (!plantId) {
    // The auto-assigned starter is free-only, member or not, deliberately: a
    // premium starter would strand the person on a plant they cannot reselect
    // the moment their membership lapsed. Premium plants are chosen, never
    // assigned.
    const fallback = await prisma.plant.findFirst({
      where: { isActive: true, isDefault: true, isPremium: false },
      orderBy: { displayOrder: "asc" },
      select: { id: true },
    });
    if (fallback) {
      plantId = fallback.id;
      await prisma.$transaction([
        prisma.user.update({ where: { id: userId }, data: { selectedPlantId: plantId } }),
        prisma.userPlantProgress.upsert({
          where: { userId_plantId: { userId, plantId } },
          create: { userId, plantId },
          update: {},
        }),
      ]);
    }
  }

  const [plant, progress, wallet] = await Promise.all([
    plantId
      ? prisma.plant.findUnique({ where: { id: plantId }, include: { stages: true } })
      : Promise.resolve(null),
    prisma.userPlantProgress.findMany({ where: { userId } }),
    walletSummary(userId, dayKey),
  ]);

  const sunlightByPlant = Object.fromEntries(progress.map((p) => [p.plantId, p.sunlight]));
  return {
    garden: plant
      ? serializeGarden(plant, plant.stages, sunlightByPlant[plant.id] ?? 0, sunlightByPlant)
      : null,
    wallet: serializeWallet(wallet),
  };
}

export async function gardenRoutes(app: FastifyInstance) {
  app.get("/me/garden", { preHandler: requireAuth }, async (req) => {
    const userId = req.auth!.sub;
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { timezone: true, selectedPlantId: true },
    });
    if (!user) throw ApiError.unauthorized();

    const tz = requestTimezone(req, user.timezone);
    rememberTimezone(userId, tz, user.timezone);
    return gardenPayload(userId, user.selectedPlantId, userDayKey(resolveNow(), tz));
  });

  // Public catalog for the plant picker: every published plant, premium ones
  // included and marked `isLocked` for a caller who may not select them. The
  // picker is where DEEP Premium plants are discovered and sold, so they are
  // visible to everyone (see lib/premiumContent: isPlantLocked).
  app.get("/garden/plants", { preHandler: optionalAuth }, async (req, reply) => {
    const userId = req.auth?.sub;
    const [plants, access, grown] = await Promise.all([
      prisma.plant.findMany({
        where: { isActive: true },
        orderBy: { displayOrder: "asc" },
        include: { stages: true },
      }),
      requestContentAccess(req),
      userId
        ? prisma.userPlantProgress.findMany({ where: { userId }, select: { plantId: true } })
        : Promise.resolve([]),
    ]);
    const grownIds = new Set(grown.map((g) => g.plantId));
    markVariesByCaller(reply);
    return {
      plants: plants.map((p) =>
        serializePlantWithStages(p, isPlantLocked(p, access, grownIds.has(p.id))),
      ),
    };
  });

  app.put("/me/garden/plant", { preHandler: requireAuth }, async (req) => {
    const { plantId } = z
      .object({ plantId: z.string().min(1).max(64) })
      .parse(req.body);
    const userId = req.auth!.sub;
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { timezone: true },
    });
    if (!user) throw ApiError.unauthorized();

    const tz = requestTimezone(req, user.timezone);
    rememberTimezone(userId, tz, user.timezone);

    const plant = await prisma.plant.findUnique({ where: { id: plantId } });
    if (!plant || !plant.isActive) {
      throw ApiError.notFound("Plant not found", "plant_not_found");
    }
    // Same code as before premium plants were selectable, so no client error
    // handling changes. Let through a member, or anyone already holding
    // progress on this plant (grandfathered: switching away and back after a
    // lapse must keep working).
    if (plant.isPremium) {
      const [access, progress] = await Promise.all([
        requestContentAccess(req),
        prisma.userPlantProgress.findUnique({
          where: { userId_plantId: { userId, plantId: plant.id } },
          select: { plantId: true },
        }),
      ]);
      if (isPlantLocked(plant, access, progress !== null)) {
        throw ApiError.forbidden("This plant is premium", "premium_locked");
      }
    }

    // Selection + progress land together; sunlight already earned on this
    // plant is preserved (upsert never resets an existing row).
    await prisma.$transaction([
      prisma.user.update({ where: { id: userId }, data: { selectedPlantId: plant.id } }),
      prisma.userPlantProgress.upsert({
        where: { userId_plantId: { userId, plantId: plant.id } },
        create: { userId, plantId: plant.id },
        update: {},
      }),
    ]);

    return gardenPayload(userId, plant.id, userDayKey(resolveNow(), tz));
  });
}
