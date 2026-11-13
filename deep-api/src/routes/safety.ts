import type { FastifyInstance } from "fastify";
import type { PeaceMessageReportReason, UserBlock } from "@prisma/client";
import { z } from "zod";
import { prisma } from "../prisma.js";
import { ApiError } from "../lib/errors.js";
import { requireAuth } from "../auth/middleware.js";
import { env } from "../env.js";

// Report and Block for peace messages (Apple Guideline 1.2). The feeds that
// honour both live in pauseLive.ts; this file records them.

const idParam = z.object({ id: z.string().min(1) });

const reasonSchema = z.enum(["offensive", "harassment", "spam", "other"]);
const REASONS: Record<z.infer<typeof reasonSchema>, PeaceMessageReportReason> = {
  offensive: "OFFENSIVE",
  harassment: "HARASSMENT",
  spam: "SPAM",
  other: "OTHER",
};

// The blocked member is shown by their current name, never their id.
function serializeBlock(block: UserBlock & { blocked: { displayName: string } }) {
  return {
    id: block.id,
    displayName: block.blocked.displayName,
    createdAt: block.createdAt.toISOString(),
  };
}

async function othersMessage(id: string, callerId: string) {
  const message = await prisma.peaceMessage.findUnique({ where: { id } });
  if (!message) throw ApiError.notFound("Message not found");
  if (message.userId === callerId) {
    throw ApiError.badRequest("That's your own message", "own_message");
  }
  return message;
}

export async function safetyRoutes(app: FastifyInstance) {
  app.post("/pause/messages/:id/report", { preHandler: requireAuth }, async (req) => {
    const { id } = idParam.parse(req.params);
    const { reason } = z.object({ reason: reasonSchema }).parse(req.body);
    const reporterId = req.auth!.sub;
    const message = await othersMessage(id, reporterId);

    // A repeat report by the same member is a no-op, so the threshold below
    // counts distinct reporters.
    const { count } = await prisma.peaceMessageReport.createMany({
      data: [{ messageId: id, reporterId, reason: REASONS[reason] }],
      skipDuplicates: true,
    });
    // Only reports no admin has reviewed count: restoring a message marks its
    // reports reviewed, so it takes a fresh threshold of new reporters to hide
    // it again. >= rather than == so a race past the exact count can't leave
    // it published.
    if (count > 0 && message.status === "PUBLISHED") {
      const reporters = await prisma.peaceMessageReport.count({
        where: { messageId: id, reviewedAt: null },
      });
      if (reporters >= env.REPORT_HIDE_THRESHOLD) {
        await prisma.peaceMessage.update({ where: { id }, data: { status: "HIDDEN" } });
      }
    }
    return { ok: true };
  });

  app.post("/pause/messages/:id/block-author", { preHandler: requireAuth }, async (req) => {
    const { id } = idParam.parse(req.params);
    const blockerId = req.auth!.sub;
    const message = await othersMessage(id, blockerId);
    // The author deleted their account: nobody left to block, and nothing else
    // of theirs can appear. The client hides this one message itself.
    if (!message.userId) return { ok: true, block: null };

    const block = await prisma.userBlock.upsert({
      where: { blockerId_blockedId: { blockerId, blockedId: message.userId } },
      create: { blockerId, blockedId: message.userId },
      update: {},
      include: { blocked: { select: { displayName: true } } },
    });
    return { ok: true, block: serializeBlock(block) };
  });

  app.get("/me/blocks", { preHandler: requireAuth }, async (req) => {
    const blocks = await prisma.userBlock.findMany({
      where: { blockerId: req.auth!.sub },
      orderBy: { createdAt: "desc" },
      include: { blocked: { select: { displayName: true } } },
    });
    return { blocks: blocks.map(serializeBlock) };
  });

  // Scoped to the caller, so an id that is unknown or someone else's is a
  // quiet no-op rather than a way to probe or undo another member's blocks.
  app.delete("/me/blocks/:id", { preHandler: requireAuth }, async (req) => {
    const { id } = idParam.parse(req.params);
    await prisma.userBlock.deleteMany({ where: { id, blockerId: req.auth!.sub } });
    return { ok: true };
  });
}
