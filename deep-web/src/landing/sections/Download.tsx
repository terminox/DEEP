// The closing invitation: the atmosphere, one large orb breathing slowly, and the way in.
import type { CSSProperties } from 'react'
import { Atmosphere, LogoMark, StoreBadges, useBloom } from '../components/shared.tsx'
import './Download.css'

export default function Download() {
  const ref = useBloom<HTMLElement>()

  return (
    <section className="dl" id="download" aria-labelledby="dl-title" ref={ref}>
      <div className="dl-stage">
        <Atmosphere />
        <div className="dl-orb" aria-hidden="true">
          <div className="dl-orb-body" />
        </div>

        <div className="dl-content">
          <div className="bloom">
            <LogoMark size={56} glow tint="var(--iris-dusk)" />
          </div>
          <h2 className="dl-title bloom" id="dl-title" style={{ '--bloom-delay': '100ms' } as CSSProperties}>
            You’re here now.
          </h2>
          <p className="lede bloom" style={{ '--bloom-delay': '200ms' } as CSSProperties}>
            Whenever you’d like to come back to this feeling, Deep is waiting on your phone. A breath, a
            pause with the world, a plant that grows with you.
          </p>
          <div className="bloom" style={{ '--bloom-delay': '300ms' } as CSSProperties}>
            <StoreBadges />
          </div>
        </div>
      </div>
    </section>
  )
}
