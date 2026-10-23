// DEEP Premium content locks: the one place that decides whether a piece of
// content is locked for the caller. Serializers and routes ask these
// predicates; nothing else re-derives the rule from `isPremium` columns.
//
// Locked content stays VISIBLE. Title, artwork, palette, duration, track count
// and lyric languages all still ship, because a visible-but-locked catalogue is
// what the paywall sells. What a locked track withholds is its playable URL.
//
// Be honest about what this protects. The files under /media are served
// statically to anyone holding a URL; there is no per-request check on the
// bytes. The protection is that we stop telling non-members what the premium
// URLs are. A URL that leaked (shared, logged, cached from a member's session)
// still plays. Signed, expiring media URLs are the follow-up if that matters.
import type { FastifyReply, FastifyRequest } from "fastify";
import { isRequestPremium } from "./entitlement.js";

/**
 * Whether the response being built is the unlocked view. Deliberately required
 * on every content serializer rather than defaulted: a default of "unlocked"
 * fails open the day a new route forgets it, and a default of "locked" quietly
 * breaks the admin panel. Making it required turns that into a compile error.
 */
export type ContentAccess = { readonly unlocked: boolean };

/** The admin panel's view: every URL, whatever the admin's own standing. */
export const ADMIN_ACCESS: ContentAccess = Object.freeze({ unlocked: true });

/** The view for a caller who is not DEEP Premium. */
export const LOCKED_ACCESS: ContentAccess = Object.freeze({ unlocked: false });

/**
 * A collection is locked iff it is premium and the caller is not.
 */
export function isCollectionLocked(
  collection: { isPremium: boolean },
  access: ContentAccess,
): boolean {
  return collection.isPremium && !access.unlocked;
}

/**
 * A track is locked iff it, or the collection it sits in, is premium and the
 * caller is not. A premium collection locks its free tracks too: the album is
 * the product.
 *
 * `collection` is null only where the parent is genuinely not at hand (an
 * admin write echoing a staged track). That case fails CLOSED for a locked
 * view: a track whose parent we did not look at is never handed out on the
 * assumption that the parent is free.
 */
export function isTrackLocked(
  track: { isPremium: boolean },
  collection: { isPremium: boolean } | null,
  access: ContentAccess,
): boolean {
  if (access.unlocked) return false;
  if (collection === null) return true;
  return track.isPremium || collection.isPremium;
}

/**
 * A plant is locked iff it is premium, the caller is not, and the caller has
 * never grown it. Grandfathering: once someone has a progress row on a plant
 * it stays theirs to select forever, through any lapse. This is a one-way door
 * — it is generous and correct, and it cannot quietly be taken back later.
 */
export function isPlantLocked(
  plant: { isPremium: boolean },
  access: ContentAccess,
  hasProgress: boolean,
): boolean {
  return plant.isPremium && !access.unlocked && !hasProgress;
}

/**
 * The caller's content access, from the per-request entitlement accessor.
 * Needs `req.auth` set by an auth preHandler (optionalAuth for public routes);
 * an anonymous caller is never unlocked.
 */
export async function requestContentAccess(req: FastifyRequest): Promise<ContentAccess> {
  return { unlocked: await isRequestPremium(req) };
}

/**
 * Marks a response whose body depends on who is asking. There is no CDN in
 * this stack today, but the iOS URL cache (or any shared cache) would
 * otherwise serve one person's unlocked body to the next caller.
 */
export function markVariesByCaller(reply: FastifyReply): void {
  reply.header("Cache-Control", "no-store");
  // Merged, not overwritten: @fastify/cors may already have set `Vary: Origin`.
  const existing = reply.getHeader("Vary");
  const values = (Array.isArray(existing) ? existing.join(",") : String(existing ?? ""))
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
  if (!values.some((v) => v.toLowerCase() === "authorization")) values.push("Authorization");
  reply.header("Vary", values.join(", "));
}
