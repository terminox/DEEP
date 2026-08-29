import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Plant, PlantStage } from "@prisma/client";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireRole } from "../auth/middleware.js";
import { serializePlant, serializePlantStage, serializePlantWithStages } from "../lib/serialize.js";
import { MEDIA_RULES, mediaRefSchema, requireUploadedFile, saveUploadedMedia } from "../lib/upload.js";
import { resolveMany, resolveOne, withPending } from "../lib/drafts/overlay.js";
import { stageCreate, stageDelete, stageReorder, stageUpdate } from "../lib/drafts/stage.js";

// Admin CRUD for the Plant catalog: plants + their ordered growth stages,
// plus the media uploads (picker image, per-stage mascot/mascotBg/heroVideo).
// Mirrors admin.ts's conventions (adminOnly preHandler, zod bodies, {thing}
// envelopes) — and, like admin.ts, every write here is staged rather than
// applied. See lib/drafts.
//
// Two behaviours changed when staging landed, both forced by it:
//
// 1. Nothing unlinks replaced media any more. A staged path swap leaves the
//    live row pointing at the old file, so deleting it on upload would break
//    live content immediately - the exact accident this feature exists to
//    prevent. Orphaned files are now a separate sweep, not this file's job.
// 2. Stage thresholds are validated at publish, not on every keystroke. Staging
//    means you can add a stage and renumber the ladder as two edits without the
//    intermediate state being rejected; the review screen blocks publishing an
//    invalid ladder.

const adminOnly = { preHandler: requireRole("ADMIN") };

function actor(req: FastifyRequest): string {
  return req.auth!.sub;
}

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

const idParam = z.object({ id: z.string() });

async function resolvedStages() {
  return resolveMany<PlantStage>("PLANT_STAGE", await prisma.plantStage.findMany());
}

export async function adminGardenRoutes(app: FastifyInstance) {
  // ---- Plants ----
  app.get("/admin/plants", adminOnly, async () => {
    const plants = await resolveMany<Plant>("PLANT", await prisma.plant.findMany());
    const stages = await resolvedStages();
    return {
      plants: plants.map((p) =>
        withPending(
          {
            ...serializePlant(p.row),
            stageCount: stages.filter((s) => s.row.plantId === p.row.id).length,
          },
          p.pending,
        ),
      ),
    };
  });

  app.get("/admin/plants/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const plant = await resolveOne<Plant>("PLANT", id);
    if (!plant) throw ApiError.notFound("Plant not found");

    const stages = (await resolvedStages()).filter((s) => s.row.plantId === id);
    return {
      plant: withPending(
        {
          ...serializePlantWithStages({ ...plant.row, stages: stages.map((s) => s.row) }),
          stages: stages.map((s) => withPending(serializePlantStage(s.row), s.pending)),
        },
        plant.pending,
      ),
    };
  });

  app.post("/admin/plants", adminOnly, async (req) => {
    const body = plantCreateBody.parse(req.body);
    // stageCreate rejects an id already taken by a live row or another draft.
    const staged = await stageCreate<Plant>("PLANT", body, actor(req));
    return {
      plant: withPending(
        serializePlantWithStages({ ...staged.row, stages: [] }),
        staged.pending,
      ),
    };
  });

  app.patch("/admin/plants/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = plantUpdateBody.parse(req.body);
    const staged = await stageUpdate<Plant>("PLANT", id, body, actor(req));
    const stages = (await resolvedStages()).filter((s) => s.row.plantId === id);
    return {
      plant: withPending(
        serializePlantWithStages({ ...staged.row, stages: stages.map((s) => s.row) }),
        staged.pending,
      ),
    };
  });

  app.delete("/admin/plants/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    // Checked now as well as at publish: staging a deletion that can never be
    // published would just sit in the review screen as an unclearable blocker.
    const inUse = await prisma.userPlantProgress.count({ where: { plantId: id } });
    if (inUse > 0) throw ApiError.conflict("Plant has user progress", "plant_in_use");

    await stageDelete("PLANT", id, actor(req));
    return { ok: true };
  });

  app.post("/admin/plants/reorder", adminOnly, async (req) => {
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);
    await stageReorder("PLANT", ids, actor(req));
    return { ok: true };
  });

  // Plant picker card art. Bytes land now; the row only points at them on publish.
  app.post("/admin/plants/:id/image", adminOnly, async (req: FastifyRequest) => {
    const { id } = idParam.parse(req.params);
    const plant = await resolveOne<Plant>("PLANT", id);
    if (!plant) throw ApiError.notFound("Plant not found");

    const file = await requireUploadedFile(req, MEDIA_RULES.image.maxBytes);
    const relPath = await saveUploadedMedia(file, "image", "garden/images");

    const staged = await stageUpdate<Plant>("PLANT", id, { imageUrl: relPath }, actor(req));
    return { plant: withPending(serializePlant(staged.row), staged.pending) };
  });

  // ---- Stages ----
  app.post("/admin/plants/:id/stages", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = stageCreateBody.parse(req.body);
    const plant = await resolveOne<Plant>("PLANT", id);
    if (!plant) throw ApiError.notFound("Plant not found");

    const staged = await stageCreate<PlantStage>(
      "PLANT_STAGE",
      { plantId: id, ...body },
      actor(req),
    );
    return { stage: withPending(serializePlantStage(staged.row), staged.pending) };
  });

  app.patch("/admin/plant-stages/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = stageUpdateBody.parse(req.body);
    const staged = await stageUpdate<PlantStage>("PLANT_STAGE", id, body, actor(req));
    return { stage: withPending(serializePlantStage(staged.row), staged.pending) };
  });

  app.delete("/admin/plant-stages/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    await stageDelete("PLANT_STAGE", id, actor(req));
    return { ok: true };
  });

  app.post("/admin/plants/:id/stages/reorder", adminOnly, async (req) => {
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);
    await stageReorder("PLANT_STAGE", ids, actor(req));
    return { ok: true };
  });

  // ---- Stage assets: mascot (no bg) / mascotBg / heroVideo ----
  app.post("/admin/plant-stages/:id/assets/:kind", adminOnly, async (req: FastifyRequest) => {
    const { id, kind } = z
      .object({ id: z.string(), kind: stageAssetKind })
      .parse(req.params);
    const stage = await resolveOne<PlantStage>("PLANT_STAGE", id);
    if (!stage) throw ApiError.notFound("Stage not found");

    const isVideo = kind === "heroVideo";
    const file = await requireUploadedFile(
      req,
      isVideo ? MEDIA_RULES.video.maxBytes : MEDIA_RULES.image.maxBytes,
    );
    const relPath = await saveUploadedMedia(
      file,
      isVideo ? "video" : "image",
      isVideo ? "garden/videos" : "garden/images",
    );

    const staged = await stageUpdate<PlantStage>(
      "PLANT_STAGE",
      id,
      { [STAGE_ASSET_COLUMN[kind]]: relPath },
      actor(req),
    );
    return { stage: withPending(serializePlantStage(staged.row), staged.pending) };
  });

  app.delete("/admin/plant-stages/:id/assets/:kind", adminOnly, async (req) => {
    const { id, kind } = z
      .object({ id: z.string(), kind: stageAssetKind })
      .parse(req.params);
    const stage = await resolveOne<PlantStage>("PLANT_STAGE", id);
    if (!stage) throw ApiError.notFound("Stage not found");

    const staged = await stageUpdate<PlantStage>(
      "PLANT_STAGE",
      id,
      { [STAGE_ASSET_COLUMN[kind]]: null },
      actor(req),
    );
    return { stage: withPending(serializePlantStage(staged.row), staged.pending) };
  });
}
