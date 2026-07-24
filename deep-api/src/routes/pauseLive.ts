import type { FastifyInstance } from "fastify";
import type { PeaceMessage } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireAuth, optionalAuth } from "../auth/middleware.js";
import { mediaUrl } from "../lib/media.js";
import { resolveOccurrence, debugNow } from "../lib/pauseSchedule.js";
import * as presence from "../lib/pausePresence.js";

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
    const now = debugNow(req) ?? new Date();
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
    return { ok: true, serverNow: new Date().toISOString() };
  });

  app.delete("/pause/presence/:presenceId", { preHandler: optionalAuth }, async (req) => {
    const { presenceId } = z.object({ presenceId: z.string() }).parse(req.params);
    presence.leave(`anon:${presenceId}`);
    if (req.auth) presence.leave(`user:${req.auth.sub}`);
    return { ok: true, serverNow: new Date().toISOString() };
  });

  // One poll feeds everything live: counter, country glow, join ripples, and
  // the feedback-phase message feed.
  app.get("/pause/live", { preHandler: optionalAuth }, async (req) => {
    const now = debugNow(req) ?? new Date();
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

  // Peace messages are written only while the feedback phase is open — the
  // server is the authority, so a skewed client clock can't sneak one in.
  app.post("/pause/messages", { preHandler: requireAuth }, async (req) => {
    const body = z
      .object({
        text: z.string().transform((t) => t.trim()).pipe(z.string().min(1).max(280)),
        countryISO: countryISOSchema,
      })
      .parse(req.body);
    const now = debugNow(req) ?? new Date();
    const config = await loadConfig();
    const occurrence = resolveOccurrence(config, now);

    if (occurrence.phaseAt(now) !== "feedback") {
      throw ApiError.forbidden("Peace messages open in the feedback phase", "phase_closed");
    }

    const auth = req.auth!;
    const already = await prisma.peaceMessage.count({
      where: { userId: auth.sub, pauseDate: occurrence.pauseDate },
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
        pauseDate: occurrence.pauseDate,
      },
    });
    return { message: serializePeaceMessage(message), serverNow: now.toISOString() };
  });

  // Public read of recent published messages (off-hours lobby feed).
  app.get("/pause/messages", async (req) => {
    const query = z
      .object({
        limit: z.coerce.number().int().positive().max(50).default(20),
        before: z.coerce.date().optional(),
      })
      .parse(req.query);
    const messages = await prisma.peaceMessage.findMany({
      where: {
        status: "PUBLISHED",
        ...(query.before ? { createdAt: { lt: query.before } } : {}),
      },
      orderBy: { createdAt: "desc" },
      take: query.limit,
    });
    return {
      serverNow: new Date().toISOString(),
      messages: messages.map(serializePeaceMessage),
    };
  });

  // Intention + mood from the feedback phase; one row per user per night.
  app.post("/pause/reflection", { preHandler: requireAuth }, async (req) => {
    const body = z
      .object({
        intention: z.string().trim().min(1).max(64).optional(),
        mood: z.string().trim().min(1).max(64).optional(),
      })
      .refine((b) => b.intention || b.mood, { message: "intention or mood required" })
      .parse(req.body);
    const now = debugNow(req) ?? new Date();
    const config = await loadConfig();
    const occurrence = resolveOccurrence(config, now);

    if (occurrence.phaseAt(now) !== "feedback") {
      throw ApiError.forbidden("Reflections open in the feedback phase", "phase_closed");
    }

    const auth = req.auth!;
    await prisma.pauseReflection.upsert({
      where: { userId_pauseDate: { userId: auth.sub, pauseDate: occurrence.pauseDate } },
      create: {
        userId: auth.sub,
        pauseDate: occurrence.pauseDate,
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
}
