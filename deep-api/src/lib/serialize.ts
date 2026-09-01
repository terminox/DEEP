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
  Plant,
  PlantStage,
  HeartSpend,
  Playlist,
  PlaylistItem,
} from "@prisma/client";
import { mediaUrl } from "./media.js";
import { translate } from "./translations.js";
import { deriveStageIndex } from "./awardRules.js";
import type { AwardOutcome, WalletSummary } from "./awards.js";

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
    title: translate("SOUND_TRACK", t.id, "title", t.title),
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
    title: translate("SOUND_COLLECTION", c.id, "title", c.title),
    subtitle: translate("SOUND_COLLECTION", c.id, "subtitle", c.subtitle),
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
    title: translate("SOUND_CATEGORY", cat.id, "title", cat.title),
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

// ---- Playlists ----

// The origin collection rides along without its tracks: a kept-track row needs
// the artwork and the name of where the sound came from, nothing more.
type PlaylistItemWithTrack = PlaylistItem & {
  track: SoundTrack & {
    collection: SoundCollection;
    lyrics?: { languageCode: string }[];
  };
};

export function serializePlaylistItem(i: PlaylistItemWithTrack) {
  return {
    id: i.id,
    savedAt: i.createdAt.toISOString(),
    track: serializeTrack(i.track),
    collection: serializeCollection(i.track.collection),
  };
}

export function serializePlaylist(
  p: Playlist & { items?: PlaylistItemWithTrack[] },
) {
  return {
    id: p.id,
    name: p.name,
    isDefault: p.isDefault,
    trackCount: p.items?.length ?? 0,
    updatedAt: p.updatedAt.toISOString(),
    items: p.items ? p.items.map(serializePlaylistItem) : undefined,
  };
}

export function serializeOnboardingConfig(
  questions: (QuizQuestion & { options: QuizOption[] })[],
  trees: Plant[],
) {
  return {
    questions: questions.map((q) => ({
      id: q.id,
      prompt: translate("QUIZ_QUESTION", q.id, "prompt", q.prompt),
      options: q.options
        .slice()
        .sort((a, b) => a.displayOrder - b.displayOrder)
        .map((o) => ({
          id: o.key,
          title: translate("QUIZ_OPTION", o.id, "title", o.title),
          subtitle: translate("QUIZ_OPTION", o.id, "subtitle", o.subtitle),
          palette: o.palette,
        })),
    })),
    mindTrees: trees.map((t) => ({
      id: t.id,
      name: translate("PLANT", t.id, "name", t.name),
      tagline: translate("PLANT", t.id, "tagline", t.tagline),
      imageUrl: mediaUrl(t.imageUrl),
      palette: t.palette,
    })),
  };
}

// ---- Mind Garden plants + hearts ----

export function serializePlant(p: Plant) {
  return {
    id: p.id,
    name: translate("PLANT", p.id, "name", p.name),
    tagline: translate("PLANT", p.id, "tagline", p.tagline),
    imageUrl: mediaUrl(p.imageUrl),
    palette: p.palette,
    displayOrder: p.displayOrder,
    isPremium: p.isPremium,
    isDefault: p.isDefault,
    isActive: p.isActive,
  };
}

export function serializePlantStage(s: PlantStage) {
  return {
    id: s.id,
    plantId: s.plantId,
    name: translate("PLANT_STAGE", s.id, "name", s.name),
    displayOrder: s.displayOrder,
    sunlightRequired: s.sunlightRequired,
    mascotUrl: mediaUrl(s.mascotPath),
    mascotBgUrl: mediaUrl(s.mascotBgPath),
    heroVideoUrl: mediaUrl(s.heroVideoPath),
  };
}

export function serializePlantWithStages(p: Plant & { stages: PlantStage[] }) {
  return {
    ...serializePlant(p),
    stages: p.stages
      .slice()
      .sort((a, b) => a.displayOrder - b.displayOrder)
      .map(serializePlantStage),
  };
}

export function serializeWallet(w: WalletSummary) {
  return {
    heartsBalance: w.heartsBalance,
    heartsEarned: w.heartsEarned,
    heartsGiven: w.heartsGiven,
    earnedToday: w.earnedToday,
    remainingToday: w.remainingToday,
    dailyCap: w.dailyCap,
    givenByCategory: w.givenByCategory,
  };
}

export function serializeAwardOutcome(o: AwardOutcome) {
  return {
    kind: o.kind,
    granted: o.granted,
    heartsGranted: o.hearts,
    sunlightGranted: o.sunlight,
    plantId: o.plantId,
    cappedBy: o.cappedBy,
  };
}

/** The `/me/garden` garden shape: the selected plant at its earned stage. */
export function serializeGarden(
  plant: Plant,
  stages: PlantStage[],
  sunlight: number,
  sunlightByPlant: Record<string, number>,
) {
  const ordered = stages.slice().sort((a, b) => a.displayOrder - b.displayOrder);
  return {
    selectedPlant: serializePlant(plant),
    sunlight,
    currentStageIndex: deriveStageIndex(ordered, sunlight),
    stages: ordered.map(serializePlantStage),
    sunlightByPlant,
  };
}

export function serializeSpend(s: HeartSpend) {
  return {
    id: s.id,
    amount: s.amount,
    category: s.category,
    projectId: s.projectId,
    createdAt: s.createdAt.toISOString(),
  };
}
