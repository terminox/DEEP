import path from "node:path";

// Locating media on disk, deliberately without importing env.ts.
//
// env.ts parses the whole environment at import time and requires JWT_SECRET,
// which prisma/seed.ts does not have: the migrate Job that runs it is given
// DATABASE_URL and nothing else (infra/components/service.ts). The seed needs
// to measure the meditation track, so this stays dependency-free.

/** Mirrored by env.ts's MEDIA_DIR default, which imports it from here. */
export const DEFAULT_MEDIA_DIR = "./media";

export function mediaRoot(): string {
  return process.env.MEDIA_DIR || DEFAULT_MEDIA_DIR;
}

/**
 * Where a `/media/...` reference lives on disk, or null when it isn't one of
 * ours to touch: an absolute third-party URL, or a path that escapes the root.
 */
export function resolveMediaFile(relPath: string | null | undefined): string | null {
  if (!relPath || !relPath.startsWith("/media/")) return null;
  const root = path.resolve(mediaRoot());
  const abs = path.resolve(root, relPath.slice("/media/".length));
  if (!abs.startsWith(root + path.sep)) return null; // traversal or outside root - refuse
  return abs;
}
