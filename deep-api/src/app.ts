import path from "node:path";
import fs from "node:fs";
import Fastify from "fastify";
import cors from "@fastify/cors";
import multipart from "@fastify/multipart";
import fastifyStatic from "@fastify/static";
import { ZodError } from "zod";
import { env } from "./env.js";
import { ApiError } from "./lib/errors.js";
import { requestBaseUrl } from "./lib/media.js";
import { negotiateLanguage, requestLanguage } from "./lib/requestLanguage.js";
import { primeTranslations } from "./lib/translations.js";
import { authRoutes } from "./routes/auth.js";
import { onboardingRoutes } from "./routes/onboarding.js";
import { soundRoutes } from "./routes/sound.js";
import { pauseRoutes } from "./routes/pause.js";
import { practiceRoutes } from "./routes/practice.js";
import { pauseLiveRoutes } from "./routes/pauseLive.js";
import { gardenRoutes } from "./routes/garden.js";
import { heartsRoutes } from "./routes/hearts.js";
import { playlistRoutes } from "./routes/playlist.js";
import { adminRoutes } from "./routes/admin.js";
import { adminGardenRoutes } from "./routes/adminGarden.js";
import { adminMediaRoutes } from "./routes/adminMedia.js";

export function buildApp() {
  const app = Fastify({ logger: true, trustProxy: true });

  app.register(cors, { origin: true });
  // 200MB covers the largest per-call limit (stage hero videos); individual
  // upload routes still enforce their own tighter limits via req.file({limits}).
  app.register(multipart, { limits: { fileSize: 200 * 1024 * 1024 } });

  // Remember the origin this request arrived on so mediaUrl() can hand back
  // absolute URLs the caller can actually reach. `req.headers.host` rather than
  // `req.hostname` because the port matters and Fastify strips it. trustProxy is
  // on above, so req.protocol already honours X-Forwarded-Proto behind a tunnel.
  app.addHook("onRequest", (req, _reply, done) => {
    const host = req.headers.host ?? req.hostname;
    requestBaseUrl.run(`${req.protocol}://${host}`, done);
  });

  // Resolve the request's language the same way, then warm the translation
  // cache before any route runs — `serialize.ts` is synchronous, so the copy
  // has to be in memory by the time it projects a row. Serving English is
  // always a valid outcome, so this never fails a request.
  app.addHook("onRequest", (req, _reply, done) => {
    const language = negotiateLanguage(req.headers["accept-language"]);
    requestLanguage.run(language, () => {
      primeTranslations().finally(done);
    });
  });

  // Serve uploaded/seeded media at /media (progressive HTTP; AVPlayer-friendly).
  const mediaRoot = path.resolve(env.MEDIA_DIR);
  fs.mkdirSync(path.join(mediaRoot, "audio"), { recursive: true });
  fs.mkdirSync(path.join(mediaRoot, "garden", "images"), { recursive: true });
  fs.mkdirSync(path.join(mediaRoot, "garden", "videos"), { recursive: true });
  fs.mkdirSync(path.join(mediaRoot, "uploads", "images"), { recursive: true });
  fs.mkdirSync(path.join(mediaRoot, "uploads", "audio"), { recursive: true });
  fs.mkdirSync(path.join(mediaRoot, "uploads", "videos"), { recursive: true });
  // maxAge lets clients reuse media for a week; ETags stay on, so stable-but-
  // mutable seed filenames still revalidate cheaply after expiry (no immutable).
  app.register(fastifyStatic, { root: mediaRoot, prefix: "/media/", maxAge: "7d" });

  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof ApiError) {
      return reply
        .status(error.statusCode)
        .send({ error: { code: error.code, message: error.message } });
    }
    if (error instanceof ZodError) {
      return reply.status(400).send({
        error: { code: "validation_error", message: "Invalid request", issues: error.issues },
      });
    }
    // Prisma unique-constraint etc. surface as 500 unless mapped above.
    reply.log.error(error);
    const e = error as { statusCode?: number; message?: string };
    return reply
      .status(e.statusCode ?? 500)
      .send({ error: { code: "internal_error", message: e.message ?? "Error" } });
  });

  app.get("/health", async () => ({ ok: true, env: "deep-api" }));

  app.register(authRoutes);
  app.register(onboardingRoutes);
  app.register(soundRoutes);
  app.register(pauseRoutes);
  app.register(practiceRoutes);
  app.register(pauseLiveRoutes);
  app.register(gardenRoutes);
  app.register(heartsRoutes);
  app.register(playlistRoutes);
  app.register(adminRoutes);
  app.register(adminGardenRoutes);
  app.register(adminMediaRoutes);

  return app;
}
