// The closing invitation: the atmosphere, one large orb breathing slowly, and the way in. The store
// badges are Apple's and Google's official artwork, used unmodified as their guidelines require.
import type { CSSProperties } from 'react'
import { Atmosphere, LogoMark, useBloom } from '../components/shared.tsx'
import './Download.css'

const stores = [
  {
    id: 'app-store',
    href: 'https://apps.apple.com/us/app/deep-peace-mental-wellness/id6834457133',
    badge: '/badges/app-store.svg',
    label: 'Download DEEP on the App Store',
  },
  {
    id: 'google-play',
    href: 'https://play.google.com/store/apps/details?id=space.deeppeace.app',
    badge: '/badges/google-play.png',
    label: 'Get DEEP on Google Play',
  },
] as const

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
            Whenever you’d like to come back to this feeling, DEEP is waiting on your phone. A breath, a
            pause with the world, a plant that grows with you.
          </p>
          <ul className="dl-badges bloom" style={{ '--bloom-delay': '300ms' } as CSSProperties}>
            {stores.map(({ id, href, badge, label }) => (
              <li key={id}>
                <a className={`dl-badge dl-badge--${id}`} href={href} target="_blank" rel="noopener">
                  <img src={badge} alt={label} />
                </a>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  )
}
