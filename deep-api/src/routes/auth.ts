import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { hashPassword, verifyPassword } from "../auth/password.js";
import { createSession, rotateSession, revokeSession } from "../auth/sessions.js";
import { requireAuth } from "../auth/middleware.js";
import { serializeUser } from "../lib/serialize.js";

const signupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  displayName: z.string().trim().min(1),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({ refreshToken: z.string().min(1) });

function device(req: FastifyRequest) {
  return { userAgent: req.headers["user-agent"], ip: req.ip };
}

export async function authRoutes(app: FastifyInstance) {
  app.post("/auth/signup", async (req) => {
    const body = signupSchema.parse(req.body);
    const email = body.email.toLowerCase();

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) throw ApiError.conflict("Email already registered", "email_taken");

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash: await hashPassword(body.password),
        displayName: body.displayName,
      },
    });

    const tokens = await createSession(user.id, user.role, device(req));
    return { user: serializeUser(user), ...tokens };
  });

  app.post("/auth/login", async (req) => {
    const body = loginSchema.parse(req.body);
    const user = await prisma.user.findUnique({
      where: { email: body.email.toLowerCase() },
    });
    if (!user || !(await verifyPassword(user.passwordHash, body.password))) {
      throw ApiError.unauthorized("Incorrect email or password", "invalid_credentials");
    }
    const tokens = await createSession(user.id, user.role, device(req));
    return { user: serializeUser(user), ...tokens };
  });

  app.post("/auth/refresh", async (req) => {
    const body = refreshSchema.parse(req.body);
    return rotateSession(body.refreshToken, device(req));
  });

  app.post("/auth/logout", { preHandler: requireAuth }, async (req) => {
    await revokeSession(req.auth!.sid);
    return { ok: true };
  });

  app.get("/me", { preHandler: requireAuth }, async (req) => {
    const user = await prisma.user.findUnique({ where: { id: req.auth!.sub } });
    if (!user) throw ApiError.notFound("User not found");
    return { user: serializeUser(user) };
  });

  app.delete("/me", { preHandler: requireAuth }, async (req) => {
    // AuthSession + OnboardingProfile cascade (see schema.prisma). Idempotent
    // like logout: a repeat delete of an already-gone user still returns ok.
    await prisma.user.delete({ where: { id: req.auth!.sub } }).catch((e) => {
      if (e?.code !== "P2025") throw e;
    });
    return { ok: true };
  });
}
