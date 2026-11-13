import { currentLanguage, type SupportedLanguage } from "./requestLanguage.js";

/** The Global Pause home's server-composed shelves, by their stable key. */
export type HomeSectionKey = "popular" | "today" | "forYou";

/**
 * The shelves' own names, in every language DEEP speaks.
 *
 * These are product copy written here, not catalogue rows an admin edits, so
 * they never pass through the content translation table. The Thai sits beside
 * the English instead, and the request's negotiated language picks one — both
 * apps render the title verbatim, so whatever is served here is what a member
 * reads.
 */
const SECTION_TITLES: Record<HomeSectionKey, { en: string } & Record<SupportedLanguage, string>> = {
  popular: { en: "Popular now", th: "ยอดนิยมตอนนี้" },
  today: { en: "Today's sessions", th: "เซสชันของวันนี้" },
  forYou: { en: "Made for you", th: "คัดมาเพื่อคุณ" },
};

/** A shelf's title in the current request's language, English when none was negotiated. */
export function homeSectionTitle(key: HomeSectionKey): string {
  const titles = SECTION_TITLES[key];
  const language = currentLanguage();
  return language ? titles[language] : titles.en;
}
