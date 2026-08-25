import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { verifyPassword } from "../auth/password.js";
import { createSession } from "../auth/sessions.js";
import { requireRole } from "../auth/middleware.js";
import { MEDIA_RULES, mediaRefSchema, requireUploadedFile, saveUploadedMedia } from "../lib/upload.js";
import {
  serializeUser,
  serializeCategory,
  serializeCollection,
  serializeTrack,
  serializeLyrics,
} from "../lib/serialize.js";

const adminOnly = { preHandler: requireRole("ADMIN") };

const paletteEnum = z.enum([
  "tide",
  "dusk",
  "bloom",
  "ember",
  "mist",
  "aurora",
  "dawn",
]);

export async function adminRoutes(app: FastifyInstance) {
  // ---- Admin auth ----
  app.post("/admin/auth/login", async (req) => {
    const body = z
      .object({ email: z.string().email(), password: z.string().min(1) })
      .parse(req.body);
    const user = await prisma.user.findUnique({
      where: { email: body.email.toLowerCase() },
    });
    if (
      !user ||
      user.role !== "ADMIN" ||
      !(await verifyPassword(user.passwordHash, body.password))
    ) {
      throw ApiError.unauthorized("Invalid admin credentials", "invalid_credentials");
    }
    const tokens = await createSession(user.id, user.role, {
      userAgent: req.headers["user-agent"],
      ip: req.ip,
    });
    return { user: serializeUser(user), ...tokens };
  });

  // ---- Users (read-only oversight) ----
  app.get("/admin/users", adminOnly, async () => {
    const users = await prisma.user.findMany({ orderBy: { createdAt: "desc" } });
    return { users: users.map(serializeUser) };
  });

  // ---- Categories ----
  app.get("/admin/categories", adminOnly, async () => {
    const categories = await prisma.soundCategory.findMany({
      orderBy: { displayOrder: "asc" },
      include: { _count: { select: { collections: true } } },
    });
    return { categories: categories.map(serializeCategory) };
  });

  app.post("/admin/categories", adminOnly, async (req) => {
    const body = z
      .object({
        slug: z.string().trim().min(1),
        title: z.string().trim().min(1),
        displayOrder: z.number().int().optional(),
      })
      .parse(req.body);
    const created = await prisma.soundCategory.create({
      data: {
        slug: body.slug,
        title: body.title,
        displayOrder: body.displayOrder ?? 0,
      },
    });
    return { category: serializeCategory(created) };
  });

  app.patch("/admin/categories/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = z
      .object({
        slug: z.string().trim().min(1).optional(),
        title: z.string().trim().min(1).optional(),
        displayOrder: z.number().int().optional(),
      })
      .parse(req.body);
    const updated = await prisma.soundCategory.update({ where: { id }, data: body });
    return { category: serializeCategory(updated) };
  });

  app.delete("/admin/categories/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    await prisma.soundCategory.delete({ where: { id } });
    return { ok: true };
  });

  app.post("/admin/categories/reorder", adminOnly, async (req) => {
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);
    await prisma.$transaction(
      ids.map((id, i) =>
        prisma.soundCategory.update({ where: { id }, data: { displayOrder: i } }),
      ),
    );
    return { ok: true };
  });

  // ---- Collections ----
  app.get("/admin/collections", adminOnly, async (req) => {
    const { categoryId } = z
      .object({ categoryId: z.string().optional() })
      .parse(req.query);
    const collections = await prisma.soundCollection.findMany({
      where: categoryId ? { categoryId } : {},
      orderBy: [{ categoryId: "asc" }, { displayOrder: "asc" }],
      include: { _count: { select: { tracks: true } } },
    });
    return { collections: collections.map(serializeCollection) };
  });

  app.get("/admin/collections/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const collection = await prisma.soundCollection.findUnique({
      where: { id },
      include: {
        tracks: {
          orderBy: { displayOrder: "asc" },
          include: { lyrics: { select: { languageCode: true } } },
        },
      },
    });
    if (!collection) throw ApiError.notFound("Collection not found");
    return { collection: serializeCollection(collection) };
  });

  const collectionBody = z.object({
    categoryId: z.string(),
    title: z.string().trim().min(1),
    subtitle: z.string().trim().min(1),
    palette: paletteEnum,
    imageUrl: mediaRefSchema.nullable().optional(),
    isPremium: z.boolean().optional(),
    displayOrder: z.number().int().optional(),
  });

  app.post("/admin/collections", adminOnly, async (req) => {
    const body = collectionBody.parse(req.body);
    const created = await prisma.soundCollection.create({
      data: {
        categoryId: body.categoryId,
        title: body.title,
        subtitle: body.subtitle,
        palette: body.palette,
        imageUrl: body.imageUrl ?? null,
        isPremium: body.isPremium ?? false,
        displayOrder: body.displayOrder ?? 0,
      },
    });
    return { collection: serializeCollection(created) };
  });

  app.patch("/admin/collections/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = collectionBody.partial().parse(req.body);
    const updated = await prisma.soundCollection.update({
      where: { id },
      data: {
        ...body,
        imageUrl: body.imageUrl === undefined ? undefined : body.imageUrl,
      },
    });
    return { collection: serializeCollection(updated) };
  });

  app.delete("/admin/collections/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    await prisma.soundCollection.delete({ where: { id } });
    return { ok: true };
  });

  app.post("/admin/collections/reorder", adminOnly, async (req) => {
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);
    await prisma.$transaction(
      ids.map((id, i) =>
        prisma.soundCollection.update({ where: { id }, data: { displayOrder: i } }),
      ),
    );
    return { ok: true };
  });

  // ---- Tracks ----
  const trackBody = z.object({
    collectionId: z.string(),
    title: z.string().trim().min(1),
    durationSeconds: z.number().int().positive(),
    kind: z.enum(["INSTRUMENTAL", "GUIDED"]).optional(),
    isPremium: z.boolean().optional(),
    displayOrder: z.number().int().optional(),
  });

  app.post("/admin/tracks", adminOnly, async (req) => {
    const body = trackBody.parse(req.body);
    const created = await prisma.soundTrack.create({
      data: {
        collectionId: body.collectionId,
        title: body.title,
        durationSeconds: body.durationSeconds,
        kind: body.kind ?? "INSTRUMENTAL",
        isPremium: body.isPremium ?? false,
        displayOrder: body.displayOrder ?? 0,
      },
    });
    return { track: serializeTrack(created) };
  });

  app.patch("/admin/tracks/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = trackBody.partial().parse(req.body);
    const updated = await prisma.soundTrack.update({ where: { id }, data: body });
    return { track: serializeTrack(updated) };
  });

  app.delete("/admin/tracks/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    await prisma.soundTrack.delete({ where: { id } });
    return { ok: true };
  });

  app.post("/admin/tracks/reorder", adminOnly, async (req) => {
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);
    await prisma.$transaction(
      ids.map((id, i) =>
        prisma.soundTrack.update({ where: { id }, data: { displayOrder: i } }),
      ),
    );
    return { ok: true };
  });

  // Audio upload (multipart). Saves under MEDIA_DIR/audio and sets audioPath.
  app.post("/admin/tracks/:id/audio", adminOnly, async (req: FastifyRequest) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const track = await prisma.soundTrack.findUnique({ where: { id } });
    if (!track) throw ApiError.notFound("Track not found");

    const file = await requireUploadedFile(req, MEDIA_RULES.audio.maxBytes);
    const relPath = await saveUploadedMedia(file, "audio", "audio");
    // No unlink of the replaced file, deliberately: prisma/seed.ts assigns audio
    // round-robin from three shared files, so many tracks point at the same path -
    // and /media/audio/global-pause.mp3 is also PauseConfig's default. Deleting on
    // replace would silence other tracks and the nightly Global Pause. The garden
    // routes can unlink safely because their old paths are per-row uuid files.
    const updated = await prisma.soundTrack.update({ where: { id }, data: { audioPath: relPath } });
    return { track: serializeTrack(updated) };
  });

  // ---- Lyrics ----
  app.get("/admin/tracks/:id/lyrics", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const lyrics = await prisma.trackLyrics.findMany({ where: { trackId: id } });
    return { lyrics: lyrics.map(serializeLyrics) };
  });

  app.put("/admin/tracks/:id/lyrics", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = z
      .object({
        languageCode: z.string().trim().min(2),
        content: z.string(),
      })
      .parse(req.body);
    const track = await prisma.soundTrack.findUnique({ where: { id } });
    if (!track) throw ApiError.notFound("Track not found");

    const lyrics = await prisma.trackLyrics.upsert({
      where: { trackId_languageCode: { trackId: id, languageCode: body.languageCode } },
      create: { trackId: id, languageCode: body.languageCode, content: body.content },
      update: { content: body.content },
    });
    return { lyrics: serializeLyrics(lyrics) };
  });

  app.delete("/admin/tracks/:id/lyrics/:lang", adminOnly, async (req) => {
    const { id, lang } = z
      .object({ id: z.string(), lang: z.string() })
      .parse(req.params);
    await prisma.trackLyrics
      .delete({
        where: { trackId_languageCode: { trackId: id, languageCode: lang } },
      })
      .catch(() => {
        /* idempotent */
      });
    return { ok: true };
  });

  // ---- Global Pause ----

  const hms = z.string().regex(/^\d{2}:\d{2}:\d{2}$/, "expected HH:mm:ss");

  const pauseConfigBody = z
    .object({
      timezone: z.string().trim().min(1),
      lobbyStart: hms,
      welcomeStart: hms,
      meditationStart: hms,
      feedbackStart: hms,
      windowEnd: hms,
      lobbyAudioPath: mediaRefSchema,
      meditationAudioPath: mediaRefSchema,
      meditationDurationSeconds: z.number().int().positive(),
    })
    .refine(
      (b) => {
        const order = [b.lobbyStart, b.welcomeStart, b.meditationStart, b.feedbackStart, b.windowEnd];
        return order.every((t, i) => i === 0 || order[i - 1]! < t);
      },
      { message: "phase times must be strictly increasing" },
    );

  app.get("/admin/pause/config", adminOnly, async () => {
    const config = await prisma.pauseConfig.upsert({
      where: { id: 1 },
      update: {},
      create: { id: 1 },
    });
    return { config };
  });

  app.put("/admin/pause/config", adminOnly, async (req) => {
    const body = pauseConfigBody.parse(req.body);
    const config = await prisma.pauseConfig.upsert({
      where: { id: 1 },
      update: body,
      create: { id: 1, ...body },
    });
    return { config };
  });

  // Welcome messages
  app.get("/admin/pause/welcome-messages", adminOnly, async () => {
    const messages = await prisma.pauseWelcomeMessage.findMany({
      orderBy: { displayOrder: "asc" },
    });
    return { messages };
  });

  app.post("/admin/pause/welcome-messages", adminOnly, async (req) => {
    const body = z
      .object({
        text: z.string().trim().min(1),
        displayOrder: z.number().int().optional(),
        isActive: z.boolean().optional(),
      })
      .parse(req.body);
    const message = await prisma.pauseWelcomeMessage.create({
      data: {
        text: body.text,
        displayOrder: body.displayOrder ?? 0,
        isActive: body.isActive ?? true,
      },
    });
    return { message };
  });

  app.patch("/admin/pause/welcome-messages/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = z
      .object({
        text: z.string().trim().min(1).optional(),
        displayOrder: z.number().int().optional(),
        isActive: z.boolean().optional(),
      })
      .parse(req.body);
    const message = await prisma.pauseWelcomeMessage.update({ where: { id }, data: body });
    return { message };
  });

  app.delete("/admin/pause/welcome-messages/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    await prisma.pauseWelcomeMessage.delete({ where: { id } });
    return { ok: true };
  });

  app.post("/admin/pause/welcome-messages/reorder", adminOnly, async (req) => {
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);
    await prisma.$transaction(
      ids.map((id, i) =>
        prisma.pauseWelcomeMessage.update({ where: { id }, data: { displayOrder: i } }),
      ),
    );
    return { ok: true };
  });

  // Intentions
  app.get("/admin/pause/intentions", adminOnly, async () => {
    const intentions = await prisma.pauseIntentionOption.findMany({
      orderBy: { displayOrder: "asc" },
    });
    return { intentions };
  });

  app.post("/admin/pause/intentions", adminOnly, async (req) => {
    const body = z
      .object({
        key: z.string().trim().min(1),
        label: z.string().trim().min(1),
        displayOrder: z.number().int().optional(),
        isActive: z.boolean().optional(),
      })
      .parse(req.body);
    const intention = await prisma.pauseIntentionOption.create({
      data: {
        key: body.key,
        label: body.label,
        displayOrder: body.displayOrder ?? 0,
        isActive: body.isActive ?? true,
      },
    });
    return { intention };
  });

  app.patch("/admin/pause/intentions/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = z
      .object({
        key: z.string().trim().min(1).optional(),
        label: z.string().trim().min(1).optional(),
        displayOrder: z.number().int().optional(),
        isActive: z.boolean().optional(),
      })
      .parse(req.body);
    const intention = await prisma.pauseIntentionOption.update({ where: { id }, data: body });
    return { intention };
  });

  app.delete("/admin/pause/intentions/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    await prisma.pauseIntentionOption.delete({ where: { id } });
    return { ok: true };
  });

  app.post("/admin/pause/intentions/reorder", adminOnly, async (req) => {
    const { ids } = z.object({ ids: z.array(z.string()) }).parse(req.body);
    await prisma.$transaction(
      ids.map((id, i) =>
        prisma.pauseIntentionOption.update({ where: { id }, data: { displayOrder: i } }),
      ),
    );
    return { ok: true };
  });

  // Peace message moderation (publish-first; moderation hides after the fact)
  app.get("/admin/pause/messages", adminOnly, async (req) => {
    const query = z
      .object({
        status: z.enum(["PUBLISHED", "HIDDEN"]).optional(),
        pauseDate: z.string().optional(),
      })
      .parse(req.query);
    const messages = await prisma.peaceMessage.findMany({
      where: {
        ...(query.status ? { status: query.status } : {}),
        ...(query.pauseDate ? { pauseDate: query.pauseDate } : {}),
      },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return { messages };
  });

  app.patch("/admin/pause/messages/:id", adminOnly, async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const body = z
      .object({ status: z.enum(["PUBLISHED", "HIDDEN"]) })
      .parse(req.body);
    const message = await prisma.peaceMessage.update({
      where: { id },
      data: { status: body.status },
    });
    return { message };
  });

  // Reflection stats: intention + mood counts per pause night.
  app.get("/admin/pause/stats", adminOnly, async (req) => {
    const { days } = z
      .object({ days: z.coerce.number().int().positive().max(90).default(7) })
      .parse(req.query);
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const reflections = await prisma.pauseReflection.findMany({
      where: { createdAt: { gte: since } },
      select: { pauseDate: true, intention: true, mood: true },
    });

    const byDate: Record<
      string,
      { intentions: Record<string, number>; moods: Record<string, number>; total: number }
    > = {};
    for (const r of reflections) {
      const bucket = (byDate[r.pauseDate] ??= { intentions: {}, moods: {}, total: 0 });
      bucket.total += 1;
      if (r.intention) bucket.intentions[r.intention] = (bucket.intentions[r.intention] ?? 0) + 1;
      if (r.mood) bucket.moods[r.mood] = (bucket.moods[r.mood] ?? 0) + 1;
    }
    return { days, byDate };
  });
}
