import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import { requireRole } from "../auth/middleware.js";
import { mediaUrl } from "../lib/media.js";
import { MEDIA_RULES, requireUploadedFile, saveUploadedMedia } from "../lib/upload.js";
import { readAudioDurationSeconds } from "../lib/audioDuration.js";

export async function adminMediaRoutes(app: FastifyInstance) {
  const adminOnly = { preHandler: requireRole("ADMIN") };

  // kind is a path param, not a multipart field: @fastify/multipart's req.file()
  // resolves at the first file part in the stream, so a field appearing after
  // the file wouldn't be parsed in time.
  //
  // Generic upload: stores the bytes and hands back the path, without touching
  // any DB row. This is what lets create-forms (which have no row id yet) and
  // the Save-button Pause config form attach media as an ordinary form value.
  app.post("/admin/media/:kind", adminOnly, async (req: FastifyRequest) => {
    const { kind } = z.object({ kind: z.enum(["image", "audio", "video"]) }).parse(req.params);
    const rule = MEDIA_RULES[kind];
    const file = await requireUploadedFile(req, rule.maxBytes);
    const subdir = `uploads/${kind === "image" ? "images" : kind === "video" ? "videos" : "audio"}`;
    const relPath = await saveUploadedMedia(file, kind, subdir);
    // Audio comes back with its measured length so the form can show the truth
    // straight away — the browser's own metadata read is only a hint, and for
    // the pause config this number is how long the session runs.
    const durationSeconds = kind === "audio" ? await readAudioDurationSeconds(relPath) : null;
    return { media: { path: relPath, url: mediaUrl(relPath), durationSeconds } };
  });
}
