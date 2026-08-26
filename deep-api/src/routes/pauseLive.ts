import crypto from "node:crypto";
import type { FastifyInstance } from "fastify";
import type { PeaceMessage } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireAuth, optionalAuth } from "../auth/middleware.js";
import { mediaUrl } from "../lib/media.js";
import {
  resolveOccurrence,
  occurrenceOn,
  resolveNow,
  setLiveWindow,
  localDate,
} from "../lib/pauseSchedule.js";
import { attendanceCovers } from "../lib/awardRules.js";
import { grantAward } from "../lib/awards.js";
import { requestTimezone, rememberTimezone, userDayKey } from "../lib/clientDay.js";
import { rewardSnapshot } from "../lib/rewardPayload.js";
import { serializeAwardOutcome } from "../lib/serialize.js";
import * as presence from "../lib/pausePresence.js";
import * as geoip from "../lib/geoip.js";
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

/**
 * Durable "was present" record behind the attendance award: first beat of the
 * night creates the row, later beats increment `beats` and widen
 * [firstSeenAt, lastSeenAt] — never narrowing, so the dev time-travel loop
 * wrapping to the window start can't shrink an attendance already recorded.
 *
 * One atomic upsert rather than read-then-write: two heartbeats racing on
 * the same (userId, pauseDate) could otherwise both read the same "existing"
 * row and one write could clobber the other's lastSeenAt backwards. Postgres
 * resolves the conflict itself, using GREATEST/LEAST against the row as it
 * stands at write time, so the result is correct under concurrency without a
 * lock.
 */
async function recordAttendance(userId: string, pauseDate: string, now: Date) {
  await prisma.$executeRaw`
    INSERT INTO "pause_attendances" ("id", "userId", "pauseDate", "firstSeenAt", "lastSeenAt", "beats")
    VALUES (${crypto.randomUUID()}, ${userId}, ${pauseDate}, ${now}, ${now}, 1)
    ON CONFLICT ("userId", "pauseDate") DO UPDATE SET
      "lastSeenAt" = GREATEST("pause_attendances"."lastSeenAt", EXCLUDED."lastSeenAt"),
      "firstSeenAt" = LEAST("pause_attendances"."firstSeenAt", EXCLUDED."firstSeenAt"),
      "beats" = "pause_attendances"."beats" + 1
  `;
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
    const isNew = !presence.isActive(key);
    const loc = isNew ? await geoip.lookup(req.ip) : null;
    const result = presence.heartbeat(
      key,
      body.countryISO ?? null,
      isNew ? (loc ? { lat: loc.lat, lon: loc.lon } : null) : undefined,
      isNew ? (loc?.continent ?? null) : undefined,
    );

    // Signed-in beats landing inside the meditation window also leave a
    // durable attendance record — the evidence POST /me/pause/award judges.
    const now = resolveNow();
    if (req.auth) {
      const config = await loadConfig();
      const occurrence = resolveOccurrence(config, now);
      if (occurrence.phaseAt(now) === "meditation") {
        await recordAttendance(req.auth.sub, occurrence.pauseDate, now);
      }
    }

    return { ok: true, serverNow: now.toISOString(), location: result.location };
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
      // Where the world is pausing, coarsely — what the live session names
      // beneath the globe. Wider coverage than `byCountry`: it also holds
      // presences the device never named a country for.
      byContinent: Object.entries(snap.byContinent).map(([iso, count]) => ({ iso, count })),
      unlocatedByCountry: Object.entries(snap.unlocatedByCountry).map(([iso, count]) => ({
        iso,
        count,
      })),
      points: snap.points,
      recentJoins: snap.recentJoins.map((j) => ({
        iso: j.iso,
        at: j.at.toISOString(),
        ...(j.lat !== undefined ? { lat: j.lat, lon: j.lon } : {}),
      })),
      messages: messages.map(serializePeaceMessage),
    };
  });

  // Explicit attendance-award claim, called by the app on entering the
  // feedback phase — but honoured for the rest of the (config-timezone) day,
  // so a client that missed the moment can still claim. The server judges
  // eligibility from the durable heartbeat record; grantAward's ledger unique
  // makes the claim idempotent.
  app.post("/me/pause/award", { preHandler: requireAuth }, async (req) => {
    const userId = req.auth!.sub;
    const now = resolveNow();
    const config = await loadConfig();
    // Today's pause — deliberately NOT resolveOccurrence, which rolls to
    // tomorrow once tonight's window has ended.
    const { pauseDate, phases } = occurrenceOn(config, localDate(now, config.timezone));
    const meditation = phases.find((p) => p.key === "meditation")!;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw ApiError.unauthorized();
    const tz = requestTimezone(req, user.timezone, config.timezone);
    rememberTimezone(userId, tz, user.timezone);

    const attendance = await prisma.pauseAttendance.findUnique({
      where: { userId_pauseDate: { userId, pauseDate } },
    });
    const eligible =
      attendance != null &&
      attendanceCovers(
        { startsAt: meditation.startsAt, endsAt: meditation.endsAt },
        attendance,
      );

    const outcome = eligible
      ? await grantAward({
          userId,
          kind: "PAUSE_ATTENDED",
          dayKey: pauseDate,
          tallyDayKey: userDayKey(now, tz),
          timezone: tz,
        })
      : null;

    const snapshot = await rewardSnapshot(userId, userDayKey(now, tz));
    return {
      eligible,
      award: outcome ? serializeAwardOutcome(outcome) : null,
      ...snapshot,
      serverNow: now.toISOString(),
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

    // First message of the night earns; the award ledger's unique on
    // (user, kind, pauseDate) turns every later one into `duplicate`.
    const tz = requestTimezone(req, user.timezone, config.timezone);
    rememberTimezone(user.id, tz, user.timezone);
    const outcome = await grantAward({
      userId: user.id,
      kind: "PEACE_MESSAGE",
      dayKey: pauseDate,
      tallyDayKey: userDayKey(now, tz),
      timezone: tz,
    });
    const snapshot = await rewardSnapshot(user.id, userDayKey(now, tz));

    return {
      message: serializePeaceMessage(message),
      serverNow: now.toISOString(),
      award: serializeAwardOutcome(outcome),
      ...snapshot,
    };
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

    // Dev-only geolocation override for the globe: "fixed" pins every new
    // join to one lat/lon (real device, fake location), "scatter" seeds N
    // fake presences at random coordinates (fake devices, no real join),
    // "drip" joins N fake participants one at a time through the real join
    // path so the client sees spark + ripple like genuine arrivals, "off"
    // restores real IP lookups (and cancels any drip in flight). Registered
    // only alongside time-travel.
    app.post("/dev/pause/fake-location", async (req) => {
      const body = z
        .object({
          mode: z.enum(["off", "fixed", "scatter", "drip"]),
          lat: z.number().min(-90).max(90).optional(),
          lon: z.number().min(-180).max(180).optional(),
          seed: z.number().int().positive().max(500).optional(),
          intervalMs: z.number().int().min(250).max(30000).default(4000),
        })
        .refine((b) => b.mode !== "fixed" || (b.lat !== undefined && b.lon !== undefined), {
          message: "lat and lon required for mode=fixed",
        })
        .refine((b) => b.mode !== "scatter" || b.seed !== undefined, {
          message: "seed required for mode=scatter",
        })
        .refine(
          (b) => b.mode !== "drip" || (b.seed !== undefined && b.seed >= 1 && b.seed <= 50),
          { message: "seed (1-50) required for mode=drip" },
        )
        .parse(req.body);

      if (body.mode === "off") {
        geoip.setFixedLocation(null);
        presence.stopDrip();
      } else if (body.mode === "fixed") {
        geoip.setFixedLocation({ lat: body.lat!, lon: body.lon! });
      } else if (body.mode === "scatter") {
        presence.injectFake(body.seed!);
      } else {
        presence.startDrip(body.seed!, body.intervalMs);
        return { ok: true, mode: body.mode, seed: body.seed!, intervalMs: body.intervalMs };
      }
      return { ok: true, mode: body.mode };
    });
  }
}
