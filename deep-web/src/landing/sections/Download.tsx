// The closing invitation: the twilight of the primary button grown to a whole card, the mark,
// one line, and the store badges.
import type { CSSProperties } from 'react'
import { LogoMark, useBloom } from '../components/shared.tsx'
import { StoreBadges } from '../components/StoreBadges.tsx'
import './Download.css'

const delay = (ms: number) => ({ '--bloom-delay': `${ms}ms` }) as CSSProperties

export default function Download() {
  const ref = useBloom<HTMLElement>()

  return (
    <section className="dl" id="download" aria-labelledby="dl-title" ref={ref}>
      <div className="dl-stage">
        <div className="dl-content">
          <div className="bloom" aria-hidden="true">
            <LogoMark size="var(--dl-mark)" glow tint="var(--moon-cream)" />
          </div>

          <h2 className="dl-title bloom" id="dl-title" style={delay(120)}>
            Take your first breath <em>with us.</em>
          </h2>

          <StoreBadges balanced className="dl-badges bloom" style={delay(240)} />
        </div>
      </div>
    </section>
  )
}
