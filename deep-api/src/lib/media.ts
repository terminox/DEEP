import { AsyncLocalStorage } from "node:async_hooks";
import { env } from "../env.js";

/// The base URL of the request currently being served, scoped per-request by the
/// `onRequest` hook in app.ts. Lets media URLs come back on whatever host the
/// client actually used — localhost from the simulator, the Mac's `.local` name
/// from a physical device, a tunnel host — with no configuration.
export const requestBaseUrl = new AsyncLocalStorage<string>();

/// Projects a stored relative media path (e.g. "/media/audio/x.mp3") into the
/// absolute URL clients should fetch. Returns null for missing paths.
///
/// An explicit PUBLIC_BASE_URL always wins, so production is pinned to its real
/// origin and never trusts a client-supplied Host header. Leaving it unset (the
/// local-dev default) makes URLs follow the request.
export function mediaUrl(path: string | null | undefined): string | null {
  if (!path) return null;
  if (/^https?:\/\//i.test(path)) return path; // already absolute (e.g. Unsplash)
  const base = (
    env.PUBLIC_BASE_URL ??
    requestBaseUrl.getStore() ??
    `http://localhost:${env.PORT}`
  ).replace(/\/$/, "");
  const rel = path.startsWith("/") ? path : `/${path}`;
  return `${base}${rel}`;
}

// Exact inverse of mediaUrl(): collapses a self-origin absolute URL back to the
// relative /media/... path we store. Third-party URLs (Unsplash seed covers) are
// left absolute. Without this, an admin edit form that reseeds from the
// serialized (absolute) value would write this origin permanently into the row.
export function mediaPath(value: string): string {
  if (!/^https?:\/\//i.test(value)) return value;
  const bases = [env.PUBLIC_BASE_URL, requestBaseUrl.getStore(), `http://localhost:${env.PORT}`]
    .filter((b): b is string => Boolean(b))
    .map((b) => b.replace(/\/$/, ""));
  for (const base of bases) {
    if (value.startsWith(`${base}/media/`)) return value.slice(base.length);
  }
  return value;
}
