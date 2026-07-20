import { env } from "../env.js";

/// Projects a stored relative media path (e.g. "/media/audio/x.mp3") into the
/// absolute URL clients should fetch. Returns null for missing paths.
export function mediaUrl(path: string | null | undefined): string | null {
  if (!path) return null;
  if (/^https?:\/\//i.test(path)) return path; // already absolute (e.g. Unsplash)
  const base = env.PUBLIC_BASE_URL.replace(/\/$/, "");
  const rel = path.startsWith("/") ? path : `/${path}`;
  return `${base}${rel}`;
}
