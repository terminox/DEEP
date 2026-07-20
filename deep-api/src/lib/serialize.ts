// Central place that turns Prisma rows into the JSON shapes clients receive.
// Keeping these here means the iOS DTOs and the admin types have one contract
// to track. Media paths are projected to absolute URLs.
import type {
  User,
  SoundCategory,
  SoundCollection,
  SoundTrack,
  TrackLyrics,
  QuizQuestion,
  QuizOption,
  MindTree,
} from "@prisma/client";
import { mediaUrl } from "./media.js";

export function serializeUser(u: User) {
  return {
    id: u.id,
    email: u.email,
    displayName: u.displayName,
    role: u.role,
    createdAt: u.createdAt.toISOString(),
  };
}

export function serializeTrack(
  t: SoundTrack & { lyrics?: { languageCode: string }[] },
) {
  return {
    id: t.id,
    title: t.title,
    durationSeconds: t.durationSeconds,
    kind: t.kind, // INSTRUMENTAL | GUIDED
    audioUrl: mediaUrl(t.audioPath),
    isPremium: t.isPremium,
    displayOrder: t.displayOrder,
    lyricsLanguages: (t.lyrics ?? []).map((l) => l.languageCode),
  };
}

export function serializeCollection(
  c: SoundCollection & {
    tracks?: (SoundTrack & { lyrics?: { languageCode: string }[] })[];
    _count?: { tracks: number };
  },
) {
  return {
    id: c.id,
    categoryId: c.categoryId,
    title: c.title,
    subtitle: c.subtitle,
    palette: c.palette,
    imageUrl: mediaUrl(c.imageUrl),
    isPremium: c.isPremium,
    displayOrder: c.displayOrder,
    trackCount: c._count?.tracks ?? c.tracks?.length,
    tracks: c.tracks ? c.tracks.map(serializeTrack) : undefined,
  };
}

export function serializeCategory(
  cat: SoundCategory & {
    collections?: (SoundCollection & {
      tracks?: (SoundTrack & { lyrics?: { languageCode: string }[] })[];
      _count?: { tracks: number };
    })[];
    _count?: { collections: number };
  },
) {
  return {
    id: cat.id,
    slug: cat.slug,
    title: cat.title,
    displayOrder: cat.displayOrder,
    collectionCount: cat._count?.collections,
    collections: cat.collections
      ? cat.collections.map(serializeCollection)
      : undefined,
  };
}

export function serializeLyrics(l: TrackLyrics) {
  return {
    id: l.id,
    trackId: l.trackId,
    languageCode: l.languageCode,
    content: l.content,
  };
}

export function serializeOnboardingConfig(
  questions: (QuizQuestion & { options: QuizOption[] })[],
  trees: MindTree[],
) {
  return {
    questions: questions.map((q) => ({
      id: q.id,
      prompt: q.prompt,
      options: q.options
        .slice()
        .sort((a, b) => a.displayOrder - b.displayOrder)
        .map((o) => ({
          id: o.key,
          title: o.title,
          subtitle: o.subtitle,
          palette: o.palette,
        })),
    })),
    mindTrees: trees.map((t) => ({
      id: t.id,
      name: t.name,
      tagline: t.tagline,
      imageUrl: mediaUrl(t.imageUrl),
      palette: t.palette,
    })),
  };
}
