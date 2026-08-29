// The one definition of "sound content the app is allowed to see".
//
// Prisma's nested `include` filters do not cascade: without a `where` at every
// level, a visible collection under a hidden category still comes back. Both
// /sound/home and /pause/home load the identical tree, so they share this
// fragment rather than each carrying three where clauses that can drift apart.
//
// Note this is about VISIBILITY, not publication. Unpublished content has no
// row at all until an admin publishes it (see lib/drafts), so nothing here
// gates drafts - isActive exists to pull LIVE content down without deleting it.

export const VISIBLE_TRACKS = {
  where: { isActive: true },
  orderBy: { displayOrder: "asc" },
  include: { lyrics: { select: { languageCode: true } } },
} as const;

export const VISIBLE_COLLECTIONS = {
  where: { isActive: true },
  orderBy: { displayOrder: "asc" },
  include: { tracks: VISIBLE_TRACKS },
} as const;

/** Args for `prisma.soundCategory.findMany` returning the full visible tree. */
export const VISIBLE_CATEGORY_TREE = {
  where: { isActive: true },
  orderBy: { displayOrder: "asc" },
  include: { collections: VISIBLE_COLLECTIONS },
} as const;
