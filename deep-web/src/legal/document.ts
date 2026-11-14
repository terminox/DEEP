// The shape of a legal document, and the few facts every document shares. The words live in
// privacy.ts, terms.ts and deleteAccount.ts, one object per language.

export const languages = ['en', 'th'] as const
export type Language = (typeof languages)[number]

export const languageNames: Record<Language, string> = { en: 'English', th: 'ไทย' }

export type Section = {
  heading: string
  paragraphs?: string[]
  bullets?: string[]
}

export type LegalDocument = {
  title: string
  updated: string
  intro: string
  sections: Section[]
}

export type Localized = Record<Language, LegalDocument>

/** Facts every document shares, confirmed by the client. */
export const site = {
  operator: 'DEEP PEACE COMPANY LIMITED',
  address: {
    en: '15/134 Soi Sukhumvit 48, Phra Khanong Subdistrict, Khlong Toei District, Bangkok 10110, Thailand',
    th: '15/134 ซอยสุขุมวิท 48 แขวงพระโขนง เขตคลองเตย กรุงเทพฯ 10110',
  } satisfies Record<Language, string>,
  supportEmail: 'support@deeppeace.space',
  /** Cloud SQL keeps 7 daily backups, so a deleted record leaves them within 7 days. */
  backupDays: '7',
  /** While true, every page says it is a draft. Set it back to true while a revision awaits sign-off. */
  isDraft: false,
}
