// DEEP Premium truth flows in from RevenueCat by two routes:
//
//   POST /webhooks/revenuecat      RevenueCat → us. Unauthenticated except for
//                                  the static Authorization header RevenueCat
//                                  echoes back from its dashboard config.
//   POST /me/entitlement/refresh   app → us → RevenueCat REST. The app supplies
//                                  only the trigger; deep-api fetches the facts.
//
// Config is read from `env` per request (not captured at registration) so an
// unset secret degrades to 503 `not_configured` instead of failing boot.
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { env } from "../env.js";
import { ApiError } from "../lib/errors.js";
import { requireAuth } from "../auth/middleware.js";
import { Cooldown } from "../lib/rateLimit.js";
import { serializeEntitlement, forgetRequestSubscription } from "../lib/entitlement.js";
import { webhookAuthMatches } from "../lib/revenuecat/auth.js";
import { applyWebhookEvent, refreshSubscription } from "../lib/revenuecat/apply.js";
import type { RevenueCatWebhookBody } from "../lib/revenuecat/derive.js";

/** One RevenueCat refresh per user per 30s. */
export const refreshCooldown = new Cooldown(30_000);

// Only the envelope is validated: RevenueCat adds fields and types freely, and
// the whole parsed body is stored for forensics.
const webhookSchema = z
  .object({
    event: z.object({ id: z.string().min(1), type: z.string().min(1) }).passthrough(),
  })
  .passthrough();

function notConfigured(what: string) {
  return new ApiError(503, "not_configured", `${what} is not configured`);
}

export async function revenueCatRoutes(app: FastifyInstance) {
  app.post("/webhooks/revenuecat", async (req, reply) => {
    const expected = env.REVENUECAT_WEBHOOK_AUTH;
    if (!expected) throw notConfigured("RevenueCat webhook");
    // Never log the header. Mismatch → unrevealing 401, before the body is read.
    if (!webhookAuthMatches(req.headers.authorization, expected)) {
      throw ApiError.unauthorized();
    }

    const body = webhookSchema.parse(req.body) as unknown as RevenueCatWebhookBody;
    const result = await applyWebhookEvent(body, {
      entitlementId: env.REVENUECAT_ENTITLEMENT_ID,
      acceptSandbox: env.REVENUECAT_ACCEPT_SANDBOX,
    });
    req.log.info(
      { revenuecatEvent: body.event.id, type: body.event.type, outcome: result.outcome },
      "revenuecat webhook",
    );

    // The receiving side of a transfer carries no product data: fetch it. The
    // event is already recorded, so a failure here never fails the delivery.
    const secretKey = env.REVENUECAT_SECRET_API_KEY;
    if (secretKey) {
      for (const userId of result.refreshUserIds) {
        await refreshSubscription(userId, {
          secretKey,
          entitlementId: env.REVENUECAT_ENTITLEMENT_ID,
          acceptSandbox: env.REVENUECAT_ACCEPT_SANDBOX,
        }).catch((e) => req.log.warn({ userId, err: (e as Error).message }, "transfer refresh failed"));
      }
    }

    return reply.status(200).send({ ok: true, outcome: result.outcome.toLowerCase() });
  });

  // Accepts no body facts at all: whatever the client posts is ignored.
  app.post("/me/entitlement/refresh", { preHandler: requireAuth }, async (req) => {
    const secretKey = env.REVENUECAT_SECRET_API_KEY;
    if (!secretKey) throw notConfigured("RevenueCat refresh");
    const userId = req.auth!.sub;
    refreshCooldown.hit(userId);

    const row = await refreshSubscription(userId, {
      secretKey,
      entitlementId: env.REVENUECAT_ENTITLEMENT_ID,
      acceptSandbox: env.REVENUECAT_ACCEPT_SANDBOX,
    });
    forgetRequestSubscription(req);
    return { entitlement: serializeEntitlement(row) };
  });
}
