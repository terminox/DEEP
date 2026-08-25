import { test } from "node:test";
import assert from "node:assert/strict";

// Pins PUBLIC_BASE_URL before env.ts (and therefore lib/media.ts / lib/upload.ts)
// is ever imported, since env.ts parses process.env once at module-load time —
// see test/geoip.test.ts for the same trick. A dynamic import after setting the
// var is what makes that ordering work. node --test runs each test file in its
// own process, so this doesn't leak into other test files.
process.env.PUBLIC_BASE_URL = "https://deep.example.com";
const { env } = await import("../src/env.js");
const { mediaPath } = await import("../src/lib/media.js");
const { MEDIA_RULES, mediaRefSchema } = await import("../src/lib/upload.js");

test("mediaPath leaves a genuine third-party URL absolute", () => {
  const unsplash = "https://images.unsplash.com/photo-123?auto=format";
  assert.equal(mediaPath(unsplash), unsplash);
});

test("mediaPath collapses a self-origin PUBLIC_BASE_URL URL to a relative path", () => {
  assert.equal(
    mediaPath(`${env.PUBLIC_BASE_URL}/media/garden/images/x.png`),
    "/media/garden/images/x.png",
  );
});

test("mediaPath is the identity on an already-relative path", () => {
  assert.equal(mediaPath("/media/audio/x.mp3"), "/media/audio/x.mp3");
});

test("mediaPath collapses a localhost:PORT URL to a relative path", () => {
  assert.equal(
    mediaPath(`http://localhost:${env.PORT}/media/audio/x.mp3`),
    "/media/audio/x.mp3",
  );
});

test("mediaRefSchema accepts an absolute https URL", () => {
  const unsplash = "https://images.unsplash.com/photo-123";
  assert.equal(mediaRefSchema.parse(unsplash), unsplash);
});

test("mediaRefSchema accepts a /media/... path", () => {
  assert.equal(mediaRefSchema.parse("/media/x.png"), "/media/x.png");
});

test("mediaRefSchema rejects a path-traversal attempt", () => {
  assert.throws(() => mediaRefSchema.parse("../etc/passwd"));
});

test("mediaRefSchema rejects an empty string", () => {
  assert.throws(() => mediaRefSchema.parse(""));
});

test("mediaRefSchema transforms a self-origin absolute URL to relative", () => {
  assert.equal(
    mediaRefSchema.parse(`${env.PUBLIC_BASE_URL}/media/garden/images/x.png`),
    "/media/garden/images/x.png",
  );
});

test("MEDIA_RULES.image accepts the image extension allowlist only", () => {
  for (const ext of [".png", ".jpg", ".jpeg", ".webp"]) {
    assert.equal(MEDIA_RULES.image.extensions.has(ext), true, ext);
  }
  assert.equal(MEDIA_RULES.image.extensions.has(".mp4"), false);
});

test("MEDIA_RULES.audio accepts the audio extension allowlist and excludes .wav", () => {
  for (const ext of [".mp3", ".m4a", ".aac"]) {
    assert.equal(MEDIA_RULES.audio.extensions.has(ext), true, ext);
  }
  assert.equal(MEDIA_RULES.audio.extensions.has(".wav"), false);
});

test("MEDIA_RULES.video accepts the video extension allowlist only", () => {
  for (const ext of [".mp4", ".mov"]) {
    assert.equal(MEDIA_RULES.video.extensions.has(ext), true, ext);
  }
  assert.equal(MEDIA_RULES.video.extensions.has(".png"), false);
});
