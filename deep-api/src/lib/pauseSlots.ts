import type { PauseConfig, PauseSlot } from "@prisma/client";
import { prisma } from "../prisma.js";

// Loading the Global Pause schedule: the shared config plus the day's slots.
//
// Kept apart from lib/pauseSchedule.ts on purpose — that file is the pure time
// math and must stay free of Prisma so its tests are plain values.

/** The default slot a database with none at all is given. */
const DEFAULT_SLOT = {
  lobbyStart: "20:30:00",
  welcomeStart: "20:39:50",
  meditationStart: "20:40:00",
  windowEnd: "21:00:00",
} as const;

export interface PauseSchedule {
  config: PauseConfig;
  /** In clock order by meditation start. Never empty. */
  slots: PauseSlot[];
}

/**
 * Just the shared config, materialised on first touch. For the routes that only
 * need the timezone — peace messages and reflections are keyed on the calendar
 * day, not on any one occurrence, so they have no reason to load the slots.
 */
export async function loadPauseConfig(): Promise<PauseConfig> {
  return prisma.pauseConfig.upsert({ where: { id: 1 }, update: {}, create: { id: 1 } });
}

/**
 * The config and every slot, both materialised from defaults on first touch.
 *
 * Creating them is infrastructure, not an admin content edit — the same
 * argument the config's upsert has always made. It is also what keeps every
 * route total: no caller has to handle "the Global Pause does not exist yet",
 * and `/pause/schedule` can never answer with an empty phase list on a fresh
 * database.
 */
export async function loadPauseSchedule(): Promise<PauseSchedule> {
  const config = await loadPauseConfig();

  const slots = await prisma.pauseSlot.findMany({ orderBy: { meditationStart: "asc" } });
  if (slots.length > 0) return { config, slots };

  // Racing requests on a fresh database would both find nothing; the unique on
  // meditationStart makes the loser's create a no-op rather than a second slot.
  const created = await prisma.pauseSlot
    .create({ data: DEFAULT_SLOT })
    .catch(() => null);
  return {
    config,
    slots: created
      ? [created]
      : await prisma.pauseSlot.findMany({ orderBy: { meditationStart: "asc" } }),
  };
}
