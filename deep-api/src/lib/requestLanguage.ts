import { AsyncLocalStorage } from "node:async_hooks";

// The languages the catalogue is translated into. English is the source, so it
// is not a translation target — a request for it resolves to the base columns.
export const SUPPORTED_LANGUAGES = ["th"] as const;
export type SupportedLanguage = (typeof SUPPORTED_LANGUAGES)[number];

/**
 * The language the current request should be answered in, or null for English.
 *
 * Carried in async-local storage rather than threaded through every serializer,
 * exactly as `requestBaseUrl` carries the origin for media URLs — the
 * serializers are deep, synchronous and numerous, and an extra parameter on
 * each would be noise at every call site.
 */
export const requestLanguage = new AsyncLocalStorage<SupportedLanguage | null>();

/** The language for this request, or null when English should be served. */
export function currentLanguage(): SupportedLanguage | null {
  return requestLanguage.getStore() ?? null;
}

/**
 * Picks a supported language out of an `Accept-Language` header.
 *
 * Deliberately small: the header is a quality-ordered list, and Deep only has
 * one translation, so the question is just "does Thai out-rank English here".
 * Anything unparseable falls through to English rather than throwing — a
 * malformed header should degrade, not fail the request.
 */
export function negotiateLanguage(header: string | undefined): SupportedLanguage | null {
  if (!header) return null;

  const ranked = header
    .split(",")
    .map((part) => {
      const [tag = "", ...params] = part.trim().split(";");
      const q = params
        .map((p) => p.trim())
        .find((p) => p.startsWith("q="))
        ?.slice(2);
      const parsed = q === undefined ? 1 : Number.parseFloat(q);
      // An unparseable weight means the header is malformed, not that the
      // client refused the language — treat it as unweighted rather than
      // silently dropping a language they did ask for. Only an explicit q=0
      // excludes.
      const quality = Number.isFinite(parsed) ? parsed : 1;
      return {
        // "th-TH" and "TH" both mean Thai; compare on the primary subtag.
        base: tag.trim().toLowerCase().split("-")[0] ?? "",
        quality,
      };
    })
    .filter((entry) => entry.quality > 0)
    .sort((a, b) => b.quality - a.quality);

  for (const entry of ranked) {
    if (entry.base === "*") return null;
    if ((SUPPORTED_LANGUAGES as readonly string[]).includes(entry.base)) {
      return entry.base as SupportedLanguage;
    }
    // A higher-ranked language we do not translate into means English wins.
    if (entry.base === "en") return null;
  }
  return null;
}
