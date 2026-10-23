import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { optionalAuth, requireAuth } from "../auth/middleware.js";
import {
  isTrackLocked,
  markVariesByCaller,
  requestContentAccess,
} from "../lib/premiumContent.js";
import { AWARD_CONFIG, listenAwardDayKey } from "../lib/awardRules.js";
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
  // One call builds the entire DEEP Sound home: ordered categories, each with
  // its ordered collections and their ordered tracks (with lyrics availability).
  // The payload is small, so the app needs no per-collection follow-up fetch.
  //
  // Optional auth: signed-out browsing still works and sees the whole
  // catalogue, but premium audio URLs only go to a DEEP Premium caller (see
  // lib/premiumContent). A present-but-expired token 401s, so a client learns to
  // refresh instead of silently receiving the locked view.
  app.get("/sound/home", { preHandler: optionalAuth }, async (req, reply) => {
    const [categories, access] = await Promise.all([
      prisma.soundCategory.findMany(VISIBLE_CATEGORY_TREE),
      requestContentAccess(req),
    ]);
    markVariesByCaller(reply);
    return { categories: categories.map((c) => serializeCategory(c, access)) };
  });

  app.get("/sound/collections/:id", { preHandler: optionalAuth }, async (req, reply) => {
    const { id } = z.object({ id: z.string() }).parse(req.params);
    // A hidden collection - or one under a hidden category - is a 404 here, the
    // same as one that does not exist. The app must not be able to reach content
    // that has been pulled from the shelves.
    const collection = await prisma.soundCollection.findFirst({
      where: { id, isActive: true, category: { isActive: true } },
      include: { tracks: VISIBLE_TRACKS },
    });
    if (!collection) throw ApiError.notFound("Collection not found");
    const access = await requestContentAccess(req);
    markVariesByCaller(reply);
    return { collection: serializeCollection(collection, access) };
  });

  // Lyrics stay public on purpose, premium or not: they are words on a screen,
  // part of what a locked track shows to sell itself, not the audio.
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
  //
  // `completedAt` (optional) is when playback finished on the device, so a
  // listen retried after a network blip still counts on the day it happened;
  // older clients omit it and mean "just now". A listen too old (48h) or too
  // far in the future to place gets `award: null` and `listens: null` — the
  // track still exists, so it is not an error. `listens` is the day's tally
  // after this request: the app's "+1 heart" / "today's 3 are in" feedback.
  app.post("/me/sound/listens", { preHandler: requireAuth }, async (req) => {
    const { trackId, completedAt } = z
      .object({
        trackId: z.string().min(1),
        completedAt: z.string().datetime({ offset: true }).optional(),
      })
      .parse(req.body);
    const userId = req.auth!.sub;

    // Hidden content earns nothing: same shape as garden.ts rejecting a write
    // that names a plant the user is not allowed to select.
    const track = await prisma.soundTrack.findFirst({
      where: { id: trackId, ...VISIBLE_TRACK },
      include: { collection: { select: { isPremium: true } } },
    });
    if (!track) throw ApiError.notFound("Track not found", "track_not_found");
    // A track locked for this caller was never given to them to play, so a
    // completion for it earns nothing. Same code the garden uses for a premium
    // plant, so clients need one premium_locked branch.
    if (isTrackLocked(track, track.collection, await requestContentAccess(req))) {
      throw ApiError.forbidden("This track is DEEP Premium", "premium_locked");
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { timezone: true },
    });
    const tz = requestTimezone(req, user?.timezone);
    rememberTimezone(userId, tz, user?.timezone);
    const now = resolveNow();
    const dayKey = listenAwardDayKey(completedAt ? new Date(completedAt) : undefined, tz, now);

    const outcome = dayKey
      ? await grantAward({
          userId,
          kind: "TRACK_COMPLETED",
          dayKey,
          sourceId: track.id,
          timezone: tz,
        })
      : null;
    const listens = dayKey
      ? {
          dayKey,
          earned: await prisma.award.count({
            where: { userId, kind: "TRACK_COMPLETED", dayKey },
          }),
          perDay: AWARD_CONFIG.TRACK_COMPLETED.perDay,
        }
      : null;
    // The wallet's "earned today" always reads against today, whichever day
    // the listen itself landed on.
    const snapshot = await rewardSnapshot(userId, userDayKey(now, tz));
    return {
      award: outcome ? serializeAwardOutcome(outcome) : null,
      listens,
      ...snapshot,
    };
  });
}
