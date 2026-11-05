// One quiet column for every legal document: the mark home, the language switch, then the words.
import { useEffect, useState } from 'react'
import { LogoMark, Wordmark } from '../landing/components/shared.tsx'
import { languageNames, languages, site, type Language, type Localized } from './document.ts'
import './legal.css'

const initialLanguage = (): Language => {
  const asked = new URLSearchParams(window.location.search).get('lang')
  if (asked === 'th' || asked === 'en') return asked
  return navigator.language.toLowerCase().startsWith('th') ? 'th' : 'en'
}

const draftNote: Record<Language, string> = {
  en: 'Draft for review. Not yet in effect.',
  th: 'ฉบับร่างเพื่อตรวจทาน ยังไม่มีผลบังคับใช้',
}

export default function LegalPage({ content }: { content: Localized }) {
  const [language, setLanguage] = useState(initialLanguage)
  const document_ = content[language]

  useEffect(() => {
    document.documentElement.lang = language
    document.title = `${document_.title} | DEEP`
  }, [language, document_.title])

  return (
    <div className="legal">
      <header className="legal-top">
        <a className="legal-home" href="/" aria-label="DEEP, home">
          <LogoMark size={26} />
          <Wordmark className="legal-wordmark" />
        </a>
        <nav className="legal-languages" aria-label="Language">
          {languages.map((option) => (
            <button
              key={option}
              type="button"
              lang={option}
              aria-pressed={option === language}
              onClick={() => setLanguage(option)}
            >
              {languageNames[option]}
            </button>
          ))}
        </nav>
      </header>

      <main className="legal-body">
        {site.isDraft && <p className="legal-draft">{draftNote[language]}</p>}
        <h1>{document_.title}</h1>
        <p className="legal-updated">{document_.updated}</p>
        <p className="legal-intro">{document_.intro}</p>

        {document_.sections.map((section) => (
          <section key={section.heading}>
            <h2>{section.heading}</h2>
            {section.paragraphs?.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
            {section.bullets && (
              <ul>
                {section.bullets.map((bullet) => (
                  <li key={bullet}>{bullet}</li>
                ))}
              </ul>
            )}
          </section>
        ))}
      </main>

      <footer className="legal-foot">
        <a href="/privacy">Privacy</a>
        <a href="/terms">Terms</a>
        <a href="/delete-account">Delete account</a>
        <a href={`mailto:${site.supportEmail}`}>Contact</a>
      </footer>
    </div>
  )
}
