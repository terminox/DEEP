// Seeds the DB with the content the iOS app used to hardcode:
//  - Deep Sound: 5 categories -> collections -> tracks (from SoundLibrary.swift)
//  - Onboarding config: 2 quiz questions + 4 mind trees (from the iOS fixtures)
//  - A couple of multi-language lyrics to exercise the lyrics feature
// Idempotent: wipes content tables and re-inserts. Users/sessions are untouched.
import { PrismaClient, type TrackKind } from "@prisma/client";

const prisma = new PrismaClient();

const img = (id: string) => `https://images.unsplash.com/photo-${id}?w=600&q=80`;
const m = (min: number, sec: number) => min * 60 + sec;

interface SeedTrack {
  title: string;
  duration: number;
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
  audio: string; // relative media path shared by the category's tracks
  collections: SeedCollection[];
}

const CATEGORIES: SeedCategory[] = [
  {
    slug: "calm",
    title: "Calm",
    kind: "INSTRUMENTAL",
    audio: "/media/audio/calm.mp3",
    collections: [
      {
        title: "Northern Calm",
        subtitle: "Wide skies, settled breath",
        palette: "aurora",
        image: img("1483347756197-71ef80e95f73"),
        tracks: [
          { title: "Aurora Drift", duration: m(9, 16) },
          { title: "Polar Stillness", duration: m(7, 48) },
          { title: "Open Sky", duration: m(6, 30) },
          { title: "Far Horizon", duration: m(8, 2) },
        ],
      },
      {
        title: "Petal Fall",
        subtitle: "Gentle bloom for an open heart",
        palette: "bloom",
        image: img("1457089328109-e5d9bd499191"),
        tracks: [
          { title: "First Blossom", duration: m(5, 50) },
          { title: "Soft Unfolding", duration: m(7, 14) },
          { title: "Drifting Petals", duration: m(6, 22) },
          { title: "Resting Garden", duration: m(9, 40) },
        ],
      },
      {
        title: "Still Forest",
        subtitle: "Green quiet between the trees",
        palette: "mist",
        image: img("1441974231531-c6227db76b6e"),
        tracks: [
          { title: "Under the Canopy", duration: m(7, 26) },
          { title: "Moss and Shade", duration: m(6, 54) },
          { title: "Leaf Light", duration: m(8, 12) },
        ],
      },
      {
        title: "Mountain Air",
        subtitle: "Thin, clear, and endlessly calm",
        palette: "aurora",
        image: img("1469474968028-56623f02e42e"),
        tracks: [
          { title: "High Meadow", duration: m(6, 8) },
          { title: "Ridge Line", duration: m(7, 34) },
          { title: "Snowmelt", duration: m(5, 46) },
          { title: "Summit Stillness", duration: m(8, 50) },
        ],
      },
    ],
  },
  {
    slug: "morning",
    title: "Morning",
    kind: "INSTRUMENTAL",
    audio: "/media/audio/morning.mp3",
    collections: [
      {
        title: "Morning Mist",
        subtitle: "A soft return to the day",
        palette: "mist",
        image: img("1470071459604-3b5ec3a7fe05"),
        tracks: [
          { title: "First Light", duration: m(5, 12) },
          { title: "Dew", duration: m(6, 58) },
          { title: "Slow Waking", duration: m(8, 24) },
        ],
      },
      {
        title: "First Sun",
        subtitle: "Warmth arriving over the hills",
        palette: "dawn",
        image: img("1470252649378-9c29740c9fa8"),
        tracks: [
          { title: "Horizon Glow", duration: m(6, 18) },
          { title: "Waking Fields", duration: m(7, 42) },
          { title: "Gold Through Mist", duration: m(5, 36) },
        ],
      },
      {
        title: "Golden Fields",
        subtitle: "Slow light across open land",
        palette: "ember",
        image: img("1472214103451-9374bd1c798e"),
        tracks: [
          { title: "Harvest Hush", duration: m(7, 8) },
          { title: "Wind in the Wheat", duration: m(6, 46) },
          { title: "Late Morning", duration: m(8, 20) },
          { title: "Open Path", duration: m(5, 58) },
        ],
      },
      {
        title: "Sea at Dawn",
        subtitle: "The coast before anyone wakes",
        palette: "dawn",
        image: img("1475924156734-496f6cac6ec1"),
        tracks: [
          { title: "Pale Tide", duration: m(6, 32) },
          { title: "Early Gulls", duration: m(5, 44) },
          { title: "Salt and Light", duration: m(7, 56) },
        ],
      },
    ],
  },
  {
    slug: "sleep",
    title: "Sleep",
    kind: "INSTRUMENTAL",
    audio: "/media/audio/sleep.mp3",
    collections: [
      {
        title: "Ocean Depths",
        subtitle: "Slow tides for deep rest",
        palette: "tide",
        image: img("1505144808419-1957a94ca61e"),
        tracks: [
          { title: "Drifting Tide", duration: m(6, 12) },
          { title: "Beneath the Surface", duration: m(8, 40) },
          { title: "Moonlit Current", duration: m(5, 28) },
          { title: "Still Water", duration: m(9, 4) },
        ],
      },
      {
        title: "Evening Light",
        subtitle: "Wind down as the day softens",
        palette: "dusk",
        image: img("1500530855697-b586d89ba3ee"),
        tracks: [
          { title: "Last Warmth", duration: m(7, 2) },
          { title: "Fading Gold", duration: m(6, 36) },
          { title: "Quiet Sky", duration: m(8, 18) },
        ],
      },
      {
        title: "Hearthglow",
        subtitle: "Warm tones to feel held",
        palette: "ember",
        image: img("1518495973542-4542c06a5843"),
        tracks: [
          { title: "Low Embers", duration: m(8, 6) },
          { title: "Candle Hour", duration: m(6, 44) },
          { title: "Held Warmth", duration: m(7, 30) },
        ],
      },
      {
        title: "Starfall",
        subtitle: "Night skies to drift beneath",
        palette: "tide",
        image: img("1419242902214-272b3f66ee7a"),
        premium: true,
        tracks: [
          { title: "Falling Slow", duration: m(8, 34) },
          { title: "Midnight Meadow", duration: m(7, 12) },
          { title: "Deep Dark", duration: m(9, 48) },
          { title: "Before Dreams", duration: m(6, 26) },
        ],
      },
    ],
  },
  {
    slug: "deep-teacher",
    title: "Deep Teacher",
    kind: "GUIDED",
    audio: "/media/audio/teacher.mp3",
    collections: [
      {
        title: "Roots of Attention",
        subtitle: "A teacher's voice to steady you",
        palette: "aurora",
        image: img("1447752875215-b2761acb3c5d"),
        tracks: [
          { title: "Arriving", duration: m(5, 20) },
          { title: "Softening the Shoulders", duration: m(6, 48) },
          { title: "Naming the Breath", duration: m(7, 16) },
          { title: "Staying a While", duration: m(8, 4) },
        ],
      },
      {
        title: "Letting Go",
        subtitle: "Guided release at day's end",
        palette: "dusk",
        image: img("1476673160081-cf065607f449"),
        tracks: [
          { title: "Setting Down the Day", duration: m(6, 30) },
          { title: "Unclenching", duration: m(5, 52) },
          { title: "The Long Exhale", duration: m(7, 38) },
        ],
      },
      {
        title: "Body & Breath",
        subtitle: "A gentle scan from crown to toes",
        palette: "mist",
        image: img("1502082553048-f009c37129b9"),
        tracks: [
          { title: "Crown and Brow", duration: m(6, 14) },
          { title: "Heart Space", duration: m(7, 26) },
          { title: "Grounding the Feet", duration: m(5, 40) },
        ],
      },
      {
        title: "Evening Reflection",
        subtitle: "Quiet questions before sleep",
        palette: "tide",
        image: img("1519681393784-d120267933ba"),
        premium: true,
        tracks: [
          { title: "What Softened Today", duration: m(6, 2) },
          { title: "Gratitude Hour", duration: m(7, 44) },
          { title: "Closing the Day", duration: m(8, 28) },
        ],
      },
    ],
  },
  {
    slug: "deep-kids",
    title: "Deep Kids",
    kind: "INSTRUMENTAL",
    audio: "/media/audio/kids.mp3",
    collections: [
      {
        title: "Sleepy Stars",
        subtitle: "A twinkling lullaby sky",
        palette: "tide",
        image: img("1462331940025-496dfbfc7564"),
        tracks: [
          { title: "Counting Starlight", duration: m(4, 36) },
          { title: "The Moon's Blanket", duration: m(5, 22) },
          { title: "Goodnight Sky", duration: m(6, 10) },
        ],
      },
      {
        title: "Little Shore",
        subtitle: "Tiny waves for tiny toes",
        palette: "dawn",
        image: img("1507525428034-b723cf961d3e"),
        tracks: [
          { title: "The Smallest Wave", duration: m(5, 8) },
          { title: "Seashell Whispers", duration: m(4, 54) },
          { title: "Sandcastle Dreams", duration: m(6, 32) },
        ],
      },
      {
        title: "Flower Friends",
        subtitle: "A garden of gentle hellos",
        palette: "bloom",
        image: img("1465146344425-f00d5f5c8f07"),
        tracks: [
          { title: "Buttercup Waves Hello", duration: m(4, 42) },
          { title: "The Bumblebee Parade", duration: m(5, 16) },
          { title: "Petal Naps", duration: m(6, 4) },
        ],
      },
      {
        title: "Big Blue Wave",
        subtitle: "Ride the friendly ocean home",
        palette: "tide",
        image: img("1518837695005-2083093ee35b"),
        tracks: [
          { title: "Splash and Glide", duration: m(5, 30) },
          { title: "The Whale's Hum", duration: m(6, 46) },
          { title: "Drifting to Shore", duration: m(4, 58) },
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
  // Wipe content (cascades to collections/tracks/lyrics + options).
  await prisma.trackLyrics.deleteMany();
  await prisma.soundTrack.deleteMany();
  await prisma.soundCollection.deleteMany();
  await prisma.soundCategory.deleteMany();
  await prisma.quizOption.deleteMany();
  await prisma.quizQuestion.deleteMany();
  await prisma.mindTree.deleteMany();
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
  for (const [i, t] of MIND_TREES.entries()) {
    await prisma.mindTree.create({ data: { ...t, displayOrder: i } });
  }

  // Deep Sound
  let firstGuidedTrackId: string | null = null;
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
        const track = await prisma.soundTrack.create({
          data: {
            collectionId: collection.id,
            title: tr.title,
            durationSeconds: tr.duration,
            kind: cat.kind,
            audioPath: cat.audio,
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
  await prisma.pauseConfig.upsert({ where: { id: 1 }, update: {}, create: { id: 1 } });

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

  const lastNight = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(Date.now() - 24 * 60 * 60 * 1000));
  const PEACE_MESSAGES: { displayName: string; countryISO: string; text: string }[] = [
    { displayName: "Nan", countryISO: "TH", text: "Peace for every quiet heart tonight." },
    { displayName: "Haruki", countryISO: "JP", text: "Breathing with you all from Kyoto." },
    { displayName: "Camille", countryISO: "FR", text: "Ce soir, le monde respire ensemble." },
    { displayName: "Luana", countryISO: "BR", text: "Sending warmth from São Paulo." },
    { displayName: "Amara", countryISO: "KE", text: "May stillness find whoever needs it." },
    { displayName: "Noah", countryISO: "US", text: "Grateful for this minute of quiet." },
    { displayName: "Mira", countryISO: "IN", text: "Shanti. Shanti. Shanti." },
    { displayName: "Elin", countryISO: "SE", text: "The lake is still here too. Goodnight." },
  ];
  for (const message of PEACE_MESSAGES) {
    await prisma.peaceMessage.create({ data: { ...message, pauseDate: lastNight } });
  }

  const counts = {
    categories: await prisma.soundCategory.count(),
    collections: await prisma.soundCollection.count(),
    tracks: await prisma.soundTrack.count(),
    questions: await prisma.quizQuestion.count(),
    mindTrees: await prisma.mindTree.count(),
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
