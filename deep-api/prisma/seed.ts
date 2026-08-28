// Seeds the DB with the content the iOS app used to hardcode:
//  - Deep Sound: 5 categories -> collections -> tracks (from SoundLibrary.swift)
//  - Onboarding config: 2 quiz questions + 4 plants with growth stages (from the iOS fixtures)
//  - A couple of multi-language lyrics to exercise the lyrics feature
// Idempotent: wipes content tables and re-inserts. Plants/stages are upserted by
// id, not wiped (user progress + selection FK them). Users/sessions are untouched.
import fs from "node:fs";
import path from "node:path";
import { PrismaClient, type TrackKind } from "@prisma/client";
import { readAudioDurationSeconds } from "../src/lib/audioDuration.js";

const prisma = new PrismaClient();

const img = (id: string) => `https://images.unsplash.com/photo-${id}?w=600&q=80`;

// The three real audio files shipped in media/audio/. Every track plays one of
// these, assigned round-robin; durationSeconds mirrors the file's real length.
const REAL_TRACKS = [
  { file: "/media/audio/global-pause.mp3", durationSeconds: 132 },
  { file: "/media/audio/inner-light.mp3", durationSeconds: 120 },
  { file: "/media/audio/ivory.mp3", durationSeconds: 183 },
] as const;

interface SeedTrack {
  title: string;
}
interface SeedCollection {
  title: string;
  subtitle: string;
  palette: string;
  image: string;
  premium?: boolean;
  tracks: SeedTrack[];
}
interface SeedCategory {
  slug: string;
  title: string;
  kind: TrackKind;
  collections: SeedCollection[];
}

const CATEGORIES: SeedCategory[] = [
  {
    slug: "calm",
    title: "Calm",
    kind: "INSTRUMENTAL",
    collections: [
      {
        title: "Northern Calm",
        subtitle: "Wide skies, settled breath",
        palette: "aurora",
        image: img("1483347756197-71ef80e95f73"),
        tracks: [
          { title: "Aurora Drift" },
          { title: "Polar Stillness" },
          { title: "Open Sky" },
          { title: "Far Horizon" },
        ],
      },
      {
        title: "Petal Fall",
        subtitle: "Gentle bloom for an open heart",
        palette: "bloom",
        image: img("1457089328109-e5d9bd499191"),
        tracks: [
          { title: "First Blossom" },
          { title: "Soft Unfolding" },
          { title: "Drifting Petals" },
          { title: "Resting Garden" },
        ],
      },
      {
        title: "Still Forest",
        subtitle: "Green quiet between the trees",
        palette: "mist",
        image: img("1441974231531-c6227db76b6e"),
        tracks: [
          { title: "Under the Canopy" },
          { title: "Moss and Shade" },
          { title: "Leaf Light" },
        ],
      },
      {
        title: "Mountain Air",
        subtitle: "Thin, clear, and endlessly calm",
        palette: "aurora",
        image: img("1469474968028-56623f02e42e"),
        tracks: [
          { title: "High Meadow" },
          { title: "Ridge Line" },
          { title: "Snowmelt" },
          { title: "Summit Stillness" },
        ],
      },
    ],
  },
  {
    slug: "morning",
    title: "Morning",
    kind: "INSTRUMENTAL",
    collections: [
      {
        title: "Morning Mist",
        subtitle: "A soft return to the day",
        palette: "mist",
        image: img("1470071459604-3b5ec3a7fe05"),
        tracks: [
          { title: "First Light" },
          { title: "Dew" },
          { title: "Slow Waking" },
        ],
      },
      {
        title: "First Sun",
        subtitle: "Warmth arriving over the hills",
        palette: "dawn",
        image: img("1470252649378-9c29740c9fa8"),
        tracks: [
          { title: "Horizon Glow" },
          { title: "Waking Fields" },
          { title: "Gold Through Mist" },
        ],
      },
      {
        title: "Golden Fields",
        subtitle: "Slow light across open land",
        palette: "ember",
        image: img("1472214103451-9374bd1c798e"),
        tracks: [
          { title: "Harvest Hush" },
          { title: "Wind in the Wheat" },
          { title: "Late Morning" },
          { title: "Open Path" },
        ],
      },
      {
        title: "Sea at Dawn",
        subtitle: "The coast before anyone wakes",
        palette: "dawn",
        image: img("1475924156734-496f6cac6ec1"),
        tracks: [
          { title: "Pale Tide" },
          { title: "Early Gulls" },
          { title: "Salt and Light" },
        ],
      },
    ],
  },
  {
    slug: "sleep",
    title: "Sleep",
    kind: "INSTRUMENTAL",
    collections: [
      {
        title: "Ocean Depths",
        subtitle: "Slow tides for deep rest",
        palette: "tide",
        image: img("1505144808419-1957a94ca61e"),
        tracks: [
          { title: "Drifting Tide" },
          { title: "Beneath the Surface" },
          { title: "Moonlit Current" },
          { title: "Still Water" },
        ],
      },
      {
        title: "Evening Light",
        subtitle: "Wind down as the day softens",
        palette: "dusk",
        image: img("1500530855697-b586d89ba3ee"),
        tracks: [
          { title: "Last Warmth" },
          { title: "Fading Gold" },
          { title: "Quiet Sky" },
        ],
      },
      {
        title: "Hearthglow",
        subtitle: "Warm tones to feel held",
        palette: "ember",
        image: img("1518495973542-4542c06a5843"),
        tracks: [
          { title: "Low Embers" },
          { title: "Candle Hour" },
          { title: "Held Warmth" },
        ],
      },
      {
        title: "Starfall",
        subtitle: "Night skies to drift beneath",
        palette: "tide",
        image: img("1419242902214-272b3f66ee7a"),
        premium: true,
        tracks: [
          { title: "Falling Slow" },
          { title: "Midnight Meadow" },
          { title: "Deep Dark" },
          { title: "Before Dreams" },
        ],
      },
    ],
  },
  {
    slug: "deep-teacher",
    title: "Deep Teacher",
    kind: "GUIDED",
    collections: [
      {
        title: "Roots of Attention",
        subtitle: "A teacher's voice to steady you",
        palette: "aurora",
        image: img("1447752875215-b2761acb3c5d"),
        tracks: [
          { title: "Arriving" },
          { title: "Softening the Shoulders" },
          { title: "Naming the Breath" },
          { title: "Staying a While" },
        ],
      },
      {
        title: "Letting Go",
        subtitle: "Guided release at day's end",
        palette: "dusk",
        image: img("1476673160081-cf065607f449"),
        tracks: [
          { title: "Setting Down the Day" },
          { title: "Unclenching" },
          { title: "The Long Exhale" },
        ],
      },
      {
        title: "Body & Breath",
        subtitle: "A gentle scan from crown to toes",
        palette: "mist",
        image: img("1502082553048-f009c37129b9"),
        tracks: [
          { title: "Crown and Brow" },
          { title: "Heart Space" },
          { title: "Grounding the Feet" },
        ],
      },
      {
        title: "Evening Reflection",
        subtitle: "Quiet questions before sleep",
        palette: "tide",
        image: img("1519681393784-d120267933ba"),
        premium: true,
        tracks: [
          { title: "What Softened Today" },
          { title: "Gratitude Hour" },
          { title: "Closing the Day" },
        ],
      },
    ],
  },
  {
    slug: "deep-kids",
    title: "Deep Kids",
    kind: "INSTRUMENTAL",
    collections: [
      {
        title: "Sleepy Stars",
        subtitle: "A twinkling lullaby sky",
        palette: "tide",
        image: img("1462331940025-496dfbfc7564"),
        tracks: [
          { title: "Counting Starlight" },
          { title: "The Moon's Blanket" },
          { title: "Goodnight Sky" },
        ],
      },
      {
        title: "Little Shore",
        subtitle: "Tiny waves for tiny toes",
        palette: "dawn",
        image: img("1507525428034-b723cf961d3e"),
        tracks: [
          { title: "The Smallest Wave" },
          { title: "Seashell Whispers" },
          { title: "Sandcastle Dreams" },
        ],
      },
      {
        title: "Flower Friends",
        subtitle: "A garden of gentle hellos",
        palette: "bloom",
        image: img("1465146344425-f00d5f5c8f07"),
        tracks: [
          { title: "Buttercup Waves Hello" },
          { title: "The Bumblebee Parade" },
          { title: "Petal Naps" },
        ],
      },
      {
        title: "Big Blue Wave",
        subtitle: "Ride the friendly ocean home",
        palette: "tide",
        image: img("1518837695005-2083093ee35b"),
        tracks: [
          { title: "Splash and Glide" },
          { title: "The Whale's Hum" },
          { title: "Drifting to Shore" },
        ],
      },
    ],
  },
];

const QUESTIONS = [
  {
    id: "arrival",
    prompt: "What brings you here today?",
    options: [
      { key: "slow-down", title: "To slow down", palette: "tide" },
      { key: "clarity", title: "To find clarity", palette: "mist" },
      { key: "recharge", title: "To recharge", palette: "ember" },
      { key: "exploring", title: "Just exploring", palette: "bloom" },
    ],
  },
  {
    id: "longing",
    prompt: "What do you long for right now?",
    options: [
      { key: "calm", title: "Calm", palette: "tide" },
      { key: "connection", title: "Connection", palette: "dusk" },
      { key: "clarity", title: "Clarity", palette: "mist" },
      { key: "healing", title: "Healing", palette: "bloom" },
    ],
  },
];

interface SeedPlantStage {
  id: string;
  name: string;
  sunlightRequired: number;
  mascotPath?: string;
  mascotBgPath?: string;
  heroVideoPath?: string;
}
interface SeedPlant {
  id: string;
  name: string;
  tagline: string;
  palette: string;
  imageUrl: string;
  stages: SeedPlantStage[];
}

// Real, admin-editable growth stages for oak (cumulative sunlight thresholds
// mirror the iOS fixtures: Seedling/Young/Mature at 0/200/700). The other
// three plants get placeholder stages with null assets and varying stage
// counts, so the picker/detail UIs exercise more than one shape.
const PLANTS: SeedPlant[] = [
  {
    id: "oak",
    name: "Oak",
    tagline: "Steady & Strong",
    palette: "tide",
    imageUrl:
      "https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=800&q=80&fm=jpg&fit=crop",
    stages: [
      {
        id: "oak-stage-0",
        name: "Seedling",
        sunlightRequired: 0,
        mascotPath: "/media/garden/images/oak-seedling.png",
      },
      {
        id: "oak-stage-1",
        name: "Young Oak",
        sunlightRequired: 200,
        mascotPath: "/media/garden/images/oak-young.png",
      },
      {
        id: "oak-stage-2",
        name: "Mature Oak",
        sunlightRequired: 700,
        mascotPath: "/media/garden/images/oak-mature.png",
        heroVideoPath: "/media/garden/videos/oak-mature.mp4",
      },
    ],
  },
  {
    id: "sakura",
    name: "Sakura",
    tagline: "Gentle & Open",
    palette: "bloom",
    imageUrl:
      "https://images.unsplash.com/photo-1522383225653-ed111181a951?w=800&q=80&fm=jpg&fit=crop",
    stages: [
      { id: "sakura-stage-0", name: "Bud", sunlightRequired: 0 },
      { id: "sakura-stage-1", name: "Budding Branch", sunlightRequired: 150 },
      { id: "sakura-stage-2", name: "Blossoming", sunlightRequired: 400 },
      { id: "sakura-stage-3", name: "Full Bloom", sunlightRequired: 900 },
    ],
  },
  {
    id: "lotus",
    name: "Lotus",
    tagline: "Calm & Mindful",
    palette: "mist",
    imageUrl:
      "https://images.unsplash.com/photo-1474557157379-8aa74a6ef541?w=800&q=80&fm=jpg&fit=crop",
    stages: [
      { id: "lotus-stage-0", name: "Seed", sunlightRequired: 0 },
      { id: "lotus-stage-1", name: "Rising Stem", sunlightRequired: 250 },
      { id: "lotus-stage-2", name: "Open Lotus", sunlightRequired: 650 },
    ],
  },
  {
    id: "orange",
    name: "Orange",
    tagline: "Warm & Joyful",
    palette: "ember",
    imageUrl:
      "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Bitter_orange_-_Citrus_%C3%97_aurantium_03.jpg/500px-Bitter_orange_-_Citrus_%C3%97_aurantium_03.jpg",
    stages: [
      { id: "orange-stage-0", name: "Sprout", sunlightRequired: 0 },
      { id: "orange-stage-1", name: "Sapling", sunlightRequired: 300 },
      { id: "orange-stage-2", name: "Fruit-Bearing", sunlightRequired: 800 },
    ],
  },
];

async function main() {
  const mediaAudioDir = path.resolve("media/audio");
  for (const t of REAL_TRACKS) {
    const file = path.join(mediaAudioDir, path.basename(t.file));
    if (!fs.existsSync(file)) {
      throw new Error(`Missing real audio file: ${file} — copy the reference mp3s into media/audio/ first.`);
    }
  }

  // The oak stages below point at real garden assets; everything else is a
  // null-asset placeholder. Fail fast if those weren't copied in yet.
  const gardenImagesDir = path.resolve("media/garden/images");
  const gardenVideosDir = path.resolve("media/garden/videos");
  const OAK_MEDIA_FILES = [
    path.join(gardenImagesDir, "oak-seedling.png"),
    path.join(gardenImagesDir, "oak-young.png"),
    path.join(gardenImagesDir, "oak-mature.png"),
    path.join(gardenVideosDir, "oak-mature.mp4"),
  ];
  for (const file of OAK_MEDIA_FILES) {
    if (!fs.existsSync(file)) {
      throw new Error(
        `Missing garden asset: ${file} — run \`npm run seed:assets\` to copy the oak Mind Garden assets into media/garden/ first.`,
      );
    }
  }

  // Wipe content (cascades to collections/tracks/lyrics + options).
  await prisma.trackLyrics.deleteMany();
  await prisma.soundTrack.deleteMany();
  await prisma.soundCollection.deleteMany();
  await prisma.soundCategory.deleteMany();
  await prisma.quizOption.deleteMany();
  await prisma.quizQuestion.deleteMany();
  // Plants are upserted, not wiped: user progress FKs (Restrict) and selected
  // plants point at these rows.
  await prisma.pauseWelcomeMessage.deleteMany();
  await prisma.pauseIntentionOption.deleteMany();
  await prisma.peaceMessage.deleteMany();

  // Onboarding config
  for (const [qi, q] of QUESTIONS.entries()) {
    await prisma.quizQuestion.create({
      data: {
        id: q.id,
        prompt: q.prompt,
        displayOrder: qi,
        options: {
          create: q.options.map((o, oi) => ({
            key: o.key,
            title: o.title,
            palette: o.palette,
            displayOrder: oi,
          })),
        },
      },
    });
  }
  for (const [i, p] of PLANTS.entries()) {
    const { stages, ...plantFields } = p;
    const data = { ...plantFields, displayOrder: i, isDefault: true, isActive: true };
    await prisma.plant.upsert({ where: { id: p.id }, update: data, create: data });

    const seededStageIds: string[] = [];
    for (const [si, s] of stages.entries()) {
      const stageData = {
        plantId: p.id,
        name: s.name,
        displayOrder: si,
        sunlightRequired: s.sunlightRequired,
        mascotPath: s.mascotPath ?? null,
        mascotBgPath: s.mascotBgPath ?? null,
        heroVideoPath: s.heroVideoPath ?? null,
      };
      await prisma.plantStage.upsert({
        where: { id: s.id },
        update: stageData,
        create: { id: s.id, ...stageData },
      });
      seededStageIds.push(s.id);
    }
    // Drop stray stages from a previous seed shape (e.g. a shrunk stage
    // count) without touching other plants' stages.
    await prisma.plantStage.deleteMany({
      where: { plantId: p.id, id: { notIn: seededStageIds } },
    });
  }

  // Deep Sound
  let firstGuidedTrackId: string | null = null;
  let audioCursor = 0;
  for (const [ci, cat] of CATEGORIES.entries()) {
    const category = await prisma.soundCategory.create({
      data: { slug: cat.slug, title: cat.title, displayOrder: ci },
    });
    for (const [coi, col] of cat.collections.entries()) {
      const collection = await prisma.soundCollection.create({
        data: {
          categoryId: category.id,
          title: col.title,
          subtitle: col.subtitle,
          palette: col.palette,
          imageUrl: col.image,
          isPremium: col.premium ?? false,
          displayOrder: coi,
        },
      });
      for (const [ti, tr] of col.tracks.entries()) {
        const real = REAL_TRACKS[audioCursor++ % REAL_TRACKS.length];
        const track = await prisma.soundTrack.create({
          data: {
            collectionId: collection.id,
            title: tr.title,
            durationSeconds: real.durationSeconds,
            kind: cat.kind,
            audioPath: real.file,
            isPremium: col.premium ?? false,
            displayOrder: ti,
          },
        });
        if (cat.kind === "GUIDED" && !firstGuidedTrackId) {
          firstGuidedTrackId = track.id;
        }
      }
    }
  }

  // Multi-language lyrics on the first guided track, to exercise the feature.
  if (firstGuidedTrackId) {
    await prisma.trackLyrics.createMany({
      data: [
        {
          trackId: firstGuidedTrackId,
          languageCode: "en",
          content:
            "Take a moment.\nLet the breath arrive on its own.\nYou don't have to reach for it.\nYou're here now.",
        },
        {
          trackId: firstGuidedTrackId,
          languageCode: "th",
          content:
            "หยุดสักครู่\nปล่อยให้ลมหายใจมาถึงเอง\nไม่ต้องพยายามไขว่คว้า\nคุณอยู่ตรงนี้แล้ว",
        },
      ],
    });
  }

  // Global Pause: singleton config, welcome copy, intentions (mirroring the
  // iOS Intention.samples), and a night's worth of sample peace messages so
  // the off-hours lobby feed isn't empty on first run.
  //
  // The duration is measured, never typed: it is how long the meditation phase
  // runs, and a literal here would quietly stamp the seeded track's length over
  // whatever an admin has since uploaded on any re-seed.
  const meditationAudioPath = "/media/audio/global-pause.mp3";
  const measured = await readAudioDurationSeconds(meditationAudioPath);
  if (measured == null) {
    throw new Error(`Couldn't read the length of ${meditationAudioPath} — is media/audio/ present?`);
  }
  const pauseConfig = {
    meditationAudioPath,
    meditationDurationSeconds: measured,
  };
  await prisma.pauseConfig.upsert({
    where: { id: 1 },
    update: pauseConfig,
    create: { id: 1, ...pauseConfig },
  });

  const WELCOME_MESSAGES = [
    "Welcome. Tonight the world pauses together.",
    "Wherever you are, you are not alone.",
    "Settle in. We begin in a moment.",
  ];
  for (const [i, text] of WELCOME_MESSAGES.entries()) {
    await prisma.pauseWelcomeMessage.create({ data: { text, displayOrder: i } });
  }

  const INTENTIONS = [
    { key: "peace", label: "Peace" },
    { key: "healing", label: "Healing" },
    { key: "gratitude", label: "Gratitude" },
    { key: "someone-i-love", label: "Someone I love" },
    { key: "other", label: "Other" },
  ];
  for (const [i, intent] of INTENTIONS.entries()) {
    await prisma.pauseIntentionOption.create({ data: { ...intent, displayOrder: i } });
  }

  // Seven nights of peace messages, newest night first — enough volume to
  // exercise the feed's keyset pagination end to end.
  const PEACE_MESSAGES: {
    displayName: string;
    countryISO: string;
    text: string;
    intention?: string;
  }[] = [
    { displayName: "Nan", countryISO: "TH", text: "Peace for every quiet heart tonight.", intention: "peace" },
    { displayName: "Haruki", countryISO: "JP", text: "Breathing with you all from Kyoto.", intention: "peace" },
    { displayName: "Camille", countryISO: "FR", text: "Ce soir, le monde respire ensemble.", intention: "peace" },
    { displayName: "Luana", countryISO: "BR", text: "Sending warmth from São Paulo.", intention: "someone-i-love" },
    { displayName: "Amara", countryISO: "KE", text: "May stillness find whoever needs it.", intention: "peace" },
    { displayName: "Noah", countryISO: "US", text: "Grateful for this minute of quiet.", intention: "gratitude" },
    { displayName: "Mira", countryISO: "IN", text: "Shanti. Shanti. Shanti.", intention: "peace" },
    { displayName: "Elin", countryISO: "SE", text: "The lake is still here too. Goodnight." },
    { displayName: "Tomás", countryISO: "AR", text: "Un abrazo enorme desde Buenos Aires.", intention: "someone-i-love" },
    { displayName: "Yuki", countryISO: "JP", text: "May tomorrow be gentler than today.", intention: "healing" },
    { displayName: "Priya", countryISO: "IN", text: "For my mother, and for yours too.", intention: "someone-i-love" },
    { displayName: "Sam", countryISO: "AU", text: "The ocean says hello. Rest easy, world." },
    { displayName: "Ingrid", countryISO: "NO", text: "Northern lights above, calm hearts below.", intention: "peace" },
    { displayName: "Kofi", countryISO: "GH", text: "One breath, one world, one family.", intention: "peace" },
    { displayName: "Léa", countryISO: "CA", text: "Snow is falling softly here. Peace to all.", intention: "peace" },
    { displayName: "Marco", countryISO: "IT", text: "Buonanotte dal cuore di Roma.", intention: "gratitude" },
    { displayName: "Aisha", countryISO: "EG", text: "Salam from the banks of the Nile.", intention: "peace" },
    { displayName: "Chen", countryISO: "SG", text: "Wishing every stranger a soft landing tonight.", intention: "healing" },
    { displayName: "Rosa", countryISO: "MX", text: "Paz para los que siguen despiertos.", intention: "peace" },
    { displayName: "Finn", countryISO: "IE", text: "The rain here is kind tonight. So am I." },
    { displayName: "Anya", countryISO: "PL", text: "Sending quiet strength to whoever needs it.", intention: "healing" },
    { displayName: "Jae", countryISO: "KR", text: "From Seoul with a full, calm heart.", intention: "gratitude" },
    { displayName: "Zara", countryISO: "PK", text: "May your worries grow lighter with each breath.", intention: "healing" },
    { displayName: "Lucas", countryISO: "PT", text: "The Atlantic is calm tonight. Be like the Atlantic.", intention: "other" },
    { displayName: "Maya", countryISO: "ID", text: "Selamat malam. You did enough today.", intention: "gratitude" },
    { displayName: "Oliver", countryISO: "GB", text: "A quiet cup of tea for every tired soul.", intention: "healing" },
    { displayName: "Sofia", countryISO: "ES", text: "Que descanses, mundo. Te lo mereces.", intention: "peace" },
    { displayName: "Nadia", countryISO: "MA", text: "Peace from the medina, under the same moon.", intention: "peace" },
    { displayName: "Theo", countryISO: "DE", text: "Alles wird gut. Breathe with me.", intention: "healing" },
    { displayName: "Lin", countryISO: "TW", text: "For everyone far from home tonight.", intention: "someone-i-love" },
    { displayName: "Ava", countryISO: "NZ", text: "First light touches us first. Passing it on." },
    { displayName: "Omar", countryISO: "JO", text: "May kindness find you before sleep does.", intention: "peace" },
    { displayName: "Nok", countryISO: "TH", text: "จากกรุงเทพฯ ด้วยรัก และความสงบ", intention: "peace" },
    { displayName: "Elias", countryISO: "FI", text: "The forest is silent. The heart can be too.", intention: "other" },
    { displayName: "Grace", countryISO: "PH", text: "Ingat kayo lagi. Peace to every home.", intention: "someone-i-love" },
    { displayName: "Mateus", countryISO: "BR", text: "Que a paz encontre você esta noite.", intention: "peace" },
    { displayName: "Hana", countryISO: "CZ", text: "Prague's bells just rang. Peace rang with them.", intention: "gratitude" },
    { displayName: "Ali", countryISO: "TR", text: "Two shores, one city, one wish: peace.", intention: "peace" },
    { displayName: "June", countryISO: "US", text: "Proud of everyone who made it through today.", intention: "gratitude" },
    { displayName: "Sanne", countryISO: "NL", text: "The canals are still. Let your mind be too." },
    { displayName: "Kwame", countryISO: "NG", text: "Blessings and calm from Lagos tonight.", intention: "peace" },
    { displayName: "Isla", countryISO: "GB", text: "For the ones working the night shift. Thank you.", intention: "gratitude" },
    { displayName: "Ren", countryISO: "JP", text: "静かな夜を、世界中のあなたへ。", intention: "peace" },
    { displayName: "Vera", countryISO: "UA", text: "Peace is not small. It starts small. Goodnight.", intention: "peace" },
    { displayName: "Diego", countryISO: "CL", text: "The Andes hold the sky. Something holds you too.", intention: "other" },
    { displayName: "Amelie", countryISO: "CH", text: "Mountain air and easy hearts to everyone.", intention: "healing" },
    { displayName: "Tariq", countryISO: "AE", text: "The desert cools at night. So can we." },
    { displayName: "Freya", countryISO: "DK", text: "Hygge and healing, wherever you are.", intention: "healing" },
    { displayName: "Ben", countryISO: "IL", text: "Shalom. Truly, simply, shalom.", intention: "peace" },
    { displayName: "Mai", countryISO: "VN", text: "Chúc cả thế giới ngủ ngon.", intention: "peace" },
    { displayName: "Stefan", countryISO: "RO", text: "May the quiet hours repair what the loud ones broke.", intention: "healing" },
    { displayName: "Lotte", countryISO: "BE", text: "A little light left on for whoever needs it.", intention: "someone-i-love" },
    { displayName: "Aroha", countryISO: "NZ", text: "Kia kaha. Stay strong, stay soft.", intention: "healing" },
    { displayName: "Igor", countryISO: "RS", text: "One minute of peace is still peace.", intention: "peace" },
    { displayName: "Celine", countryISO: "FR", text: "Paris respire doucement ce soir.", intention: "peace" },
    { displayName: "Dara", countryISO: "KH", text: "From Phnom Penh: may your dreams be gentle.", intention: "someone-i-love" },
    { displayName: "Nina", countryISO: "AT", text: "The mountains don't hurry. Neither should you.", intention: "other" },
    { displayName: "Yusuf", countryISO: "ID", text: "Damai untuk semua, dari Jakarta.", intention: "peace" },
    { displayName: "Clara", countryISO: "CO", text: "Paz y café para mañana. Buenas noches.", intention: "gratitude" },
    { displayName: "Emeka", countryISO: "NG", text: "We breathe together, we rise together.", intention: "peace" },
  ];

  // Spread across the last seven nights, newest first. createdAt is staggered
  // explicitly inside each night's 21:00–21:30 Bangkok window (batch inserts
  // would otherwise share one timestamp); the newest night's first two rows
  // deliberately share an instant so the feed's (createdAt, id) cursor is
  // exercised on the ambiguous case.
  const NIGHTLY_COUNTS = [10, 9, 9, 8, 8, 8, 8];
  const bangkokDay = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  let nextMessage = 0;
  for (const [night, count] of NIGHTLY_COUNTS.entries()) {
    const pauseDate = bangkokDay.format(new Date(Date.now() - (night + 1) * 24 * 60 * 60 * 1000));
    // Bangkok is fixed UTC+7, so 21:00 local is 14:00 UTC on the same date.
    const nightStart = new Date(`${pauseDate}T14:00:00.000Z`);
    for (let i = 0; i < count; i += 1) {
      const message = PEACE_MESSAGES[nextMessage]!;
      const offsetSeconds = night === 0 && i === 1 ? 0 : i * 100;
      await prisma.peaceMessage.create({
        data: {
          ...message,
          pauseDate,
          createdAt: new Date(nightStart.getTime() + offsetSeconds * 1000),
        },
      });
      nextMessage += 1;
    }
  }

  const counts = {
    categories: await prisma.soundCategory.count(),
    collections: await prisma.soundCollection.count(),
    tracks: await prisma.soundTrack.count(),
    questions: await prisma.quizQuestion.count(),
    plants: await prisma.plant.count(),
    plantStages: await prisma.plantStage.count(),
    welcomeMessages: await prisma.pauseWelcomeMessage.count(),
    intentions: await prisma.pauseIntentionOption.count(),
    peaceMessages: await prisma.peaceMessage.count(),
  };
  console.log("Seed complete:", counts);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
