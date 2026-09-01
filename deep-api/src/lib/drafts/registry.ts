// The one map of what can be staged. Everything else in this module - staging,
// overlay, validation, publish ordering - is generic and reads from here, so
// adding a tenth staged entity means adding one entry, not touching five files.
import type { DraftEntity, Prisma, PrismaClient } from "@prisma/client";
import { z } from "zod";
import { mediaRefSchema } from "../upload.js";

/** A Prisma client or an interactive-transaction client. */
export type Db = PrismaClient | Prisma.TransactionClient;

/** Points at one live-or-staged record. */
export interface DraftRef {
  entity: DraftEntity;
  entityId: string;
}

export type AnyRow = Record<string, unknown>;

export interface EntitySpec {
  entity: DraftEntity;
  /** Human name for the review screen: "Collection", "Track". */
  noun: string;
  /** Which area of the admin the change belongs to, for grouping. */
  area: "sound" | "garden" | "pause";
  /** The Prisma delegate, resolved against whichever client is in play. */
  delegate: (db: Db) => {
    findUnique(args: AnyRow): Promise<AnyRow | null>;
    findMany(args?: AnyRow): Promise<AnyRow[]>;
    create(args: AnyRow): Promise<AnyRow>;
    update(args: AnyRow): Promise<AnyRow>;
    delete(args: AnyRow): Promise<AnyRow>;
  };
  /** Full body for a create; the same zod objects the routes already validate with. */
  createSchema: z.ZodTypeAny;
  /** Column defaults applied to a staged create, so publish writes a complete row. */
  defaults?: AnyRow;
  /** Row label for the review screen. */
  label: (row: AnyRow) => string;
  /** The parent this record hangs off, if any. Drives grouping and publish order. */
  parentOf: (row: AnyRow) => DraftRef | null;
  /** Entities deleted by the database when this row goes, for delete-impact preview. */
  cascadesTo?: DraftEntity[];
  /** Columns that must be unique, checked across live rows AND pending creates. */
  uniqueFields?: string[];
  /** Mints the id for a staged create. Defaults to a uuid. */
  mintId?: (patch: AnyRow) => string;
  /** True when the model has an `updatedAt` we can use for conflict detection. */
  versioned: boolean;
  /**
   * Singletons (PauseConfig) are upserted rather than created, and their id is
   * fixed, so publish must not try to insert a second row.
   */
  singleton?: { id: unknown };
  /** Coerces a staged id back to the column type. Only PauseConfig is non-string. */
  parseId?: (id: string) => unknown;
}

const palette = z.enum(["tide", "dusk", "bloom", "ember", "mist", "aurora", "dawn"]);
const hms = z.string().regex(/^\d{2}:\d{2}:\d{2}$/, "expected HH:mm:ss");

/** Rejects the ids Postgres would choke on and keeps parentKey unambiguous. */
export const plantIdSchema = z
  .string()
  .trim()
  .regex(/^[a-z0-9-]{2,32}$/, "plant id must be 2-32 chars of a-z, 0-9 or -");

// ---- Body schemas, shared with the routes ----

export const categoryBody = z.object({
  slug: z.string().trim().min(1),
  title: z.string().trim().min(1),
  displayOrder: z.number().int().optional(),
  isActive: z.boolean().optional(),
});

export const collectionBody = z.object({
  categoryId: z.string(),
  title: z.string().trim().min(1),
  subtitle: z.string().trim().min(1),
  palette,
  imageUrl: mediaRefSchema.nullable().optional(),
  isPremium: z.boolean().optional(),
  isActive: z.boolean().optional(),
  displayOrder: z.number().int().optional(),
});

export const trackBody = z.object({
  collectionId: z.string(),
  title: z.string().trim().min(1),
  durationSeconds: z.number().int().positive(),
  kind: z.enum(["INSTRUMENTAL", "GUIDED"]).optional(),
  audioPath: mediaRefSchema.nullable().optional(),
  isPremium: z.boolean().optional(),
  isActive: z.boolean().optional(),
  displayOrder: z.number().int().optional(),
});

export const lyricsBody = z.object({
  trackId: z.string(),
  languageCode: z.string().trim().min(2),
  content: z.string(),
});

export const plantBody = z.object({
  id: plantIdSchema,
  name: z.string().trim().min(1),
  tagline: z.string().trim().min(1),
  imageUrl: mediaRefSchema.nullable().optional(),
  palette: z.string().trim().min(1),
  displayOrder: z.number().int().optional(),
  isPremium: z.boolean().optional(),
  isDefault: z.boolean().optional(),
  isActive: z.boolean().optional(),
});

export const plantStageBody = z.object({
  plantId: z.string(),
  name: z.string().trim().min(1),
  displayOrder: z.number().int().optional(),
  sunlightRequired: z.number().int().min(0).optional(),
  mascotPath: mediaRefSchema.nullable().optional(),
  mascotBgPath: mediaRefSchema.nullable().optional(),
  heroVideoPath: mediaRefSchema.nullable().optional(),
});

export const pauseConfigBody = z.object({
  timezone: z.string().trim().min(1),
  lobbyStart: hms,
  welcomeStart: hms,
  meditationStart: hms,
  windowEnd: hms,
  lobbyAudioPath: mediaRefSchema,
  meditationAudioPath: mediaRefSchema,
  // Optional because the file is the authority: PUT /admin/pause/config reads
  // each track's real length off disk and stages that. Only an absolute
  // third-party URL, which we can't measure, needs a number sent with it. Both
  // columns carry a default, so a create is complete without either.
  lobbyDurationSeconds: z.number().int().positive().optional(),
  meditationDurationSeconds: z.number().int().positive().optional(),
});

export const welcomeMessageBody = z.object({
  text: z.string().trim().min(1),
  displayOrder: z.number().int().optional(),
  isActive: z.boolean().optional(),
});

export const intentionBody = z.object({
  key: z.string().trim().min(1),
  label: z.string().trim().min(1),
  displayOrder: z.number().int().optional(),
  isActive: z.boolean().optional(),
});

// ---- The registry ----

function str(row: AnyRow, key: string): string {
  const v = row[key];
  return typeof v === "string" ? v : "";
}

export const REGISTRY: Record<DraftEntity, EntitySpec> = {
  SOUND_CATEGORY: {
    entity: "SOUND_CATEGORY",
    noun: "Category",
    area: "sound",
    delegate: (db) => db.soundCategory as never,
    createSchema: categoryBody,
    defaults: { displayOrder: 0, isActive: true },
    label: (r) => str(r, "title") || str(r, "slug"),
    parentOf: () => null,
    cascadesTo: ["SOUND_COLLECTION", "SOUND_TRACK", "TRACK_LYRICS"],
    uniqueFields: ["slug"],
    versioned: true,
  },

  SOUND_COLLECTION: {
    entity: "SOUND_COLLECTION",
    noun: "Collection",
    area: "sound",
    delegate: (db) => db.soundCollection as never,
    createSchema: collectionBody,
    defaults: { imageUrl: null, isPremium: false, isActive: true, displayOrder: 0 },
    label: (r) => str(r, "title"),
    parentOf: (r) => ({ entity: "SOUND_CATEGORY", entityId: str(r, "categoryId") }),
    cascadesTo: ["SOUND_TRACK", "TRACK_LYRICS"],
    versioned: true,
  },

  SOUND_TRACK: {
    entity: "SOUND_TRACK",
    noun: "Track",
    area: "sound",
    delegate: (db) => db.soundTrack as never,
    createSchema: trackBody,
    defaults: {
      kind: "INSTRUMENTAL",
      audioPath: null,
      isPremium: false,
      isActive: true,
      displayOrder: 0,
    },
    label: (r) => str(r, "title"),
    parentOf: (r) => ({ entity: "SOUND_COLLECTION", entityId: str(r, "collectionId") }),
    cascadesTo: ["TRACK_LYRICS"],
    versioned: true,
  },

  TRACK_LYRICS: {
    entity: "TRACK_LYRICS",
    noun: "Lyrics",
    area: "sound",
    delegate: (db) => db.trackLyrics as never,
    createSchema: lyricsBody,
    label: (r) => str(r, "languageCode").toUpperCase(),
    parentOf: (r) => ({ entity: "SOUND_TRACK", entityId: str(r, "trackId") }),
    versioned: true,
  },

  PLANT: {
    entity: "PLANT",
    noun: "Plant",
    area: "garden",
    delegate: (db) => db.plant as never,
    createSchema: plantBody,
    defaults: {
      imageUrl: null,
      displayOrder: 0,
      isPremium: false,
      isDefault: false,
      isActive: true,
    },
    label: (r) => str(r, "name") || str(r, "id"),
    parentOf: () => null,
    cascadesTo: ["PLANT_STAGE"],
    // The plant id IS the slug, chosen by the admin, so it is the unique field.
    uniqueFields: ["id"],
    mintId: (patch) => str(patch, "id"),
    versioned: true,
  },

  PLANT_STAGE: {
    entity: "PLANT_STAGE",
    noun: "Stage",
    area: "garden",
    delegate: (db) => db.plantStage as never,
    createSchema: plantStageBody,
    defaults: {
      displayOrder: 0,
      sunlightRequired: 0,
      mascotPath: null,
      mascotBgPath: null,
      heroVideoPath: null,
    },
    label: (r) => str(r, "name"),
    parentOf: (r) => ({ entity: "PLANT", entityId: str(r, "plantId") }),
    versioned: false,
  },

  PAUSE_CONFIG: {
    entity: "PAUSE_CONFIG",
    noun: "Global Pause schedule",
    area: "pause",
    delegate: (db) => db.pauseConfig as never,
    createSchema: pauseConfigBody,
    label: () => "Global Pause schedule",
    parentOf: () => null,
    versioned: true,
    singleton: { id: 1 },
    parseId: () => 1,
  },

  PAUSE_WELCOME_MESSAGE: {
    entity: "PAUSE_WELCOME_MESSAGE",
    noun: "Welcome message",
    area: "pause",
    delegate: (db) => db.pauseWelcomeMessage as never,
    createSchema: welcomeMessageBody,
    defaults: { displayOrder: 0, isActive: true },
    label: (r) => str(r, "text").slice(0, 60),
    parentOf: () => null,
    versioned: false,
  },

  PAUSE_INTENTION: {
    entity: "PAUSE_INTENTION",
    noun: "Intention",
    area: "pause",
    delegate: (db) => db.pauseIntentionOption as never,
    createSchema: intentionBody,
    defaults: { displayOrder: 0, isActive: true },
    label: (r) => str(r, "label") || str(r, "key"),
    parentOf: () => null,
    uniqueFields: ["key"],
    versioned: false,
  },
};

export function specFor(entity: DraftEntity): EntitySpec {
  return REGISTRY[entity];
}

/** Parent-before-child. Publish creates in this order and deletes in reverse. */
export const PUBLISH_ORDER: DraftEntity[] = [
  "PAUSE_CONFIG",
  "PAUSE_WELCOME_MESSAGE",
  "PAUSE_INTENTION",
  "SOUND_CATEGORY",
  "SOUND_COLLECTION",
  "SOUND_TRACK",
  "TRACK_LYRICS",
  "PLANT",
  "PLANT_STAGE",
];

export function refKey(ref: DraftRef): string {
  return `${ref.entity}:${ref.entityId}`;
}

export function parseRefKey(key: string): DraftRef {
  const at = key.indexOf(":");
  return {
    entity: key.slice(0, at) as DraftEntity,
    entityId: key.slice(at + 1),
  };
}
