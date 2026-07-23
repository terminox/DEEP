// Seeds the DB with the content the iOS app used to hardcode:
//  - Deep Sound: 5 categories -> collections -> tracks (from SoundLibrary.swift)
//  - Onboarding config: 2 quiz questions + 4 mind trees (from the iOS fixtures)
//  - A couple of multi-language lyrics to exercise the lyrics feature
// Idempotent: wipes content tables and re-inserts. Users/sessions are untouched.
import fs from "node:fs";
import path from "node:path";
import { PrismaClient, type TrackKind } from "@prisma/client";

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

const MIND_TREES = [
  {
    id: "oak",
    name: "Oak",
    tagline: "Steady & Strong",
    palette: "tide",
    imageUrl:
      "https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=800&q=80&fm=jpg&fit=crop",
  },
  {
    id: "sakura",
    name: "Sakura",
    tagline: "Gentle & Open",
    palette: "bloom",
    imageUrl:
      "https://images.unsplash.com/photo-1522383225653-ed111181a951?w=800&q=80&fm=jpg&fit=crop",
  },
  {
    id: "lotus",
    name: "Lotus",
    tagline: "Calm & Mindful",
    palette: "mist",
    imageUrl:
      "https://images.unsplash.com/photo-1474557157379-8aa74a6ef541?w=800&q=80&fm=jpg&fit=crop",
  },
  {
    id: "orange",
    name: "Orange",
    tagline: "Warm & Joyful",
    palette: "ember",
    imageUrl:
      "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Bitter_orange_-_Citrus_%C3%97_aurantium_03.jpg/500px-Bitter_orange_-_Citrus_%C3%97_aurantium_03.jpg",
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

  // Wipe content (cascades to collections/tracks/lyrics + options).
  await prisma.trackLyrics.deleteMany();
  await prisma.soundTrack.deleteMany();
  await prisma.soundCollection.deleteMany();
  await prisma.soundCategory.deleteMany();
  await prisma.quizOption.deleteMany();
  await prisma.quizQuestion.deleteMany();
  await prisma.mindTree.deleteMany();

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
  for (const [i, t] of MIND_TREES.entries()) {
    await prisma.mindTree.create({ data: { ...t, displayOrder: i } });
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

  const counts = {
    categories: await prisma.soundCategory.count(),
    collections: await prisma.soundCollection.count(),
    tracks: await prisma.soundTrack.count(),
    questions: await prisma.quizQuestion.count(),
    mindTrees: await prisma.mindTree.count(),
  };
  console.log("Seed complete:", counts);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
