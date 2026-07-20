import type { FastifyInstance, FastifyRequest } from "fastify";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { env } from "../env.js";
import { ApiError } from "../lib/errors.js";
import { verifyPassword } from "../auth/password.js";
import { createSession } from "../auth/sessions.js";
import { requireRole } from "../auth/middleware.js";
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
    imageUrl: z.string().url().nullable().optional(),
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

    const file = await req.file();
    if (!file) throw ApiError.badRequest("No file uploaded");

    const ext = path.extname(file.filename) || ".mp3";
    const name = `${crypto.randomUUID()}${ext}`;
    const audioDir = path.join(env.MEDIA_DIR, "audio");
    await fs.mkdir(audioDir, { recursive: true });
    await fs.writeFile(path.join(audioDir, name), await file.toBuffer());

    const updated = await prisma.soundTrack.update({
      where: { id },
      data: { audioPath: `/media/audio/${name}` },
    });
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
}
