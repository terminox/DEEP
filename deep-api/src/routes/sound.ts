import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import {
  serializeCategory,
  serializeCollection,
  serializeLyrics,
} from "../lib/serialize.js";

export async function soundRoutes(app: FastifyInstance) {
  // One call builds the entire Deep Sound home: ordered categories, each with
  // its ordered collections and their ordered tracks (with lyrics availability).
  // The payload is small, so the app needs no per-collection follow-up fetch.
  app.get("/sound/home", async () => {
    const categories = await prisma.soundCategory.findMany({
      orderBy: { displayOrder: "asc" },
      include: {
        collections: {
          orderBy: { displayOrder: "asc" },
          include: {
            tracks: {
              orderBy: { displayOrder: "asc" },
              include: { lyrics: { select: { languageCode: true } } },
            },
          },
        },
      },
    });
    return { categories: categories.map(serializeCategory) };
  });

  app.get("/sound/collections/:id", async (req) => {
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

  app.get("/sound/tracks/:id/lyrics", async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    const { lang } = z
      .object({ lang: z.string().optional() })
      .parse(req.query);

    const lyrics = await prisma.trackLyrics.findMany({
      where: { trackId: id, ...(lang ? { languageCode: lang } : {}) },
    });
    return { lyrics: lyrics.map(serializeLyrics) };
  });
}
