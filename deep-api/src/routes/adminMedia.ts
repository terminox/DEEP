import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import { requireRole } from "../auth/middleware.js";
import { mediaUrl } from "../lib/media.js";
import { MEDIA_RULES, requireUploadedFile, saveUploadedMedia } from "../lib/upload.js";

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
    return { media: { path: relPath, url: mediaUrl(relPath) } };
  });
}
