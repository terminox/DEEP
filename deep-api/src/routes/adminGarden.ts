import type { FastifyInstance, FastifyRequest } from "fastify";
import { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireRole } from "../auth/middleware.js";
import { validateThresholds } from "../lib/awardRules.js";
import { serializePlant, serializePlantStage, serializePlantWithStages } from "../lib/serialize.js";
import {
  MEDIA_RULES,
  mediaRefSchema,
  requireUploadedFile,
  saveUploadedMedia,
  unlinkMedia,
} from "../lib/upload.js";

// Admin CRUD for the Plant catalog: plants + their ordered growth stages,
// plus the media uploads (picker image, per-stage mascot/mascotBg/heroVideo).
// Mirrors admin.ts's conventions (adminOnly preHandler, zod bodies, {thing}
// envelopes, reorder transactions) — kept in its own file per the plan.

const adminOnly = { preHandler: requireRole("ADMIN") };

// Duplicated from admin.ts's paletteEnum on purpose: plants and sound
// collections are unrelated catalogs that happen to share a palette
// vocabulary today; keeping the enum local avoids coupling the two files.
const paletteEnum = z.enum([
  "tide",
  "dusk",
  "bloom",
  "ember",
  "mist",
  "aurora",
  "dawn",
]);

const plantCreateBody = z.object({
  id: z
    .string()
    .regex(/^[a-z0-9-]{2,32}$/, "id must be 2-32 lowercase letters, digits, or hyphens"),
  name: z.string().trim().min(1),
  tagline: z.string().trim().min(1),
  palette: paletteEnum,
  imageUrl: mediaRefSchema.nullable().optional(),
  isPremium: z.boolean().optional(),
  isDefault: z.boolean().optional(),
  isActive: z.boolean().optional(),
  displayOrder: z.number().int().optional(),
});
// id is immutable after creation — PATCH omits it entirely.
const plantUpdateBody = plantCreateBody.omit({ id: true }).partial();

const stageCreateBody = z.object({
  name: z.string().trim().min(1),
  sunlightRequired: z.number().int().min(0),
  displayOrder: z.number().int().optional(),
});
const stageUpdateBody = z.object({
  name: z.string().trim().min(1).optional(),
  sunlightRequired: z.number().int().min(0).optional(),
});

const stageAssetKind = z.enum(["mascot", "mascotBg", "heroVideo"]);
type StageAssetKind = z.infer<typeof stageAssetKind>;

const STAGE_ASSET_COLUMN: Record<StageAssetKind, "mascotPath" | "mascotBgPath" | "heroVideoPath"> = {
  mascot: "mascotPath",
  mascotBg: "mascotBgPath",
  heroVideo: "heroVideoPath",
};

export async function adminGardenRoutes(app: FastifyInstance) {
  // ---- Plants ----
  app.get("/admin/plants", adminOnly, async () => {
    const plants = await prisma.plant.findMany({
      orderBy: { displayOrder: "asc" },
      include: { _count: { select: { stages: true } } },
    });
    return {
      plants: plants.map((p) => ({ ...serializePlant(p), stageCount: p._count.stages })),
    };
  });

  app.get("/admin/plants/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const plant = await prisma.plant.findUnique({
      where: { id },
      include: { stages: { orderBy: { displayOrder: "asc" } } },
    });
    if (!plant) throw ApiError.notFound("Plant not found");
    return { plant: serializePlantWithStages(plant) };
  });

  app.post("/admin/plants", adminOnly, async (req) => {
    const body = plantCreateBody.parse(req.body);
    let created;
    try {
      created = await prisma.plant.create({
        data: {
          id: body.id,
          name: body.name,
          tagline: body.tagline,
          palette: body.palette,
          imageUrl: body.imageUrl ?? null,
          isPremium: body.isPremium ?? false,
          isDefault: body.isDefault ?? false,
          isActive: body.isActive ?? false,
          displayOrder: body.displayOrder ?? 0,
        },
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
        throw ApiError.conflict("A plant with this id already exists", "plant_id_taken");
      }
      throw e;
    }
    return { plant: serializePlantWithStages({ ...created, stages: [] }) };
  });

  app.patch("/admin/plants/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = plantUpdateBody.parse(req.body);
    const existing = await prisma.plant.findUnique({ where: { id } });
    if (!existing) throw ApiError.notFound("Plant not found");

    const updated = await prisma.plant.update({
      where: { id },
      data: {
        ...body,
        imageUrl: body.imageUrl === undefined ? undefined : body.imageUrl,
      },
      include: { stages: { orderBy: { displayOrder: "asc" } } },
    });
    return { plant: serializePlantWithStages(updated) };
  });

  app.delete("/admin/plants/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const existing = await prisma.plant.findUnique({
      where: { id },
      include: { stages: true },
    });
    if (!existing) throw ApiError.notFound("Plant not found");

    try {
      // selectedPlantId is onDelete: SetNull, so users pointed at this plant
      // fall back to the lazy-default-assignment path automatically.
      await prisma.plant.delete({ where: { id } });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2003") {
        throw ApiError.conflict("Plant has user progress", "plant_in_use");
      }
      throw e;
    }

    // Best-effort: the plant's own art plus every stage's assets are now
    // orphaned on disk. Never blocks the response.
    await unlinkMedia(existing.imageUrl);
    for (const stage of existing.stages) {
      await unlinkMedia(stage.mascotPath);
      await unlinkMedia(stage.mascotBgPath);
      await unlinkMedia(stage.heroVideoPath);
    }

    return { ok: true };
  });

  app.post("/admin/plants/reorder", adminOnly, async (req) => {
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);
    await prisma.$transaction(
      ids.map((id, i) => prisma.plant.update({ where: { id }, data: { displayOrder: i } })),
    );
    return { ok: true };
  });

  // Plant picker card art.
  app.post("/admin/plants/:id/image", adminOnly, async (req: FastifyRequest) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const plant = await prisma.plant.findUnique({ where: { id } });
    if (!plant) throw ApiError.notFound("Plant not found");

    const file = await requireUploadedFile(req, MEDIA_RULES.image.maxBytes);
    const relPath = await saveUploadedMedia(file, "image", "garden/images");

    const updated = await prisma.plant.update({ where: { id }, data: { imageUrl: relPath } });
    await unlinkMedia(plant.imageUrl);
    return { plant: serializePlant(updated) };
  });

  // ---- Stages ----
  // Every mutation below re-validates the plant's full ordered threshold
  // ladder inside the same transaction; an invalid result rolls the whole
  // thing back and surfaces as 400 invalid_thresholds.

  app.post("/admin/plants/:id/stages", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = stageCreateBody.parse(req.body);
    const plant = await prisma.plant.findUnique({ where: { id } });
    if (!plant) throw ApiError.notFound("Plant not found");

    const stage = await prisma.$transaction(async (tx) => {
      const created = await tx.plantStage.create({
        data: {
          plantId: id,
          name: body.name,
          sunlightRequired: body.sunlightRequired,
          displayOrder: body.displayOrder ?? 0,
        },
      });
      const ladder = await tx.plantStage.findMany({ where: { plantId: id } });
      if (!validateThresholds(ladder)) {
        throw ApiError.badRequest(
          "Stage thresholds must start at 0 and strictly increase",
          "invalid_thresholds",
        );
      }
      return created;
    });

    return { stage: serializePlantStage(stage) };
  });

  app.patch("/admin/plant-stages/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = stageUpdateBody.parse(req.body);
    const existing = await prisma.plantStage.findUnique({ where: { id } });
    if (!existing) throw ApiError.notFound("Stage not found");

    const stage = await prisma.$transaction(async (tx) => {
      const updated = await tx.plantStage.update({ where: { id }, data: body });
      const ladder = await tx.plantStage.findMany({ where: { plantId: existing.plantId } });
      if (!validateThresholds(ladder)) {
        throw ApiError.badRequest(
          "Stage thresholds must start at 0 and strictly increase",
          "invalid_thresholds",
        );
      }
      return updated;
    });

    return { stage: serializePlantStage(stage) };
  });

  app.delete("/admin/plant-stages/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const existing = await prisma.plantStage.findUnique({ where: { id } });
    if (!existing) throw ApiError.notFound("Stage not found");

    await prisma.$transaction(async (tx) => {
      await tx.plantStage.delete({ where: { id } });
      const ladder = await tx.plantStage.findMany({ where: { plantId: existing.plantId } });
      if (!validateThresholds(ladder)) {
        throw ApiError.badRequest(
          "Stage thresholds must start at 0 and strictly increase",
          "invalid_thresholds",
        );
      }
    });

    await unlinkMedia(existing.mascotPath);
    await unlinkMedia(existing.mascotBgPath);
    await unlinkMedia(existing.heroVideoPath);

    return { ok: true };
  });

  app.post("/admin/plants/:id/stages/reorder", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);

    await prisma.$transaction(async (tx) => {
      await Promise.all(
        ids.map((stageId, i) => tx.plantStage.update({ where: { id: stageId }, data: { displayOrder: i } })),
      );
      const ladder = await tx.plantStage.findMany({ where: { plantId: id } });
      if (!validateThresholds(ladder)) {
        throw ApiError.badRequest(
          "Stage thresholds must start at 0 and strictly increase",
          "invalid_thresholds",
        );
      }
    });

    return { ok: true };
  });

  // ---- Stage assets: mascot (no bg) / mascotBg / heroVideo ----
  app.post("/admin/plant-stages/:id/assets/:kind", adminOnly, async (req: FastifyRequest) => {
    const { id, kind } = z
      .object({ id: z.string(), kind: stageAssetKind })
      .parse(req.params);
    const stage = await prisma.plantStage.findUnique({ where: { id } });
    if (!stage) throw ApiError.notFound("Stage not found");

    const isVideo = kind === "heroVideo";
    const file = await requireUploadedFile(req, isVideo ? MEDIA_RULES.video.maxBytes : MEDIA_RULES.image.maxBytes);
    const relPath = await saveUploadedMedia(
      file,
      isVideo ? "video" : "image",
      isVideo ? "garden/videos" : "garden/images",
    );

    const column = STAGE_ASSET_COLUMN[kind];
    const oldPath = stage[column];
    const updated = await prisma.plantStage.update({
      where: { id },
      data: { [column]: relPath },
    });
    await unlinkMedia(oldPath);

    return { stage: serializePlantStage(updated) };
  });

  app.delete("/admin/plant-stages/:id/assets/:kind", adminOnly, async (req) => {
    const { id, kind } = z
      .object({ id: z.string(), kind: stageAssetKind })
      .parse(req.params);
    const stage = await prisma.plantStage.findUnique({ where: { id } });
    if (!stage) throw ApiError.notFound("Stage not found");

    const column = STAGE_ASSET_COLUMN[kind];
    const oldPath = stage[column];
    const updated = await prisma.plantStage.update({
      where: { id },
      data: { [column]: null },
    });
    await unlinkMedia(oldPath);

    return { stage: serializePlantStage(updated) };
  });
}
