import type { FastifyInstance } from "fastify";
import type { SoundCategory, SoundCollection, SoundTrack } from "@prisma/client";
import { prisma } from "../prisma.js";
import { optionalAuth } from "../auth/middleware.js";
import { serializeCategory, serializeCollection } from "../lib/serialize.js";

type LoadedTrack = SoundTrack & { lyrics: { languageCode: string }[] };
type LoadedCollection = SoundCollection & { tracks: LoadedTrack[] };
type LoadedCategory = SoundCategory & { collections: LoadedCollection[] };

// Onboarding answers → category affinity, keyed by "questionId:optionKey".
// Kept as data so the heuristic reads at a glance. These keys must track the
// seeded quiz slugs (prisma/seed.ts); an unknown answer simply scores nothing.
// "arrival:exploring" carries no category bias on purpose — palette affinity
// still applies.
const ANSWER_CATEGORY_WEIGHTS: Record<string, Record<string, number>> = {
  "arrival:slow-down": { sleep: 3, calm: 2 },
  "arrival:clarity": { morning: 3, calm: 1 },
  "arrival:recharge": { morning: 3 },
  "longing:calm": { calm: 3, sleep: 1 },
  "longing:connection": { "deep-teacher": 3 },
  "longing:clarity": { morning: 2, "deep-teacher": 1 },
  "longing:healing": { "deep-teacher": 3, calm: 1 },
};

// Deterministic daily rotation: n items starting at seed % pool.length.
function rotate<T>(pool: T[], seed: number, n: number): T[] {
  if (pool.length === 0) return [];
  const out: T[] = [];
  for (let i = 0; i < Math.min(n, pool.length); i += 1) {
    out.push(pool[(seed + i) % pool.length]!);
  }
  return out;
}

export async function pauseRoutes(app: FastifyInstance) {
  // The Global Pause home in one call: server-composed sections plus the full
  // category tree for the Explore grid. Sections carry complete collections
  // (with tracks), so the app needs no follow-up fetch to open or play them.
  // Anonymous requests get deterministic fallbacks; a signed-in user with an
  // onboarding profile gets a personalized "Made for you".
  app.get("/pause/home", { preHandler: optionalAuth }, async (req) => {
    const categories: LoadedCategory[] = await prisma.soundCategory.findMany({
      orderBy: { displayOrder: "asc" },
      include: {
        collections: {
          orderBy: { displayOrder: "asc" },
          include: {
            tracks: {
              orderBy: { displayOrder: "asc" },
              include: { lyrics: { select: { languageCode: true } } },
            },
          },
        },
      },
    });

    const allCollections = categories.flatMap((c) => c.collections);
    const categoryBy = new Map(categories.map((c) => [c.id, c]));

    // "Popular now" — no play counts exist yet, so lead with each category's
    // first collection: the editorial lead. Swap for real popularity once
    // playback stats land.
    const popular = categories
      .map((c) => c.collections[0])
      .filter((c): c is LoadedCollection => Boolean(c));
    const popularIds = new Set(popular.map((c) => c.id));

    // "Today's sessions" — rotates daily (UTC day index), biased toward guided
    // content: 2 guided + 2 instrumental picks. Filtered pools avoid repeating
    // "Popular now"; if a pool runs dry we fall back to the unfiltered one
    // rather than serving an empty shelf.
    const dayKey = Math.floor(Date.now() / 86_400_000);
    const isGuided = (c: LoadedCollection) =>
      c.tracks.some((t) => t.kind === "GUIDED");
    const guided = allCollections.filter(isGuided);
    const instrumental = allCollections.filter((c) => !isGuided(c));
    const guidedPool = guided.filter((c) => !popularIds.has(c.id));
    const guidedPicks = rotate(guidedPool.length ? guidedPool : guided, dayKey, 2);
    const guidedPickIds = new Set(guidedPicks.map((c) => c.id));
    const instrumentalPool = instrumental.filter(
      (c) => !popularIds.has(c.id) && !guidedPickIds.has(c.id),
    );
    const instrumentalPicks = rotate(
      instrumentalPool.length ? instrumentalPool : instrumental,
      dayKey,
      2,
    );
    const today = [...guidedPicks, ...instrumentalPicks];

    // "Made for you" — onboarding-biased when a profile exists, otherwise each
    // category's second collection (disjoint from "Popular now" by construction).
    const usedIds = new Set([...popularIds, ...today.map((c) => c.id)]);
    const profile = req.auth
      ? await prisma.onboardingProfile.findUnique({
          where: { userId: req.auth.sub },
        })
      : null;
    const answers = (profile?.quizAnswers ?? {}) as Record<string, string>;
    const personalized = Boolean(
      profile && (Object.keys(answers).length > 0 || profile.mindTree),
    );

    let forYou: LoadedCollection[];
    if (personalized && profile) {
      const [tree, options] = await Promise.all([
        profile.mindTree
          ? prisma.mindTree.findUnique({ where: { id: profile.mindTree } })
          : Promise.resolve(null),
        prisma.quizOption.findMany(),
      ]);
      const answerPalettes = Object.entries(answers).flatMap(
        ([questionId, key]) => {
          const option = options.find(
            (o) => o.questionId === questionId && o.key === key,
          );
          return option ? [option.palette] : [];
        },
      );

      const score = (collection: LoadedCollection): number => {
        let s = 0;
        const slug = categoryBy.get(collection.categoryId)?.slug;
        for (const [questionId, key] of Object.entries(answers)) {
          const weights = ANSWER_CATEGORY_WEIGHTS[`${questionId}:${key}`];
          if (weights && slug) s += weights[slug] ?? 0;
        }
        if (tree && collection.palette === tree.palette) s += 2;
        for (const palette of answerPalettes) {
          if (palette === collection.palette) s += 1;
        }
        // Soft dedup against the other shelves, not a hard ban.
        if (usedIds.has(collection.id)) s -= 2;
        return s;
      };

      const scored = new Map(allCollections.map((c) => [c.id, score(c)]));
      forYou = allCollections
        .slice()
        .sort((a, b) => {
          const byScore = scored.get(b.id)! - scored.get(a.id)!;
          if (byScore !== 0) return byScore;
          const byCategory =
            (categoryBy.get(a.categoryId)?.displayOrder ?? 0) -
            (categoryBy.get(b.categoryId)?.displayOrder ?? 0);
          if (byCategory !== 0) return byCategory;
          return a.displayOrder - b.displayOrder;
        })
        .slice(0, 6);
    } else {
      forYou = categories
        .map((c) => c.collections[1])
        .filter((c): c is LoadedCollection => Boolean(c));
    }

    return {
      sections: [
        {
          key: "popular",
          title: "Popular now",
          personalized: false,
          collections: popular.map(serializeCollection),
        },
        {
          key: "today",
          title: "Today's sessions",
          personalized: false,
          collections: today.map(serializeCollection),
        },
        {
          key: "forYou",
          title: "Made for you",
          personalized,
          collections: forYou.map(serializeCollection),
        },
      ],
      categories: categories.map(serializeCategory),
    };
  });
}
