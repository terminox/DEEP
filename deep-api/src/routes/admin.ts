// Admin content routes.
//
// Content writes here do NOT touch the live tables: they stage a change that an
// admin must explicitly publish (see lib/drafts). Reads merge the live row with
// whatever is staged for it, so the panel shows work in progress while the app
// keeps serving the last published state. Two things stay immediate on purpose -
// peace-message moderation, which cannot wait for a publish, and media uploads,
// which write bytes only.
import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import type {
  SoundCategory,
  SoundCollection,
  SoundTrack,
  TrackLyrics,
  PauseConfig,
  PauseWelcomeMessage,
  PauseIntentionOption,
} from "@prisma/client";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { verifyPassword } from "../auth/password.js";
import { createSession } from "../auth/sessions.js";
import { requireRole } from "../auth/middleware.js";
import { MEDIA_RULES, requireUploadedFile, saveUploadedMedia } from "../lib/upload.js";
import { readAudioDurationSeconds } from "../lib/audioDuration.js";
import {
  serializeUser,
  serializeCategory,
  serializeCollection,
  serializeTrack,
  serializeLyrics,
} from "../lib/serialize.js";
import {
  categoryBody,
  collectionBody,
  trackBody,
  pauseConfigBody,
  welcomeMessageBody,
  intentionBody,
} from "../lib/drafts/registry.js";
import { resolveMany, resolveOne, withPending } from "../lib/drafts/overlay.js";
import {
  stageCreate,
  stageDelete,
  stageDeleteBy,
  stageReorder,
  stageSingleton,
  stageUpdate,
  stageUpsertBy,
} from "../lib/drafts/stage.js";
import {
  discard,
  pendingChanges,
  pendingCount,
  publish,
  validate,
} from "../lib/drafts/publish.js";
import {
  PHASE_ORDER_MESSAGE,
  meditationOverrun,
  phaseTimesIncreasing,
} from "../lib/drafts/validators.js";

const adminOnly = { preHandler: requireRole("ADMIN") };

/** Who staged the change. requireRole has already put the claims on the request. */
function actor(req: FastifyRequest): string {
  return req.auth!.sub;
}

const idParam = z.object({ id: z.string() });
const reorderBody = z.object({ ids: z.array(z.string()) });

/**
 * Every sound row, resolved through its drafts. Counting collections per
 * category and tracks per collection has to happen over the resolved lists, not
 * over Prisma's _count, or a staged create would go uncounted and a staged
 * delete would still be counted.
 */
async function resolvedSoundTree() {
  const [categories, collections, tracks, lyrics] = await Promise.all([
    prisma.soundCategory.findMany(),
    prisma.soundCollection.findMany(),
    prisma.soundTrack.findMany(),
    prisma.trackLyrics.findMany({ select: { id: true, trackId: true, languageCode: true } }),
  ]);
  return {
    categories: await resolveMany<SoundCategory>("SOUND_CATEGORY", categories),
    collections: await resolveMany<SoundCollection>("SOUND_COLLECTION", collections),
    tracks: await resolveMany<SoundTrack>("SOUND_TRACK", tracks),
    lyrics: await resolveMany("TRACK_LYRICS", lyrics, { sort: false }),
  };
}

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

  // ---- Pending changes: review, publish, discard ----

  app.get("/admin/changes", adminOnly, async () => {
    const changes = await pendingChanges();
    return { changes, count: changes.length };
  });

  // Cheap enough to poll from the nav badge on every page.
  app.get("/admin/changes/count", adminOnly, async () => {
    return { count: await pendingCount() };
  });

  const selectionBody = z
    .object({ refs: z.array(z.string()).optional(), all: z.boolean().optional() })
    .refine((b) => b.all === true || (b.refs?.length ?? 0) > 0, {
      message: "select at least one change, or pass all: true",
    });

  /** Dry run: what publishing this selection would do, and what would stop it. */
  app.post("/admin/changes/validate", adminOnly, async (req) => {
    const body = selectionBody.parse(req.body);
    return validate(body.all ? "all" : body.refs!);
  });

  app.post("/admin/changes/publish", adminOnly, async (req) => {
    const body = selectionBody.parse(req.body);
    return publish(body.all ? "all" : body.refs!);
  });

  app.post("/admin/changes/discard", adminOnly, async (req) => {
    const body = selectionBody.parse(req.body);
    return discard(body.all ? "all" : body.refs!);
  });

  // ---- Categories ----
  app.get("/admin/categories", adminOnly, async () => {
    const tree = await resolvedSoundTree();
    return {
      categories: tree.categories.map((c) =>
        withPending(
          serializeCategory({
            ...c.row,
            _count: {
              collections: tree.collections.filter((col) => col.row.categoryId === c.row.id).length,
            },
          }),
          c.pending,
        ),
      ),
    };
  });

  app.post("/admin/categories", adminOnly, async (req) => {
    const body = categoryBody.parse(req.body);
    const staged = await stageCreate<SoundCategory>("SOUND_CATEGORY", body, actor(req));
    return { category: withPending(serializeCategory(staged.row), staged.pending) };
  });

  app.patch("/admin/categories/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = categoryBody.partial().parse(req.body);
    const staged = await stageUpdate<SoundCategory>("SOUND_CATEGORY", id, body, actor(req));
    return { category: withPending(serializeCategory(staged.row), staged.pending) };
  });

  app.delete("/admin/categories/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    await stageDelete("SOUND_CATEGORY", id, actor(req));
    return { ok: true };
  });

  app.post("/admin/categories/reorder", adminOnly, async (req) => {
    const { ids } = reorderBody.parse(req.body);
    await stageReorder("SOUND_CATEGORY", ids, actor(req));
    return { ok: true };
  });

  // ---- Collections ----
  app.get("/admin/collections", adminOnly, async (req) => {
    const { categoryId } = z
      .object({ categoryId: z.string().optional() })
      .parse(req.query);
    const tree = await resolvedSoundTree();
    const collections = categoryId
      ? tree.collections.filter((c) => c.row.categoryId === categoryId)
      : tree.collections;

    return {
      collections: collections.map((c) =>
        withPending(
          serializeCollection({
            ...c.row,
            _count: { tracks: tree.tracks.filter((t) => t.row.collectionId === c.row.id).length },
          }),
          c.pending,
        ),
      ),
    };
  });

  app.get("/admin/collections/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const tree = await resolvedSoundTree();
    const collection = tree.collections.find((c) => c.row.id === id);
    if (!collection) throw ApiError.notFound("Collection not found");

    const tracks = tree.tracks
      .filter((t) => t.row.collectionId === id)
      .map((t) => ({
        ...t.row,
        lyrics: tree.lyrics
          .filter((l) => l.row.trackId === t.row.id)
          .map((l) => ({ languageCode: String(l.row.languageCode) })),
        pending: t.pending,
      }));

    // trackCount comes from _count rather than the tracks array so the tracks
    // are serialized once, with their own pending markers attached.
    return {
      collection: withPending(
        {
          ...serializeCollection({ ...collection.row, _count: { tracks: tracks.length } }),
          tracks: tracks.map((t) => withPending(serializeTrack(t), t.pending)),
        },
        collection.pending,
      ),
    };
  });

  app.post("/admin/collections", adminOnly, async (req) => {
    const body = collectionBody.parse(req.body);
    const staged = await stageCreate<SoundCollection>("SOUND_COLLECTION", body, actor(req));
    return { collection: withPending(serializeCollection(staged.row), staged.pending) };
  });

  app.patch("/admin/collections/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = collectionBody.partial().parse(req.body);
    const staged = await stageUpdate<SoundCollection>("SOUND_COLLECTION", id, body, actor(req));
    return { collection: withPending(serializeCollection(staged.row), staged.pending) };
  });

  app.delete("/admin/collections/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    await stageDelete("SOUND_COLLECTION", id, actor(req));
    return { ok: true };
  });

  app.post("/admin/collections/reorder", adminOnly, async (req) => {
    const { ids } = reorderBody.parse(req.body);
    await stageReorder("SOUND_COLLECTION", ids, actor(req));
    return { ok: true };
  });

  // ---- Tracks ----
  app.post("/admin/tracks", adminOnly, async (req) => {
    const body = trackBody.parse(req.body);
    const staged = await stageCreate<SoundTrack>("SOUND_TRACK", body, actor(req));
    return { track: withPending(serializeTrack(staged.row), staged.pending) };
  });

  app.patch("/admin/tracks/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = trackBody.partial().parse(req.body);
    const staged = await stageUpdate<SoundTrack>("SOUND_TRACK", id, body, actor(req));
    return { track: withPending(serializeTrack(staged.row), staged.pending) };
  });

  app.delete("/admin/tracks/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    await stageDelete("SOUND_TRACK", id, actor(req));
    return { ok: true };
  });

  app.post("/admin/tracks/reorder", adminOnly, async (req) => {
    const { ids } = reorderBody.parse(req.body);
    await stageReorder("SOUND_TRACK", ids, actor(req));
    return { ok: true };
  });

  // Audio upload (multipart). The bytes land immediately - they are inert until
  // a row points at them - but attaching the path to the track is staged, so the
  // audio under a track people are listening to only changes on publish.
  app.post("/admin/tracks/:id/audio", adminOnly, async (req: FastifyRequest) => {
    const { id } = idParam.parse(req.params);
    const track = await resolveOne<SoundTrack>("SOUND_TRACK", id);
    if (!track) throw ApiError.notFound("Track not found");

    const file = await requireUploadedFile(req, MEDIA_RULES.audio.maxBytes);
    const relPath = await saveUploadedMedia(file, "audio", "audio");
    // No unlink of the replaced file, deliberately: prisma/seed.ts assigns audio
    // round-robin from three shared files, so many tracks point at the same path -
    // and /media/audio/global-pause.mp3 is also PauseConfig's default. Deleting on
    // replace would silence other tracks and the nightly Global Pause.
    const staged = await stageUpdate<SoundTrack>(
      "SOUND_TRACK",
      id,
      { audioPath: relPath },
      actor(req),
    );
    return { track: withPending(serializeTrack(staged.row), staged.pending) };
  });

  // ---- Lyrics ----
  app.get("/admin/tracks/:id/lyrics", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const resolved = await resolveMany<TrackLyrics>(
      "TRACK_LYRICS",
      await prisma.trackLyrics.findMany({ where: { trackId: id } }),
      { filter: (row) => row.trackId === id, sort: false },
    );
    return {
      lyrics: resolved.map((l) => withPending(serializeLyrics(l.row), l.pending)),
    };
  });

  // Lyrics are addressed by (track, language) rather than by id, so the staged
  // upsert matches on that pair across live rows AND pending creates.
  app.put("/admin/tracks/:id/lyrics", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = z
      .object({ languageCode: z.string().trim().min(2), content: z.string() })
      .parse(req.body);

    const track = await resolveOne<SoundTrack>("SOUND_TRACK", id);
    if (!track) throw ApiError.notFound("Track not found");

    const staged = await stageUpsertBy<TrackLyrics>(
      "TRACK_LYRICS",
      (row) => row.trackId === id && row.languageCode === body.languageCode,
      { trackId: id, languageCode: body.languageCode, content: body.content },
      { content: body.content },
      actor(req),
    );
    return { lyrics: withPending(serializeLyrics(staged.row), staged.pending) };
  });

  app.delete("/admin/tracks/:id/lyrics/:lang", adminOnly, async (req) => {
    const { id, lang } = z
      .object({ id: z.string(), lang: z.string() })
      .parse(req.params);
    await stageDeleteBy(
      "TRACK_LYRICS",
      (row) => row.trackId === id && row.languageCode === lang,
      actor(req),
    );
    return { ok: true };
  });

  // ---- Global Pause ----

  app.get("/admin/pause/config", adminOnly, async () => {
    // Materialises the singleton with its schema defaults if it has never been
    // saved; that is infrastructure, not an admin content edit.
    await prisma.pauseConfig.upsert({ where: { id: 1 }, update: {}, create: { id: 1 } });
    const resolved = await resolveOne<PauseConfig>("PAUSE_CONFIG", "1");
    return { config: withPending(resolved!.row, resolved!.pending) };
  });

  app.put("/admin/pause/config", adminOnly, async (req) => {
    const body = pauseConfigBody.parse(req.body);
    // Checked here for a clear error while typing, and again at publish, because
    // a staged schedule can sit for days before it is applied.
    if (!phaseTimesIncreasing(body)) {
      throw ApiError.badRequest(PHASE_ORDER_MESSAGE, "invalid_phase_times");
    }

    // The meditation phase runs meditationStart → meditationStart + this, so
    // the track's real length *is* the length of the event. Measured here
    // rather than taken on trust: the browser's metadata read is a hint that
    // quietly returns nothing for some containers, and a nights-long silent
    // disagreement between the window and the track is what this replaces.
    const measured = await readAudioDurationSeconds(body.meditationAudioPath);
    const meditationDurationSeconds = measured ?? body.meditationDurationSeconds;
    if (meditationDurationSeconds == null) {
      throw ApiError.badRequest(
        `Couldn't read the length of "${body.meditationAudioPath}" — send meditationDurationSeconds alongside it.`,
        "meditation_duration_unknown",
      );
    }

    const overrun = meditationOverrun({ ...body, meditationDurationSeconds });
    if (overrun) throw ApiError.badRequest(overrun, "meditation_overruns_window");

    // Fuku's lounge set runs lobbyStart → lobbyStart + this, and the lounge and
    // the home card that opens it both light their ON AIR badge off it. Measured
    // for the same reason as the meditation's: a typed number outlives the file.
    const measuredLobby = await readAudioDurationSeconds(body.lobbyAudioPath);
    const lobbyDurationSeconds = measuredLobby ?? body.lobbyDurationSeconds;
    if (lobbyDurationSeconds == null) {
      throw ApiError.badRequest(
        `Couldn't read the length of "${body.lobbyAudioPath}" — send lobbyDurationSeconds alongside it.`,
        "lobby_duration_unknown",
      );
    }

    // The measured lengths are what get staged, so publishing applies the numbers
    // the files actually hold rather than whatever the form last showed.
    const staged = await stageSingleton<PauseConfig>(
      "PAUSE_CONFIG",
      { ...body, lobbyDurationSeconds, meditationDurationSeconds },
      actor(req),
    );
    return { config: withPending(staged.row, staged.pending) };
  });

  // Welcome messages
  app.get("/admin/pause/welcome-messages", adminOnly, async () => {
    const resolved = await resolveMany<PauseWelcomeMessage>(
      "PAUSE_WELCOME_MESSAGE",
      await prisma.pauseWelcomeMessage.findMany(),
    );
    return { messages: resolved.map((m) => withPending(m.row, m.pending)) };
  });

  app.post("/admin/pause/welcome-messages", adminOnly, async (req) => {
    const body = welcomeMessageBody.parse(req.body);
    const staged = await stageCreate<PauseWelcomeMessage>(
      "PAUSE_WELCOME_MESSAGE",
      body,
      actor(req),
    );
    return { message: withPending(staged.row, staged.pending) };
  });

  app.patch("/admin/pause/welcome-messages/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = welcomeMessageBody.partial().parse(req.body);
    const staged = await stageUpdate<PauseWelcomeMessage>(
      "PAUSE_WELCOME_MESSAGE",
      id,
      body,
      actor(req),
    );
    return { message: withPending(staged.row, staged.pending) };
  });

  app.delete("/admin/pause/welcome-messages/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    await stageDelete("PAUSE_WELCOME_MESSAGE", id, actor(req));
    return { ok: true };
  });

  app.post("/admin/pause/welcome-messages/reorder", adminOnly, async (req) => {
    const { ids } = reorderBody.parse(req.body);
    await stageReorder("PAUSE_WELCOME_MESSAGE", ids, actor(req));
    return { ok: true };
  });

  // Intentions
  app.get("/admin/pause/intentions", adminOnly, async () => {
    const resolved = await resolveMany<PauseIntentionOption>(
      "PAUSE_INTENTION",
      await prisma.pauseIntentionOption.findMany(),
    );
    return { intentions: resolved.map((i) => withPending(i.row, i.pending)) };
  });

  app.post("/admin/pause/intentions", adminOnly, async (req) => {
    const body = intentionBody.parse(req.body);
    const staged = await stageCreate<PauseIntentionOption>("PAUSE_INTENTION", body, actor(req));
    return { intention: withPending(staged.row, staged.pending) };
  });

  app.patch("/admin/pause/intentions/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    const body = intentionBody.partial().parse(req.body);
    const staged = await stageUpdate<PauseIntentionOption>(
      "PAUSE_INTENTION",
      id,
      body,
      actor(req),
    );
    return { intention: withPending(staged.row, staged.pending) };
  });

  app.delete("/admin/pause/intentions/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
    await stageDelete("PAUSE_INTENTION", id, actor(req));
    return { ok: true };
  });

  app.post("/admin/pause/intentions/reorder", adminOnly, async (req) => {
    const { ids } = reorderBody.parse(req.body);
    await stageReorder("PAUSE_INTENTION", ids, actor(req));
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

  // Deliberately NOT staged: this hides user-posted content during a live event,
  // where waiting for someone to remember to publish is the wrong behaviour.
  app.patch("/admin/pause/messages/:id", adminOnly, async (req) => {
    const { id } = idParam.parse(req.params);
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
