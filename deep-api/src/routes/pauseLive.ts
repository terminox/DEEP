import type { FastifyInstance } from "fastify";
import type { PeaceMessage } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireAuth, optionalAuth } from "../auth/middleware.js";
import { mediaUrl } from "../lib/media.js";
import { resolveOccurrence, resolveNow, setLiveWindow, localDate } from "../lib/pauseSchedule.js";
import * as presence from "../lib/pausePresence.js";
import { env } from "../env.js";

// The live Global Pause event: schedule, presence, and peace messages.
// (The similarly-named pause.ts serves the tab's *content feed*; this file is
// the nightly event's mechanics.)

const MESSAGES_PER_NIGHT = 3;
const LIVE_MESSAGE_COUNT = 10;

const countryISOSchema = z
  .string()
  .regex(/^[A-Z]{2}$/, "countryISO must be ISO-3166 alpha-2")
  .optional();

function serializePeaceMessage(message: PeaceMessage) {
  return {
    id: message.id,
    displayName: message.displayName,
    countryISO: message.countryISO,
    text: message.text,
    createdAt: message.createdAt.toISOString(),
  };
}

// The feed pages by keyset, not offset. createdAt alone is not unique (batch
// inserts share timestamps), so the cursor carries (createdAt, id) — the same
// pair the feed sorts by — encoded opaquely.
function encodeMessageCursor(message: PeaceMessage): string {
  return Buffer.from(`${message.createdAt.toISOString()}|${message.id}`).toString("base64url");
}

function decodeMessageCursor(cursor: string): { createdAt: Date; id: string } {
  const decoded = Buffer.from(cursor, "base64url").toString("utf8");
  const separator = decoded.lastIndexOf("|");
  if (separator === -1) throw ApiError.badRequest("Invalid cursor", "invalid_cursor");
  const createdAt = new Date(decoded.slice(0, separator));
  const id = decoded.slice(separator + 1);
  if (Number.isNaN(createdAt.getTime()) || !id) {
    throw ApiError.badRequest("Invalid cursor", "invalid_cursor");
  }
  return { createdAt, id };
}

/** The singleton config row, created from schema defaults on first touch. */
async function loadConfig() {
  return prisma.pauseConfig.upsert({
    where: { id: 1 },
    update: {},
    create: { id: 1 },
  });
}

export async function pauseLiveRoutes(app: FastifyInstance) {
  // Everything a client needs to run the event locally: absolute phase
  // instants for tonight's occurrence, audio, welcome copy, intentions —
  // plus serverNow so the client can correct its clock.
  app.get("/pause/schedule", { preHandler: optionalAuth }, async (req) => {
    const now = resolveNow();
    const config = await loadConfig();
    const occurrence = resolveOccurrence(config, now);
    const [welcomeMessages, intentions] = await Promise.all([
      prisma.pauseWelcomeMessage.findMany({
        where: { isActive: true },
        orderBy: { displayOrder: "asc" },
      }),
      prisma.pauseIntentionOption.findMany({
        where: { isActive: true },
        orderBy: { displayOrder: "asc" },
      }),
    ]);

    return {
      serverNow: now.toISOString(),
      pauseDate: occurrence.pauseDate,
      timezone: config.timezone,
      phases: occurrence.phases.map((p) => ({
        key: p.key,
        startsAt: p.startsAt.toISOString(),
        endsAt: p.endsAt.toISOString(),
      })),
      lobbyAudioUrl: mediaUrl(config.lobbyAudioPath),
      meditationAudioUrl: mediaUrl(config.meditationAudioPath),
      meditationDurationSeconds: config.meditationDurationSeconds,
      welcomeMessages: welcomeMessages.map((m) => m.text),
      intentions: intentions.map((i) => ({ key: i.key, label: i.label })),
    };
  });

  // Presence key: signed-in users count once across devices; anonymous
  // visitors count by their locally-persisted presenceId.
  app.post("/pause/presence/heartbeat", { preHandler: optionalAuth }, async (req) => {
    const body = z
      .object({ presenceId: z.string().min(8).max(64), countryISO: countryISOSchema })
      .parse(req.body);
    const key = req.auth ? `user:${req.auth.sub}` : `anon:${body.presenceId}`;
    presence.heartbeat(key, body.countryISO ?? null);
    return { ok: true, serverNow: resolveNow().toISOString() };
  });

  app.delete("/pause/presence/:presenceId", { preHandler: optionalAuth }, async (req) => {
    const { presenceId } = z.object({ presenceId: z.string() }).parse(req.params);
    presence.leave(`anon:${presenceId}`);
    if (req.auth) presence.leave(`user:${req.auth.sub}`);
    return { ok: true, serverNow: resolveNow().toISOString() };
  });

  // One poll feeds everything live: counter, country glow, join ripples, and
  // tonight's message feed.
  app.get("/pause/live", { preHandler: optionalAuth }, async (req) => {
    const now = resolveNow();
    const config = await loadConfig();
    const occurrence = resolveOccurrence(config, now);
    const snap = presence.snapshot();
    const messages = await prisma.peaceMessage.findMany({
      where: { pauseDate: occurrence.pauseDate, status: "PUBLISHED" },
      orderBy: { createdAt: "desc" },
      take: LIVE_MESSAGE_COUNT,
    });

    return {
      serverNow: now.toISOString(),
      phase: occurrence.phaseAt(now),
      participantCount: snap.total,
      byCountry: Object.entries(snap.byCountry).map(([iso, count]) => ({ iso, count })),
      recentJoins: snap.recentJoins.map((j) => ({ iso: j.iso, at: j.at.toISOString() })),
      messages: messages.map(serializePeaceMessage),
    };
  });

  // Peace messages are accepted any time of day — pauseDate stamps the
  // calendar night of posting in the config timezone, not the resolved
  // occurrence (which rolls to tomorrow once tonight's window has closed).
  app.post("/pause/messages", { preHandler: requireAuth }, async (req) => {
    const body = z
      .object({
        text: z.string().transform((t) => t.trim()).pipe(z.string().min(1).max(280)),
        countryISO: countryISOSchema,
      })
      .parse(req.body);
    const now = resolveNow();
    const config = await loadConfig();
    const pauseDate = localDate(now, config.timezone);

    const auth = req.auth!;
    const already = await prisma.peaceMessage.count({
      where: { userId: auth.sub, pauseDate },
    });
    if (already >= MESSAGES_PER_NIGHT) {
      throw ApiError.forbidden("Message limit reached for tonight", "message_limit");
    }

    const user = await prisma.user.findUnique({ where: { id: auth.sub } });
    if (!user) throw ApiError.unauthorized();

    const message = await prisma.peaceMessage.create({
      data: {
        userId: user.id,
        displayName: user.displayName,
        countryISO: body.countryISO ?? null,
        text: body.text,
        pauseDate,
      },
    });
    return { message: serializePeaceMessage(message), serverNow: now.toISOString() };
  });

  // Public read of published messages, newest first — available around the
  // clock. Keyset-paginated: pass back `nextCursor` to fetch the next page;
  // null means the feed is exhausted.
  app.get("/pause/messages", async (req) => {
    const query = z
      .object({
        limit: z.coerce.number().int().positive().max(50).default(20),
        cursor: z.string().optional(),
      })
      .parse(req.query);
    const cursor = query.cursor ? decodeMessageCursor(query.cursor) : null;
    const page = await prisma.peaceMessage.findMany({
      where: {
        status: "PUBLISHED",
        ...(cursor
          ? {
              OR: [
                { createdAt: { lt: cursor.createdAt } },
                { createdAt: cursor.createdAt, id: { lt: cursor.id } },
              ],
            }
          : {}),
      },
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take: query.limit + 1,
    });
    const hasMore = page.length > query.limit;
    const messages = hasMore ? page.slice(0, query.limit) : page;
    return {
      serverNow: resolveNow().toISOString(),
      messages: messages.map(serializePeaceMessage),
      nextCursor: hasMore ? encodeMessageCursor(messages[messages.length - 1]!) : null,
    };
  });

  // Intention + mood, accepted any time of day; one row per user per night,
  // keyed by the calendar night of posting in the config timezone.
  app.post("/pause/reflection", { preHandler: requireAuth }, async (req) => {
    const body = z
      .object({
        intention: z.string().trim().min(1).max(64).optional(),
        mood: z.string().trim().min(1).max(64).optional(),
      })
      .refine((b) => b.intention || b.mood, { message: "intention or mood required" })
      .parse(req.body);
    const now = resolveNow();
    const config = await loadConfig();
    const pauseDate = localDate(now, config.timezone);

    const auth = req.auth!;
    await prisma.pauseReflection.upsert({
      where: { userId_pauseDate: { userId: auth.sub, pauseDate } },
      create: {
        userId: auth.sub,
        pauseDate,
        intention: body.intention ?? null,
        mood: body.mood ?? null,
      },
      update: {
        ...(body.intention !== undefined ? { intention: body.intention } : {}),
        ...(body.mood !== undefined ? { mood: body.mood } : {}),
      },
    });
    return { ok: true, serverNow: now.toISOString() };
  });

  // Dev-only time travel: "live" holds the meditation window perpetually open
  // (server time loops inside it until "off"); "countdown" starts the loop 15
  // minutes before the meditation so the card's countdown ticks down, flips
  // live at 00:00, plays through the meditation, then wraps. Clients follow
  // on their next response — they sync to serverNow on everything above.
  // Registered only when the environment allows overrides, so the route does
  // not exist anywhere real.
  if (env.ALLOW_TIME_OVERRIDE) {
    // Mirrors GlobalPauseSession.countdownLead on iOS. This is dev tooling
    // only (client presentation constant), so a mismatch only skews the dev
    // preview — it doesn't affect anything real.
    const COUNTDOWN_LEAD_MS = 15 * 60 * 1000;

    app.post("/dev/pause/time-travel", async (req) => {
      const { mode } = z.object({ mode: z.enum(["live", "countdown", "off"]) }).parse(req.body);
      if (mode === "off") {
        setLiveWindow(null);
        return { mode, serverNow: new Date().toISOString() };
      }
      const config = await loadConfig();
      const occurrence = resolveOccurrence(config, new Date());
      const meditation = occurrence.phases.find((p) => p.key === "meditation")!;
      if (mode === "countdown") {
        setLiveWindow({
          startsAt: new Date(meditation.startsAt.getTime() - COUNTDOWN_LEAD_MS),
          endsAt: meditation.endsAt,
        });
      } else {
        setLiveWindow(meditation);
      }
      return { mode, serverNow: resolveNow().toISOString() };
    });
  }
}
