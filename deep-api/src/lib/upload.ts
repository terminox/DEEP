import type { FastifyRequest } from "fastify";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import { createWriteStream } from "node:fs";
import { pipeline } from "node:stream/promises";
import path from "node:path";
import { z } from "zod";
import { env } from "../env.js";
import { ApiError } from "./errors.js";
import { mediaPath } from "./media.js";

export type MediaKind = "image" | "audio" | "video";

export const MEDIA_RULES: Record<MediaKind, { extensions: Set<string>; maxBytes: number }> = {
  image: { extensions: new Set([".png", ".jpg", ".jpeg", ".webp"]), maxBytes: 10 * 1024 * 1024 },
  // 25MB, not 200: Cloud Run caps a non-streamed HTTP/1 request body at 32 MiB.
  // Real tracks are 2.6-4.0 MB. .wav is excluded deliberately - a few minutes of
  // wav blows the cap and is a poor delivery format for AVPlayer anyway.
  audio: { extensions: new Set([".mp3", ".m4a", ".aac"]), maxBytes: 25 * 1024 * 1024 },
  // 200MB is only reachable in local dev; behind Cloud Run the 32 MiB body cap
  // applies. Raising it properly needs resumable uploads - out of scope.
  video: { extensions: new Set([".mp4", ".mov"]), maxBytes: 200 * 1024 * 1024 },
};

export type UploadedFile = NonNullable<Awaited<ReturnType<FastifyRequest["file"]>>>;

/**
 * Pulls one uploaded file off the request with a per-call size limit.
 * `throwFileSizeLimit: false` keeps busboy from aborting the request on an
 * oversized file — it just truncates the stream and flags `.truncated`, which
 * `saveUploadedMedia` below checks once the write is done so we can clean up
 * the partial file and return our own `file_too_large` error.
 */
export async function requireUploadedFile(req: FastifyRequest, limitBytes: number): Promise<UploadedFile> {
  const file = await req.file({
    limits: { fileSize: limitBytes },
    throwFileSizeLimit: false,
  });
  if (!file) throw ApiError.badRequest("No file uploaded");
  return file;
}

/**
 * Streams an uploaded file to media/<subdir>/<uuid>.<ext>, enforcing the
 * kind's extension allowlist and the caller's size limit. Returns the
 * relative /media/<subdir>/... path to store on the row.
 */
export async function saveUploadedMedia(
  file: UploadedFile,
  kind: MediaKind,
  subdir: string,
): Promise<string> {
  const ext = path.extname(file.filename).toLowerCase();
  const allowed = MEDIA_RULES[kind].extensions;
  if (!allowed.has(ext)) {
    throw ApiError.badRequest(`Unsupported file type "${ext || "none"}"`, "unsupported_file_type");
  }

  const dir = path.join(env.MEDIA_DIR, subdir);
  await fs.mkdir(dir, { recursive: true });
  const name = `${crypto.randomUUID()}${ext}`;
  const dest = path.join(dir, name);

  await pipeline(file.file, createWriteStream(dest));

  if (file.file.truncated) {
    await fs.unlink(dest).catch(() => {});
    throw ApiError.badRequest("File too large", "file_too_large");
  }

  return `/media/${subdir}/${name}`;
}

/** Best-effort cleanup of a replaced/removed file — only ever under our own upload dir. */
export async function unlinkMedia(relPath: string | null | undefined) {
  if (!relPath || !relPath.startsWith("/media/")) return;
  const root = path.resolve(env.MEDIA_DIR);
  const abs = path.resolve(root, relPath.slice("/media/".length));
  if (!abs.startsWith(root + path.sep)) return; // traversal or outside root - refuse
  await fs.unlink(abs).catch(() => {});
}

// Plant/collection imageUrl (and similar media refs) used to be z.string().url(),
// but admin uploads hand back relative /media/... paths, not absolute URLs.
// Accept either, and collapse a self-origin absolute URL back to relative so a
// reseeded edit form doesn't bake this origin permanently into the row.
export const mediaRefSchema = z
  .string()
  .trim()
  .min(1)
  .refine((v) => /^https?:\/\//i.test(v) || v.startsWith("/media/"), {
    message: "must be an absolute http(s) URL or a /media/ path",
  })
  .transform(mediaPath);
