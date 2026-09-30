// A floating frosted capsule. It rests wide over the hero, then settles into a tighter glass pill
// once the page moves. On phones the links fold into a small sheet.
import { useEffect, useState } from 'react'
import { LogoMark, Wordmark } from '../components/shared.tsx'
import { sections } from '../storyOrder.ts'
import './Nav.css'

export default function Nav() {
  const [condensed, setCondensed] = useState(false)
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState<string | null>(null)

  useEffect(() => {
    const onScroll = () => setCondensed(window.scrollY > 40)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  // The section occupying the middle band of the viewport is the one we're "in".
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) if (entry.isIntersecting) setActive(entry.target.id)
      },
      { rootMargin: '-45% 0px -50% 0px' },
    )
    for (const { id } of sections) {
      const el = document.getElementById(id)
      if (el) observer.observe(el)
    }
    const hero = document.getElementById('top')
    if (hero) observer.observe(hero)
    return () => observer.disconnect()
  }, [])

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open])

  return (
    <nav className={`nav${condensed ? ' is-condensed' : ''}${open ? ' is-open' : ''}`} aria-label="Main">
      <div className="nav-bar">
        <a className="nav-brand" href="#top" aria-label="DEEP, back to top" onClick={() => setOpen(false)}>
          <LogoMark size={26} />
          <Wordmark className="nav-wordmark" />
        </a>

        <ul className="nav-links">
          {sections.map(({ id, label }) => (
            <li key={id}>
              <a href={`#${id}`} className={active === id ? 'is-active' : undefined} aria-current={active === id ? 'true' : undefined}>
                {label}
              </a>
            </li>
          ))}
        </ul>

        <button
          className="nav-toggle"
          type="button"
          aria-expanded={open}
          aria-controls="nav-sheet"
          aria-label={open ? 'Close menu' : 'Open menu'}
          onClick={() => setOpen(!open)}
        >
          <span />
          <span />
        </button>
      </div>

      <div className="nav-sheet" id="nav-sheet" hidden={!open}>
        <ul>
          {sections.map(({ id, label }) => (
            <li key={id}>
              <a href={`#${id}`} onClick={() => setOpen(false)}>
                {label}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </nav>
  )
}
