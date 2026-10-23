// A quiet close. Spacing does the separating; nothing here asks for anything.
import { LogoMark, Tagline, Wordmark } from '../components/shared.tsx'
import { sections } from '../storyOrder.ts'
import './Footer.css'

const company = ['Privacy', 'Terms', 'Contact']

export default function Footer() {
  return (
    <footer className="ft">
      <div className="ft-inner">
        <div className="ft-brand">
          <a className="ft-mark" href="#top" aria-label="DEEP, back to top">
            <LogoMark size={30} />
            <Wordmark className="ft-wordmark" />
          </a>
          <p className="ft-manifesto">
            <Tagline className="ft-tagline" />
          </p>
        </div>

        <nav className="ft-cols" aria-label="Footer">
          <div>
            <p className="eyebrow">Inside DEEP</p>
            <ul>
              {sections.map(({ id, label }) => (
                <li key={id}>
                  <a href={`#${id}`}>{label}</a>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <p className="eyebrow">DEEP</p>
            <ul>
              {company.map((label) => (
                <li key={label}>
                  <a href="#">{label}</a>
                </li>
              ))}
            </ul>
          </div>
        </nav>
      </div>

      <p className="ft-fine">© 2026 DEEP.</p>
    </footer>
  )
}
