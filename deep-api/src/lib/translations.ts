import type { TranslatableEntity } from "@prisma/client";
import { prisma } from "../prisma.js";
import { currentLanguage, type SupportedLanguage } from "./requestLanguage.js";

/**
 * Translated copy, resolved synchronously.
 *
 * `serialize.ts` is entirely synchronous and is called once per row of a tree —
 * a sound home response alone walks five categories, twenty collections and
 * sixty-seven tracks. Querying per field there would be an N+1 on every
 * request, and making the serializers async would turn a pure projection layer
 * into an awaited one for the sake of a lookup.
 *
 * So the whole catalogue for a language is held in memory instead. It is tiny —
 * a few hundred short strings — read on almost every request and written only
 * when an admin publishes, which is exactly the shape a process-local cache
 * suits. The publish path calls `invalidateTranslations()`; a short TTL is the
 * backstop for anything that writes around it.
 */

type FieldBag = Record<string, string>;
type LanguageCache = {
  loadedAt: number;
  /** "ENTITY:id" -> translated fields */
  byRecord: Map<string, FieldBag>;
};

const TTL_MS = 60_000;

const caches = new Map<SupportedLanguage, LanguageCache>();
/** In-flight loads, so a cold cache under concurrent requests queries once. */
const loading = new Map<SupportedLanguage, Promise<LanguageCache>>();

function key(entity: TranslatableEntity, entityId: string): string {
  return `${entity}:${entityId}`;
}

async function load(language: SupportedLanguage): Promise<LanguageCache> {
  const rows = await prisma.contentTranslation.findMany({
    where: { languageCode: language },
    select: { entity: true, entityId: true, fields: true },
  });

  const byRecord = new Map<string, FieldBag>();
  for (const row of rows) {
    if (row.fields && typeof row.fields === "object" && !Array.isArray(row.fields)) {
      byRecord.set(key(row.entity, row.entityId), row.fields as FieldBag);
    }
  }
  const cache: LanguageCache = { loadedAt: Date.now(), byRecord };
  caches.set(language, cache);
  return cache;
}

/**
 * Warms the cache for the request's language.
 *
 * Called once per request, before any serializer runs, so that `translate()`
 * below can stay synchronous. A failure here is not fatal: the catalogue simply
 * serves its English source columns.
 */
export async function primeTranslations(): Promise<void> {
  const language = currentLanguage();
  if (!language) return;

  const cached = caches.get(language);
  if (cached && Date.now() - cached.loadedAt < TTL_MS) return;

  let pending = loading.get(language);
  if (!pending) {
    pending = load(language).finally(() => loading.delete(language));
    loading.set(language, pending);
  }
  try {
    await pending;
  } catch {
    // Leave whatever was cached in place; English is the fallback either way.
  }
}

/**
 * The translated value for one field, or the English source when there is none.
 *
 * Every serializer calls this rather than reading the column directly, so a
 * record that has never been translated — or a language that has not been
 * primed — renders in English instead of blank.
 */
export function translate<T extends string | null>(
  entity: TranslatableEntity,
  entityId: string,
  field: string,
  source: T,
): T {
  const language = currentLanguage();
  if (!language) return source;

  const cache = caches.get(language);
  if (!cache) return source;

  const value = cache.byRecord.get(key(entity, entityId))?.[field];
  if (typeof value !== "string" || value.length === 0) return source;
  return value as T;
}

/** Drops cached copy so the next request reloads it. Called after a publish. */
export function invalidateTranslations(language?: SupportedLanguage): void {
  if (language) caches.delete(language);
  else caches.clear();
}

/** Test seam: lets a test assert on a known cache rather than the database. */
export function seedTranslationCache(
  language: SupportedLanguage,
  entries: Array<{ entity: TranslatableEntity; entityId: string; fields: FieldBag }>,
): void {
  const byRecord = new Map<string, FieldBag>();
  for (const entry of entries) {
    byRecord.set(key(entry.entity, entry.entityId), entry.fields);
  }
  caches.set(language, { loadedAt: Date.now(), byRecord });
}
