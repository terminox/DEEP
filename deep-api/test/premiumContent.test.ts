import { test } from "node:test";
import assert from "node:assert/strict";

// Same ordering trick as test/playlist.test.ts: env.ts parses process.env once
// at module load and serialize.ts reaches mediaUrl through it, so the base URL
// is pinned before the first dynamic import.
process.env.PUBLIC_BASE_URL = "https://deep.example.com";
const {
  ADMIN_ACCESS,
  LOCKED_ACCESS,
  isCollectionLocked,
  isPlantLocked,
  isTrackLocked,
} = await import("../src/lib/premiumContent.js");
const {
  serializeCategory,
  serializeCollection,
  serializeGarden,
  serializePlantWithStages,
  serializePlaylistItem,
  serializeTrack,
} = await import("../src/lib/serialize.js");

const MEMBER = { unlocked: true };
const NON_MEMBER = { unlocked: false };
const T0 = new Date("2026-01-01T00:00:00.000Z");

function collection(id: string, isPremium: boolean) {
  return {
    id,
    categoryId: "cat1",
    title: `Collection ${id}`,
    subtitle: "Recorded at dawn",
    palette: "mist",
    imageUrl: `/media/uploads/images/${id}.jpg`,
    isPremium,
    isActive: true,
    displayOrder: 0,
    createdAt: T0,
    updatedAt: T0,
  };
}

function track(id: string, collectionId: string, isPremium: boolean) {
  return {
    id,
    collectionId,
    title: `Track ${id}`,
    durationSeconds: 245,
    kind: "GUIDED" as const,
    audioPath: `/media/audio/${id}.mp3`,
    displayOrder: 0,
    isPremium,
    isActive: true,
    createdAt: T0,
    updatedAt: T0,
    lyrics: [{ languageCode: "en" }, { languageCode: "th" }],
  };
}

// ---- The rule ----

test("a track is locked iff it or its collection is premium and the caller is not", () => {
  for (const trackPremium of [false, true]) {
    for (const collectionPremium of [false, true]) {
      const t = { isPremium: trackPremium };
      const c = { isPremium: collectionPremium };
      assert.equal(isTrackLocked(t, c, MEMBER), false, "a member is never locked");
      assert.equal(
        isTrackLocked(t, c, NON_MEMBER),
        trackPremium || collectionPremium,
        `track ${trackPremium} / collection ${collectionPremium}`,
      );
    }
  }
});

test("a track with no parent at hand fails closed for a locked view", () => {
  assert.equal(isTrackLocked({ isPremium: false }, null, NON_MEMBER), true);
  assert.equal(isTrackLocked({ isPremium: false }, null, ADMIN_ACCESS), false);
});

test("a collection is locked iff it is premium and the caller is not", () => {
  assert.equal(isCollectionLocked({ isPremium: true }, NON_MEMBER), true);
  assert.equal(isCollectionLocked({ isPremium: true }, MEMBER), false);
  assert.equal(isCollectionLocked({ isPremium: false }, NON_MEMBER), false);
});

test("a premium plant is locked unless the caller is a member or has grown it", () => {
  const premium = { isPremium: true };
  assert.equal(isPlantLocked(premium, NON_MEMBER, false), true);
  assert.equal(isPlantLocked(premium, MEMBER, false), false);
  assert.equal(isPlantLocked(premium, NON_MEMBER, true), false, "grandfathered");
  assert.equal(isPlantLocked({ isPremium: false }, NON_MEMBER, false), false);
});

test("the shared access constants cannot be flipped at runtime", () => {
  assert.throws(() => {
    (LOCKED_ACCESS as { unlocked: boolean }).unlocked = true;
  });
  assert.equal(LOCKED_ACCESS.unlocked, false);
  assert.equal(ADMIN_ACCESS.unlocked, true);
});

// ---- Serializers ----

test("a locked track withholds only its audio URL", () => {
  const free = collection("c1", false);
  const locked = serializeTrack(track("t1", "c1", true), NON_MEMBER, free);
  const open = serializeTrack(track("t1", "c1", true), MEMBER, free);

  assert.equal(locked.audioUrl, null);
  assert.equal(locked.isLocked, true);
  assert.equal(locked.isPremium, true);
  assert.equal(open.audioUrl, "https://deep.example.com/media/audio/t1.mp3");
  assert.equal(open.isLocked, false);

  // Everything the lock UI renders is still there.
  const { audioUrl: _a, isLocked: _l, ...lockedRest } = locked;
  const { audioUrl: _b, isLocked: _m, ...openRest } = open;
  assert.deepEqual(lockedRest, openRest);
  assert.equal(locked.title, "Track t1");
  assert.equal(locked.durationSeconds, 245);
  assert.deepEqual(locked.lyricsLanguages, ["en", "th"]);
});

test("a premium collection locks its free tracks, and keeps its artwork and count", () => {
  const c = {
    ...collection("c1", true),
    tracks: [track("t1", "c1", false), track("t2", "c1", false)],
  };
  const out = serializeCollection(c, NON_MEMBER);

  assert.equal(out.isLocked, true);
  assert.equal(out.isPremium, true);
  assert.equal(out.imageUrl, "https://deep.example.com/media/uploads/images/c1.jpg");
  assert.equal(out.trackCount, 2);
  assert.deepEqual(out.tracks?.map((t) => [t.isLocked, t.audioUrl]), [
    [true, null],
    [true, null],
  ]);
});

test("a premium track in a free collection is locked on its own", () => {
  const c = {
    ...collection("c1", false),
    tracks: [track("free", "c1", false), track("paid", "c1", true)],
  };
  const out = serializeCollection(c, NON_MEMBER);

  assert.equal(out.isLocked, false);
  assert.deepEqual(
    out.tracks?.map((t) => [t.id, t.isLocked, t.audioUrl]),
    [
      ["free", false, "https://deep.example.com/media/audio/free.mp3"],
      ["paid", true, null],
    ],
  );
});

test("the admin view carries every URL", () => {
  const c = { ...collection("c1", true), tracks: [track("t1", "c1", true)] };
  const out = serializeCategory(
    {
      id: "cat1",
      slug: "sleep",
      title: "Sleep",
      displayOrder: 0,
      isActive: true,
      createdAt: T0,
      updatedAt: T0,
      collections: [c],
    },
    ADMIN_ACCESS,
  );
  const t = out.collections?.[0]?.tracks?.[0];
  assert.equal(out.collections?.[0]?.isLocked, false);
  assert.equal(t?.isLocked, false);
  assert.equal(t?.audioUrl, "https://deep.example.com/media/audio/t1.mp3");
});

test("a kept track inherits its origin collection's lock", () => {
  const origin = collection("c1", true);
  const item = {
    id: "i1",
    playlistId: "p1",
    trackId: "t1",
    createdAt: T0,
    track: { ...track("t1", "c1", false), collection: origin },
  };
  const locked = serializePlaylistItem(item, NON_MEMBER);
  assert.equal(locked.track.isLocked, true);
  assert.equal(locked.track.audioUrl, null);
  assert.equal(locked.collection.isLocked, true);

  const open = serializePlaylistItem(item, MEMBER);
  assert.equal(open.track.audioUrl, "https://deep.example.com/media/audio/t1.mp3");
});

// ---- Plants ----

const lotus = {
  id: "lotus",
  name: "Lotus",
  tagline: "Opens slowly",
  imageUrl: "/media/garden/images/lotus.png",
  palette: "dusk",
  displayOrder: 0,
  isPremium: true,
  isDefault: false,
  isActive: true,
  createdAt: T0,
  updatedAt: T0,
};
const seed = {
  id: "s1",
  plantId: "lotus",
  name: "Seed",
  displayOrder: 0,
  sunlightRequired: 0,
  mascotPath: null,
  mascotBgPath: null,
  heroVideoPath: null,
};

test("a locked plant is fully described, carrying isPremium and isLocked", () => {
  const out = serializePlantWithStages({ ...lotus, stages: [seed] }, true);
  assert.equal(out.isPremium, true);
  assert.equal(out.isLocked, true);
  assert.equal(out.name, "Lotus");
  assert.equal(out.imageUrl, "https://deep.example.com/media/garden/images/lotus.png");
  assert.equal(out.stages.length, 1);
});

test("the garden's own selected plant never serializes as locked", () => {
  const garden = serializeGarden(lotus, [seed], 12, { lotus: 12 });
  assert.equal(garden.selectedPlant.isPremium, true);
  assert.equal(garden.selectedPlant.isLocked, false);
});
