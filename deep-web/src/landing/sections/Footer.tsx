// A quiet close. Spacing does the separating; nothing here asks for anything.
import { LogoMark, Wordmark } from '../components/shared.tsx'
import { sections } from '../storyOrder.ts'
import './Footer.css'

const company = ['Privacy', 'Terms', 'Contact', 'Press']

export default function Footer() {
  return (
    <footer className="ft">
      <div className="ft-inner">
        <div className="ft-brand">
          <a className="ft-mark" href="#top" aria-label="Deep, back to top">
            <LogoMark size={30} />
            <Wordmark className="ft-wordmark" />
          </a>
          <p className="ft-manifesto">Pause. Breathe. Connect. Heal — together.</p>
        </div>

        <nav className="ft-cols" aria-label="Footer">
          <div>
            <p className="eyebrow">Inside Deep</p>
            <ul>
              {sections.map(({ id, label }) => (
                <li key={id}>
                  <a href={`#${id}`}>{label}</a>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <p className="eyebrow">Deep</p>
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

      <p className="ft-fine">© 2026 DEEP. Made slowly, with care.</p>
    </footer>
  )
}
