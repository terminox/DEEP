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

/** Facts only the client can confirm. Every use reads "[...]" until they do. */
export const site = {
  operator: '[Client legal name]',
  address: '[Client registered address]',
  supportEmail: 'support@deeppeace.space',
  backupDays: '[N]',
  /** While true, every page says so. Set false only once the client has signed off the text. */
  isDraft: true,
}
