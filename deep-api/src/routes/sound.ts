import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireAuth } from "../auth/middleware.js";
import { grantAward } from "../lib/awards.js";
import { requestTimezone, rememberTimezone, userDayKey } from "../lib/clientDay.js";
import { rewardSnapshot } from "../lib/rewardPayload.js";
import { resolveNow } from "../lib/pauseSchedule.js";
import {
  serializeAwardOutcome,
  serializeCategory,
  serializeCollection,
  serializeLyrics,
} from "../lib/serialize.js";
import { VISIBLE_CATEGORY_TREE, VISIBLE_TRACK, VISIBLE_TRACKS } from "../lib/soundQuery.js";

export async function soundRoutes(app: FastifyInstance) {
  // One call builds the entire Deep Sound home: ordered categories, each with
  // its ordered collections and their ordered tracks (with lyrics availability).
  // The payload is small, so the app needs no per-collection follow-up fetch.
  app.get("/sound/home", async () => {
    const categories = await prisma.soundCategory.findMany(VISIBLE_CATEGORY_TREE);
    return { categories: categories.map(serializeCategory) };
  });

  app.get("/sound/collections/:id", async (req) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    // A hidden collection - or one under a hidden category - is a 404 here, the
    // same as one that does not exist. The app must not be able to reach content
    // that has been pulled from the shelves.
    const collection = await prisma.soundCollection.findFirst({
      where: { id, isActive: true, category: { isActive: true } },
      include: { tracks: VISIBLE_TRACKS },
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
      where: {
        trackId: id,
        ...(lang ? { languageCode: lang } : {}),
        // Lyrics inherit their track's visibility, and the track its collection's.
        track: VISIBLE_TRACK,
      },
    });
    return { lyrics: lyrics.map(serializeLyrics) };
  });

  // A track played to the end. The award ledger is the durable listen record:
  // the unique on (user, kind, dayKey, trackId) means the same track earns
  // once per local day, and TRACK_COMPLETED's perDay rule caps distinct
  // tracks — both come back as a non-granted outcome, never an error.
  app.post("/me/sound/listens", { preHandler: requireAuth }, async (req) => {
    const { trackId } = z.object({ trackId: z.string().min(1) }).parse(req.body);
    const userId = req.auth!.sub;

    // Hidden content earns nothing: same shape as garden.ts rejecting a write
    // that names a plant the user is not allowed to select.
    const track = await prisma.soundTrack.findFirst({
      where: { id: trackId, ...VISIBLE_TRACK },
    });
    if (!track) throw ApiError.notFound("Track not found", "track_not_found");

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { timezone: true },
    });
    const tz = requestTimezone(req, user?.timezone);
    rememberTimezone(userId, tz, user?.timezone);
    const dayKey = userDayKey(resolveNow(), tz);

    const outcome = await grantAward({
      userId,
      kind: "TRACK_COMPLETED",
      dayKey,
      sourceId: track.id,
      timezone: tz,
    });
    const snapshot = await rewardSnapshot(userId, dayKey);
    return { award: serializeAwardOutcome(outcome), ...snapshot };
  });
}
