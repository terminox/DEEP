import { test } from "node:test";
import assert from "node:assert/strict";
import { readAudioDurationSeconds } from "../src/lib/audioDuration.js";
import { resolveMediaFile } from "../src/lib/mediaFiles.js";

// Runs against the tracks committed at deep-api/media/audio/, with MEDIA_DIR
// left at its default (./media) — the same files the seed measures.

test("measures a committed track's real length", async () => {
  // global-pause.mp3 is 131.96s; the pause config used to carry a hand-typed
  // 132 next to it, which is exactly what stopped matching the file.
  assert.equal(await readAudioDurationSeconds("/media/audio/global-pause.mp3"), 132);
});

test("null for anything that isn't a readable local media file", async () => {
  assert.equal(await readAudioDurationSeconds("https://example.com/track.mp3"), null);
  assert.equal(await readAudioDurationSeconds("/media/audio/does-not-exist.mp3"), null);
  assert.equal(await readAudioDurationSeconds(null), null);
  assert.equal(await readAudioDurationSeconds(""), null);
});

test("resolveMediaFile refuses to escape the media root", () => {
  assert.equal(resolveMediaFile("/media/../../etc/passwd"), null);
  assert.equal(resolveMediaFile("/media/audio/../../../.env"), null);
  assert.equal(resolveMediaFile("/etc/passwd"), null);
  assert.ok(resolveMediaFile("/media/audio/global-pause.mp3")?.endsWith("/media/audio/global-pause.mp3"));
});
