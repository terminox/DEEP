import { test } from "node:test";
import assert from "node:assert/strict";

// Same ordering trick as test/upload.test.ts: env.ts parses process.env once at
// module load, and serialize.ts reaches mediaUrl through it, so the base URL has
// to be pinned before the first dynamic import.
process.env.PUBLIC_BASE_URL = "https://deep.example.com";
const { serializePlaylist, serializePlaylistItem } = await import(
  "../src/lib/serialize.js"
);

const collection = {
  id: "c1",
  categoryId: "cat1",
  title: "Ocean Field",
  subtitle: "Recorded at dawn",
  palette: "mist",
  imageUrl: "/media/uploads/images/ocean.jpg",
  isPremium: false,
  displayOrder: 0,
  createdAt: new Date("2026-01-01T00:00:00.000Z"),
  updatedAt: new Date("2026-01-01T00:00:00.000Z"),
};

function item(id: string, trackId: string, title: string, savedAt: string) {
  return {
    id,
    playlistId: "p1",
    trackId,
    createdAt: new Date(savedAt),
    track: {
      id: trackId,
      collectionId: collection.id,
      title,
      durationSeconds: 245,
      kind: "INSTRUMENTAL" as const,
      audioPath: `/media/audio/${trackId}.mp3`,
      displayOrder: 0,
      isPremium: false,
      createdAt: new Date("2026-01-01T00:00:00.000Z"),
      updatedAt: new Date("2026-01-01T00:00:00.000Z"),
      collection,
    },
  };
}

const playlist = {
  id: "p1",
  userId: "u1",
  name: "Playlist",
  isDefault: true,
  displayOrder: 0,
  createdAt: new Date("2026-08-01T00:00:00.000Z"),
  updatedAt: new Date("2026-08-20T09:30:00.000Z"),
};

test("a kept item carries the track and where it came from", () => {
  const kept = serializePlaylistItem(item("i1", "t1", "Low Tide", "2026-08-20T09:00:00.000Z"));

  assert.equal(kept.id, "i1");
  assert.equal(kept.savedAt, "2026-08-20T09:00:00.000Z");
  assert.equal(kept.track.id, "t1");
  assert.equal(kept.track.title, "Low Tide");
  assert.equal(kept.collection.id, "c1");
  assert.equal(kept.collection.title, "Ocean Field");
});

test("relative media paths are served as absolute URLs", () => {
  const kept = serializePlaylistItem(item("i1", "t1", "Low Tide", "2026-08-20T09:00:00.000Z"));

  assert.equal(kept.track.audioUrl, "https://deep.example.com/media/audio/t1.mp3");
  assert.equal(
    kept.collection.imageUrl,
    "https://deep.example.com/media/uploads/images/ocean.jpg",
  );
});

test("the origin collection arrives without its own tracks", () => {
  // A kept-track row only needs artwork and a name; shipping the whole album
  // with every item would balloon the payload for nothing.
  const kept = serializePlaylistItem(item("i1", "t1", "Low Tide", "2026-08-20T09:00:00.000Z"));

  assert.equal(kept.collection.tracks, undefined);
});

test("a playlist keeps the order it was queried in", () => {
  const serialized = serializePlaylist({
    ...playlist,
    items: [
      item("i2", "t2", "High Tide", "2026-08-20T10:00:00.000Z"),
      item("i1", "t1", "Low Tide", "2026-08-20T09:00:00.000Z"),
    ],
  });

  assert.deepEqual(
    serialized.items?.map((i) => i.track.title),
    ["High Tide", "Low Tide"],
  );
  assert.equal(serialized.trackCount, 2);
  assert.equal(serialized.updatedAt, "2026-08-20T09:30:00.000Z");
  assert.equal(serialized.isDefault, true);
  assert.equal(serialized.name, "Playlist");
});

test("a playlist with nothing kept serializes as empty, not absent", () => {
  const serialized = serializePlaylist({ ...playlist, items: [] });

  assert.equal(serialized.trackCount, 0);
  assert.deepEqual(serialized.items, []);
});

test("a playlist loaded without its items reports no track count", () => {
  const serialized = serializePlaylist(playlist);

  assert.equal(serialized.items, undefined);
  assert.equal(serialized.trackCount, 0);
});
