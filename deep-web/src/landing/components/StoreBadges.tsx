// The way in: Apple's and Google's official store badges, used unmodified as their guidelines
// require. A section sizes the pair by setting `--badge` (the artwork height) on or above it.
import type { CSSProperties } from 'react'
import './StoreBadges.css'

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

export function StoreBadges({
  className,
  style,
  balanced,
}: {
  className?: string
  style?: CSSProperties
  /** For centred layouts: the gap between the badges sits on the centre line. */
  balanced?: boolean
}) {
  return (
    <ul
      className={`store-badges${balanced ? ' store-badges--balanced' : ''}${className ? ` ${className}` : ''}`}
      style={style}
    >
      {stores.map(({ id, href, badge, label }) => (
        <li key={id}>
          <a className={`store-badge store-badge--${id}`} href={href} target="_blank" rel="noopener">
            <img src={badge} alt={label} />
          </a>
        </li>
      ))}
    </ul>
  )
}
