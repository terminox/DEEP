// Thai copy for the server-authored catalogue.
//
// Keyed by the record's *English* source text rather than by id, because ids
// are generated per seed run — matching on the English means this file stays
// valid across a `db:seed` that rebuilds the catalogue from scratch.
//
// Deliberately no import from `src/env.ts`: the migrate Job that runs seeding
// in deploy has only DATABASE_URL, so anything that validates a fuller
// environment would fail there.
import { PrismaClient, type TranslatableEntity } from "@prisma/client";

const LANGUAGE = "th";

/** English source -> Thai, per translatable field. */
type Dictionary = Record<string, string>;

const CATEGORY_TITLES: Dictionary = {
  Calm: "สงบ",
  Morning: "เช้า",
  Sleep: "หลับ",
  "Deep Teacher": "ครูแห่งใจ",
  "Deep Kids": "เด็ก ๆ",
};

const COLLECTION_TITLES: Dictionary = {
  "Northern Calm": "ความสงบแห่งเหนือ",
  "Aurora Drift": "แสงเหนือล่องลอย",
};

const COLLECTION_SUBTITLES: Dictionary = {
  "Wide skies, settled breath": "ฟ้ากว้าง ลมหายใจนิ่ง",
};

const PLANT_NAMES: Dictionary = {
  Oak: "โอ๊ก",
  Sakura: "ซากุระ",
  Lotus: "บัว",
  Orange: "ส้ม",
};

const PLANT_TAGLINES: Dictionary = {
  "Steady & Strong": "มั่นคงและแข็งแรง",
};

const STAGE_NAMES: Dictionary = {
  Seedling: "ต้นกล้า",
  "Young Oak": "โอ๊กต้นอ่อน",
  "Mature Oak": "โอ๊กเต็มวัย",
};

const INTENTION_LABELS: Dictionary = {
  Peace: "ความสงบ",
  Healing: "การเยียวยา",
  Gratitude: "ความกตัญญู",
  "Someone I love": "คนที่ฉันรัก",
  Other: "อื่น ๆ",
};

const WELCOME_MESSAGES: Dictionary = {
  "Welcome. Tonight the world pauses together.":
    "ยินดีต้อนรับ คืนนี้โลกจะหยุดพักไปพร้อมกัน",
};

const prisma = new PrismaClient();

type Staged = {
  entity: TranslatableEntity;
  entityId: string;
  fields: Record<string, string>;
};

/** Collects a record's translated fields, skipping any with no dictionary hit. */
function stage(
  entity: TranslatableEntity,
  entityId: string,
  pairs: Array<[field: string, source: string | null, dictionary: Dictionary]>,
): Staged | null {
  const fields: Record<string, string> = {};
  for (const [field, source, dictionary] of pairs) {
    if (source && dictionary[source]) fields[field] = dictionary[source];
  }
  return Object.keys(fields).length ? { entity, entityId, fields } : null;
}

export async function seedTranslations(): Promise<number> {
  const staged: Staged[] = [];

  for (const row of await prisma.soundCategory.findMany()) {
    const entry = stage("SOUND_CATEGORY", row.id, [["title", row.title, CATEGORY_TITLES]]);
    if (entry) staged.push(entry);
  }

  for (const row of await prisma.soundCollection.findMany()) {
    const entry = stage("SOUND_COLLECTION", row.id, [
      ["title", row.title, COLLECTION_TITLES],
      ["subtitle", row.subtitle, COLLECTION_SUBTITLES],
    ]);
    if (entry) staged.push(entry);
  }

  for (const row of await prisma.plant.findMany()) {
    const entry = stage("PLANT", row.id, [
      ["name", row.name, PLANT_NAMES],
      ["tagline", row.tagline, PLANT_TAGLINES],
    ]);
    if (entry) staged.push(entry);
  }

  for (const row of await prisma.plantStage.findMany()) {
    const entry = stage("PLANT_STAGE", row.id, [["name", row.name, STAGE_NAMES]]);
    if (entry) staged.push(entry);
  }

  for (const row of await prisma.pauseIntentionOption.findMany()) {
    const entry = stage("PAUSE_INTENTION", row.id, [["label", row.label, INTENTION_LABELS]]);
    if (entry) staged.push(entry);
  }

  for (const row of await prisma.pauseWelcomeMessage.findMany()) {
    const entry = stage("PAUSE_WELCOME_MESSAGE", row.id, [
      ["text", row.text, WELCOME_MESSAGES],
    ]);
    if (entry) staged.push(entry);
  }

  for (const entry of staged) {
    await prisma.contentTranslation.upsert({
      where: {
        entity_entityId_languageCode: {
          entity: entry.entity,
          entityId: entry.entityId,
          languageCode: LANGUAGE,
        },
      },
      create: { ...entry, languageCode: LANGUAGE },
      update: { fields: entry.fields },
    });
  }

  return staged.length;
}

const invokedDirectly = process.argv[1]?.endsWith("seedTranslations.ts");
if (invokedDirectly) {
  seedTranslations()
    .then((count) => {
      console.log(`seeded ${count} translated records (${LANGUAGE})`);
    })
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
