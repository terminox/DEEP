import type { FastifyInstance } from "fastify";
import { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireAuth } from "../auth/middleware.js";
import { serializePlaylist } from "../lib/serialize.js";

// Playlists: the tracks a listener kept for later.
//
// A user has exactly one playlist today, created lazily on first read and
// marked `isDefault`. Every route is nonetheless keyed by playlist id, so
// letting someone keep several is an addition here rather than a reshape.

/** The name the automatically-created playlist carries. */
const DEFAULT_PLAYLIST_NAME = "Playlist";

/**
 * Everything a playlist read needs in one query: items newest-kept-first, each
 * with its track and the collection that track came from (artwork + origin
 * name). The origin collection deliberately arrives without its own tracks.
 */
const playlistInclude = {
  items: {
    orderBy: { createdAt: "desc" },
    include: { track: { include: { collection: true } } },
  },
} satisfies Prisma.PlaylistInclude;

/**
 * The user's default playlist, created on first sight. The create can lose a
 * race with a concurrent request; the partial unique index on
 * `playlists("userId") WHERE "isDefault"` turns that into a P2002, and the
 * winner's row is what we re-read.
 */
async function ensureDefaultPlaylist(userId: string) {
  const existing = await prisma.playlist.findFirst({
    where: { userId, isDefault: true },
    select: { id: true },
  });
  if (existing) return existing.id;

  try {
    const created = await prisma.playlist.create({
      data: { userId, name: DEFAULT_PLAYLIST_NAME, isDefault: true },
      select: { id: true },
    });
    return created.id;
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002") {
      const winner = await prisma.playlist.findFirst({
        where: { userId, isDefault: true },
        select: { id: true },
      });
      if (winner) return winner.id;
    }
    throw e;
  }
}

/**
 * Loads one playlist the caller actually owns. A playlist belonging to someone
 * else reads as missing rather than forbidden — a 403 would confirm the id
 * exists.
 */
async function ownedPlaylist(playlistId: string, userId: string) {
  const playlist = await prisma.playlist.findFirst({
    where: { id: playlistId, userId },
    include: playlistInclude,
  });
  if (!playlist) {
    throw ApiError.notFound("Playlist not found", "playlist_not_found");
  }
  return playlist;
}

const playlistParams = z.object({ id: z.string().uuid() });

export async function playlistRoutes(app: FastifyInstance) {
  // Every playlist with its items, in one call. With a single playlist the
  // payload is a handful of rows, so the client needs no follow-up fetch —
  // the same reasoning behind /sound/home returning the whole tree.
  app.get("/me/playlists", { preHandler: requireAuth }, async (req) => {
    const userId = req.auth!.sub;
    await ensureDefaultPlaylist(userId);
    const playlists = await prisma.playlist.findMany({
      where: { userId },
      orderBy: [{ isDefault: "desc" }, { displayOrder: "asc" }, { createdAt: "asc" }],
      include: playlistInclude,
    });
    return { playlists: playlists.map(serializePlaylist) };
  });

  // Keeping a track is idempotent: keeping one twice is the same as keeping it
  // once, and both answers are the whole playlist so the client reconciles
  // against server truth rather than guessing.
  app.post("/me/playlists/:id/items", { preHandler: requireAuth }, async (req) => {
    const { id } = playlistParams.parse(req.params);
    const { trackId } = z.object({ trackId: z.string().uuid() }).parse(req.body);
    const userId = req.auth!.sub;

    await ownedPlaylist(id, userId);

    const track = await prisma.soundTrack.findUnique({
      where: { id: trackId },
      select: { id: true },
    });
    if (!track) throw ApiError.notFound("Track not found", "track_not_found");

    try {
      await prisma.playlistItem.create({ data: { playlistId: id, trackId } });
      await prisma.playlist.update({ where: { id }, data: { updatedAt: new Date() } });
    } catch (e) {
      // Already kept — nothing to do, and nothing to tell the caller about.
      if (!(e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2002")) {
        throw e;
      }
    }

    return { playlist: serializePlaylist(await ownedPlaylist(id, userId)) };
  });

  app.delete("/me/playlists/:id/items/:trackId", { preHandler: requireAuth }, async (req) => {
    const { id, trackId } = playlistParams
      .extend({ trackId: z.string().uuid() })
      .parse(req.params);
    const userId = req.auth!.sub;

    await ownedPlaylist(id, userId);

    // Idempotent: removing something already gone is a success.
    const removed = await prisma.playlistItem
      .delete({ where: { playlistId_trackId: { playlistId: id, trackId } } })
      .then(() => true)
      .catch(() => false);
    if (removed) {
      await prisma.playlist.update({ where: { id }, data: { updatedAt: new Date() } });
    }

    return { playlist: serializePlaylist(await ownedPlaylist(id, userId)) };
  });
}
