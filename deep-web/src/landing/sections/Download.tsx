// The closing invitation: the atmosphere, one large orb breathing slowly, and word of when DEEP arrives.
// DEEP isn't on any store yet, so nothing here is a button; store links replace the note at launch.
import type { CSSProperties } from 'react'
import { Atmosphere, LogoMark, useBloom } from '../components/shared.tsx'
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
            Soon, whenever you’d like to come back to this feeling, DEEP will be waiting on your phone. A
            breath, a pause with the world, a plant that grows with you.
          </p>
          <p className="dl-soon bloom" style={{ '--bloom-delay': '300ms' } as CSSProperties}>
            Coming soon to iPhone and Android
          </p>
        </div>
      </div>
    </section>
  )
}
