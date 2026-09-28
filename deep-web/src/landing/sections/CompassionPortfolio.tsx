// Compassion Portfolio: the iOS portfolio home (CompassionPortfolioHomeView.swift) as a landing moment.
// Mine, then ours: the day's halo around your balance, the community pool ring, the causes shelf,
// and one dispatch from the field. Every figure here is sample state, and says so.
import { useCallback, useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { Atmosphere, SectionHead, prefersReducedMotion, useBloom, useInView } from '../components/shared.tsx'
import './CompassionPortfolio.css'

// MARK: Palettes (ArtworkPalette.swift single-hue ramps, seated on deepPlum)

const deepen = (token: string, from: number, to: number) => [
  from === 0 ? `var(${token})` : `color-mix(in srgb, var(${token}), var(--deep-plum) ${from}%)`,
  `color-mix(in srgb, var(${token}), var(--deep-plum) ${to}%)`,
]

const palettes = {
  dusk: ['var(--lavender-mist)', 'var(--blush-powder)'],
  iris: deepen('--lavender-mist', 22, 34),
  petal: deepen('--blush-powder', 0, 12),
  hearth: deepen('--peach-cloud', 0, 12),
  veil: deepen('--soft-lilac', 0, 8),
  shore: deepen('--sky-wash', 0, 12),
} as const

type Palette = keyof typeof palettes

/** SoundArtwork: palette linear top-leading to bottom-trailing, a plum vignette in the far corner. */
const artwork = (palette: Palette): CSSProperties => ({
  backgroundImage: `radial-gradient(circle at 100% 100%, rgb(from var(--deep-plum) r g b / 0.12), transparent 240px), linear-gradient(to bottom right, ${palettes[palette].join(', ')})`,
})

// MARK: Glyphs (white, drawn on a 24 grid)

type GlyphName = 'heart' | 'bird' | 'cross' | 'book' | 'leaf' | 'hands' | 'pin' | 'pie'

const HEART = 'M12 20.6c-.3 0-.6-.1-.8-.3C8.4 18 3 13.9 3 9.1 3 6.3 5.1 4.2 7.7 4.2c1.8 0 3.3.9 4.3 2.4 1-1.5 2.5-2.4 4.3-2.4C18.9 4.2 21 6.3 21 9.1c0 4.8-5.4 8.9-8.2 11.2-.2.2-.5.3-.8.3z'

function Glyph({ name, className }: { name: GlyphName; className?: string }) {
  const shapes: Record<GlyphName, ReactNode> = {
    heart: <path d={HEART} />,
    bird: (
      <>
        <path d="M2.8 12.6c2.9.9 5.6.2 7.4-1.9l2.2-2.6c.9-1.1 2.1-1.7 3.4-1.7 1 0 1.9.4 2.5 1l2.6.3-2 1.4c0 4.1-2.8 7.4-7 8.1l-3.3 2.5.6-2.6c-3.3-.4-5.7-2.2-6.4-4.5z" />
        <path d="M9.6 10.4C8.4 7.6 8.8 4.9 10.5 3c1 2.3 2.2 4 3.6 5.1l-1.7 2.1c-.8 1-1.7 1.3-2.8.2z" opacity="0.85" />
      </>
    ),
    cross: <path d="M10 3.5h4c.6 0 1 .4 1 1V9h4.5c.6 0 1 .4 1 1v4c0 .6-.4 1-1 1H15v4.5c0 .6-.4 1-1 1h-4c-.6 0-1-.4-1-1V15H4.5c-.6 0-1-.4-1-1v-4c0-.6.4-1 1-1H9V4.5c0-.6.4-1 1-1z" />,
    book: (
      <>
        <path d="M11.2 6.4C9.2 5 6.6 4.5 3.6 4.7c-.4 0-.6.3-.6.7v11.8c0 .4.3.7.7.7 2.9-.1 5.3.4 7.5 1.8z" />
        <path d="M12.8 6.4c2-1.4 4.6-1.9 7.6-1.7.4 0 .6.3.6.7v11.8c0 .4-.3.7-.7.7-2.9-.1-5.3.4-7.5 1.8z" />
      </>
    ),
    leaf: (
      <path d="M5.2 19.6c-.4.4-1 .4-1.4 0s-.4-1 0-1.4l1.5-1.5C4.6 9.4 10.1 4.2 19.8 3.6c.4 0 .7.3.6.7-.5 9.8-5.9 15.2-13.3 14.3l-1.9 1zm2.4-3.8c2.4-3 5.2-5.3 8.3-7-3.6 1.1-6.6 3.4-8.9 6.4z" fillRule="evenodd" />
    ),
    hands: (
      <>
        <path d="M2.6 12.2c0-.8.9-1.3 1.6-.8l3.2 2.3c1 .7 2.2 1.1 3.4 1.1h2.4c1.2 0 2.4-.4 3.4-1.1l3.2-2.3c.7-.5 1.6 0 1.6.8 0 4.3-3.5 7.8-7.8 7.8h-3.2c-4.3 0-7.8-3.5-7.8-7.8z" />
        <path d="M12 12.6c-.2 0-.3 0-.4-.1-1.5-1.2-4.1-3.1-4.1-5.4 0-1.4 1.1-2.5 2.4-2.5.9 0 1.6.4 2.1 1.1.5-.7 1.2-1.1 2.1-1.1 1.3 0 2.4 1.1 2.4 2.5 0 2.3-2.6 4.2-4.1 5.4-.1.1-.2.1-.4.1z" />
      </>
    ),
    pin: (
      <path d="M12 21.2c-.3 0-.5-.1-.7-.3C8.6 18.2 5.5 14.6 5.5 10.5a6.5 6.5 0 0 1 13 0c0 4.1-3.1 7.7-5.8 10.4-.2.2-.4.3-.7.3zm0-8.2a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z" fillRule="evenodd" />
    ),
    pie: <path d="M11 3.1v9.9h9.9A9 9 0 1 1 11 3.1zm2-.1a9 9 0 0 1 8 8h-8z" fillRule="evenodd" />,
  }
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      {shapes[name]}
    </svg>
  )
}

/** CompassionMotif: the gradient artwork with its glyph floating in soft white on top. */
function Motif({
  glyph,
  palette,
  className = '',
  shadow = true,
}: {
  glyph: GlyphName
  palette: Palette
  className?: string
  shadow?: boolean
}) {
  return (
    <span className={`cp-motif ${className}`} style={artwork(palette)} aria-hidden="true">
      <Glyph name={glyph} className={`cp-motif-glyph${shadow ? '' : ' cp-motif-glyph--flat'}`} />
    </span>
  )
}

// MARK: Sample ledger (CompassionLibrary.swift, with partners left unnamed)

type Cause = {
  id: string
  name: string
  tagline: string
  glyph: GlyphName
  palette: Palette
  hearts: number
}

const causes: Cause[] = [
  { id: 'peace', name: 'Peace & Well-being', tagline: 'Calmer minds, a kinder world', glyph: 'bird', palette: 'iris', hearts: 18_520 },
  { id: 'health', name: 'Healthcare', tagline: 'Caring for health and well-being', glyph: 'cross', palette: 'petal', hearts: 16_240 },
  { id: 'education', name: 'Education', tagline: 'Empowering minds, building tomorrow', glyph: 'book', palette: 'hearth', hearts: 14_180 },
  { id: 'nature', name: 'Nature', tagline: 'Protecting nature for future generations', glyph: 'leaf', palette: 'veil', hearts: 12_450 },
  { id: 'community', name: 'Community', tagline: 'Stronger communities, brighter futures', glyph: 'hands', palette: 'shore', hearts: 11_610 },
]

const DAILY_CEILING = 30
const START = { balance: 42, given: 318, today: 21 }

const fmt = (n: number) => n.toLocaleString('en-US')
const compact = (n: number) => new Intl.NumberFormat('en-US', { notation: 'compact' }).format(n)

// MARK: Pieces

/** HeartDayHalo: today's arc (lavender into blush, round caps) around the heart portrait. */
function HeartDayHalo({ progress, isFull }: { progress: number; isFull: boolean }) {
  const r = 50 - 3.5
  return (
    <div className={`cp-halo${isFull ? ' is-full' : ''}`}>
      <svg className="cp-halo-ring" viewBox="0 0 100 100" aria-hidden="true">
        <defs>
          <linearGradient id="cp-day" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="var(--lavender-mist)" />
            <stop offset="1" stopColor="var(--blush-powder)" />
          </linearGradient>
          <filter id="cp-day-bloom" x="-30%" y="-30%" width="160%" height="160%">
            <feGaussianBlur stdDeviation="2.4" />
          </filter>
        </defs>
        <circle className="cp-ring-track" cx="50" cy="50" r={r} strokeWidth="5" />
        <g transform="rotate(-90 50 50)">
          <circle
            className="cp-halo-arc cp-halo-arc--bloom"
            cx="50"
            cy="50"
            r={r}
            pathLength={1}
            strokeWidth="5"
            stroke="url(#cp-day)"
            filter="url(#cp-day-bloom)"
            style={{ strokeDasharray: `${progress} 1` }}
          />
          <circle
            className="cp-halo-arc"
            cx="50"
            cy="50"
            r={r}
            pathLength={1}
            strokeWidth="5"
            stroke="url(#cp-day)"
            style={{ strokeDasharray: `${progress} 1` }}
          />
        </g>
      </svg>
      <span className="cp-halo-pulse" aria-hidden="true" />
      <Motif glyph="heart" palette="dusk" className="cp-halo-portrait" />
    </div>
  )
}

/** CompassionRing: gradient arcs on a faint track, cap-corrected so every gap survives the round caps. */
function PoolRing({ shares, drawn }: { shares: number[]; drawn: boolean }) {
  const lineWidth = 9
  const r = 50 - lineWidth / 2
  const gap = 0.016
  const capBleed = lineWidth / 2 / (2 * Math.PI * r)
  const inset = shares.length > 1 ? gap / 2 + capBleed : 0
  let start = 0
  const arcs = shares.map((share, i) => {
    const from = start + inset
    const to = Math.max(from, start + share - inset)
    start += share
    return { from, length: to - from, palette: causes[i].palette }
  })

  const renderArcs = (bloom: boolean) =>
    arcs.map((arc, i) => (
      <circle
        key={i}
        className="cp-pool-arc"
        cx="50"
        cy="50"
        r={r}
        pathLength={1}
        strokeWidth={lineWidth}
        stroke={`url(#cp-arc-${i})`}
        style={{
          strokeDasharray: `${drawn ? arc.length : 0} 1`,
          strokeDashoffset: -arc.from,
          transitionDelay: `${i * 160}ms`,
        }}
        filter={bloom ? 'url(#cp-pool-bloom)' : undefined}
      />
    ))

  return (
    <svg className="cp-pool-ring" viewBox="0 0 100 100" aria-hidden="true">
      <defs>
        {arcs.map((arc, i) => (
          <linearGradient key={i} id={`cp-arc-${i}`} x1="0" y1="0" x2="100" y2="100" gradientUnits="userSpaceOnUse">
            <stop offset="0" stopColor={palettes[arc.palette][0]} />
            <stop offset="1" stopColor={palettes[arc.palette][1]} />
          </linearGradient>
        ))}
        <filter id="cp-pool-bloom" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="3" />
        </filter>
      </defs>
      <circle className="cp-ring-track" cx="50" cy="50" r={r} strokeWidth={lineWidth} />
      <g transform="rotate(-90 50 50)">
        <g opacity="0.5">{renderArcs(true)}</g>
        {renderArcs(false)}
      </g>
    </svg>
  )
}

function CauseTile({
  cause,
  hearts,
  share,
  received,
  onGive,
  bannerRef,
  delay,
}: {
  cause: Cause
  hearts: number
  share: number
  received: number
  onGive: (id: string) => void
  bannerRef: (el: HTMLSpanElement | null) => void
  delay: number
}) {
  const tint = palettes[cause.palette][0]
  return (
    <article
      className="cp-tile frosted bloom"
      style={{ '--bloom-delay': `${delay}ms`, '--cp-tint': tint } as CSSProperties}
    >
      <span className="cp-tile-banner" ref={bannerRef} style={artwork(cause.palette)} aria-hidden="true">
        <Glyph name={cause.glyph} className="cp-tile-glyph" />
        {received > 0 && <span key={received} className="cp-tile-pulse" />}
      </span>
      <div className="cp-tile-body">
        <h4 className="cp-tile-name">{cause.name}</h4>
        <p className="cp-tile-tagline">{cause.tagline}</p>
        <div className="cp-tile-facts">
          <span className="cp-fact">
            <Glyph name="heart" className="cp-fact-glyph cp-fact-glyph--blush" />
            <span key={hearts} className="cp-count">
              {fmt(hearts)} hearts
            </span>
          </span>
          <span className="cp-fact">
            <Glyph name="pie" className="cp-fact-glyph cp-fact-glyph--lavender" />
            <span>{Math.round(share * 100)}% of giving</span>
          </span>
        </div>
        <button type="button" className="cp-give" onClick={() => onGive(cause.id)}>
          <Glyph name="heart" className="cp-give-glyph" />
          Give a heart
        </button>
      </div>
    </article>
  )
}

// MARK: Section

type Flight = { key: number; from: { x: number; y: number }; to: { x: number; y: number }; target: string }

export default function CompassionPortfolio() {
  const rootRef = useBloom<HTMLElement>()
  const haloRef = useRef<HTMLDivElement>(null)
  const poolRef = useRef<HTMLDivElement>(null)
  const shelfRef = useRef<HTMLDivElement>(null)
  const bannerRefs = useRef<Record<string, HTMLSpanElement | null>>({})
  const travellerRef = useRef<HTMLSpanElement>(null)

  const haloInView = useInView(haloRef, '0px 0px -20% 0px')
  const poolInView = useInView(poolRef, '0px 0px -15% 0px')
  const shelfInView = useInView(shelfRef, '0px 0px -30% 0px')

  const [ledger, setLedger] = useState(START)
  const [pooled, setPooled] = useState<Record<string, number>>(() =>
    Object.fromEntries(causes.map((c) => [c.id, c.hearts])),
  )
  const [received, setReceived] = useState<Record<string, number>>({})
  const [dayShown, setDayShown] = useState(false)
  const [poolDrawn, setPoolDrawn] = useState(false)
  const [flight, setFlight] = useState<Flight | null>(null)
  const signatureDone = useRef(false)
  const flightKey = useRef(0)
  const flightRef = useRef<Flight | null>(null)
  const ledgerRef = useRef(START)

  useEffect(() => {
    if (haloInView) setDayShown(true)
  }, [haloInView])

  useEffect(() => {
    if (poolInView) setPoolDrawn(true)
  }, [poolInView])

  const land = useCallback((id: string) => {
    setPooled((p) => ({ ...p, [id]: p[id] + 1 }))
    setReceived((r) => ({ ...r, [id]: (r[id] ?? 0) + 1 }))
  }, [])

  /** One heart leaves the balance for a cause: from the halo if both are on screen, else it settles in from above. */
  const give = useCallback(
    (id: string) => {
      if (flightRef.current || ledgerRef.current.balance <= 0) return
      const l = ledgerRef.current
      ledgerRef.current = { ...l, balance: l.balance - 1, given: l.given + 1 }
      setLedger(ledgerRef.current)
      const root = rootRef.current
      const banner = bannerRefs.current[id]
      const halo = haloRef.current
      if (!root || !banner || !halo || prefersReducedMotion()) {
        land(id)
        return
      }
      const base = root.getBoundingClientRect()
      const b = banner.getBoundingClientRect()
      const h = halo.getBoundingClientRect()
      const to = { x: b.left + b.width / 2 - base.left, y: b.top + b.height / 2 - base.top }
      const haloVisible = h.top > 40 && h.bottom < window.innerHeight - 20
      const from = haloVisible
        ? { x: h.left + h.width / 2 - base.left, y: h.top + h.height / 2 - base.top }
        : { x: to.x, y: to.y - 140 }
      flightKey.current += 1
      flightRef.current = { key: flightKey.current, from, to, target: id }
      setFlight(flightRef.current)
    },
    [land, rootRef],
  )

  // The signature: once the causes shelf is in view, the first heart of the day travels to Peace & Well-being.
  useEffect(() => {
    if (!shelfInView || signatureDone.current) return
    signatureDone.current = true
    const t = window.setTimeout(() => give(causes[0].id), 900)
    return () => window.clearTimeout(t)
  }, [shelfInView, give])

  // Fly the traveller along a soft arc (a quadratic curve sampled into keyframes).
  useEffect(() => {
    const el = travellerRef.current
    if (!flight || !el) return
    const { from, to } = flight
    const lift = Math.min(160, Math.max(60, Math.hypot(to.x - from.x, to.y - from.y) * 0.35))
    const ctrl = { x: (from.x + to.x) / 2 + (to.x < from.x ? 40 : -40), y: Math.min(from.y, to.y) - lift }
    const steps = 14
    const frames: Keyframe[] = []
    for (let i = 0; i <= steps; i++) {
      const t = i / steps
      const x = (1 - t) ** 2 * from.x + 2 * (1 - t) * t * ctrl.x + t ** 2 * to.x
      const y = (1 - t) ** 2 * from.y + 2 * (1 - t) * t * ctrl.y + t ** 2 * to.y
      const scale = 0.6 + Math.sin(t * Math.PI) * 0.55
      const opacity = t < 0.12 ? t / 0.12 : t > 0.88 ? (1 - t) / 0.12 : 1
      frames.push({ transform: `translate(${x}px, ${y}px) translate(-50%, -50%) scale(${scale})`, opacity, offset: t })
    }
    const anim = el.animate(frames, { duration: 2400, easing: 'cubic-bezier(0.3, 0, 0.2, 1)', fill: 'forwards' })
    anim.onfinish = () => {
      land(flight.target)
      flightRef.current = null
      setFlight(null)
    }
    return () => {
      anim.onfinish = null
      anim.cancel()
    }
  }, [flight, land])

  const total = Object.values(pooled).reduce((a, b) => a + b, 0)
  const shares = causes.map((c) => pooled[c.id] / total)
  const todayProgress = dayShown ? ledger.today / DAILY_CEILING : 0
  const peopleReached = 412_000

  return (
    <section id="compassion" className="cp" ref={rootRef}>
      <Atmosphere className="cp-atmosphere" />

      <div className="cp-inner">
        <div className="cp-head">
          <SectionHead
            eyebrow="Compassion Portfolio"
            lede="Every quiet minute you spend in Deep becomes a heart. Give your hearts to the causes you care about, and Deep donates real money to partner organisations in proportion to where the community's hearts have gone."
          >
            Make <em>real life</em> impacts
          </SectionHead>
        </div>

        {/* Mine */}
        <div className="cp-mine frosted bloom" style={{ '--bloom-delay': '120ms' } as CSSProperties}>
          <div ref={haloRef} className={`cp-mine-halo${flight ? ' is-sending' : ''}`}>
            <HeartDayHalo progress={todayProgress} isFull={ledger.today >= DAILY_CEILING} />
          </div>
          <div className="cp-mine-copy">
            <p className="cp-micro">My hearts</p>
            <p className="cp-balance">
              <span key={ledger.balance} className="cp-balance-num">
                {ledger.balance}
              </span>
              <span className="cp-balance-word">to give</span>
            </p>
            <p className="cp-fact">
              <Glyph name="heart" className="cp-fact-glyph cp-fact-glyph--blush" />
              <span>
                <strong key={ledger.given} className="cp-count">
                  {fmt(ledger.given)}
                </strong>{' '}
                given
              </span>
            </p>
            <p className="cp-fact">
              <Glyph name="heart" className="cp-fact-glyph cp-fact-glyph--rose" />
              <span>
                <strong>{ledger.today}</strong> of {DAILY_CEILING} today
              </span>
            </p>
          </div>
        </div>

        {/* Ours */}
        <div ref={poolRef} className="cp-pool frosted bloom" style={{ '--bloom-delay': '220ms' } as CSSProperties}>
          <p className="cp-micro">The community pool</p>
          <div className="cp-pool-halo" role="img" aria-label={`${fmt(total)} hearts pooled`}>
            <PoolRing shares={shares} drawn={poolDrawn} />
            <div className="cp-pool-centre">
              <Glyph name="heart" className="cp-pool-heart" />
              <span className="cp-pool-total">{compact(total)}</span>
            </div>
          </div>
          <ul className="cp-legend">
            {causes.map((c, i) => (
              <li key={c.id} className="cp-legend-row">
                <Motif glyph={c.glyph} palette={c.palette} className="cp-legend-chip" shadow={false} />
                <span className="cp-legend-name">{c.name}</span>
                <span className="cp-legend-share">{Math.round(shares[i] * 100)}%</span>
              </li>
            ))}
          </ul>
          <p className="cp-caption">
            {compact(peopleReached)} people reached across {causes.length} causes
          </p>
        </div>

        {/* Where your hearts go */}
        <div className="cp-causes" ref={shelfRef}>
          <h3 className="cp-subhead bloom">Where your hearts go</h3>
          <div className="cp-shelf" role="list">
            {causes.map((c, i) => (
              <div key={c.id} role="listitem" className="cp-shelf-item">
                <CauseTile
                  cause={c}
                  hearts={pooled[c.id]}
                  share={shares[i]}
                  received={received[c.id] ?? 0}
                  onGive={give}
                  bannerRef={(el) => {
                    bannerRefs.current[c.id] = el
                  }}
                  delay={120 + i * 90}
                />
              </div>
            ))}
          </div>
        </div>

        {/* What came back */}
        <div className="cp-field">
          <h3 className="cp-subhead bloom">What comes back</h3>
          <article className="cp-report frosted bloom" style={{ '--bloom-delay': '120ms' } as CSSProperties}>
            <Motif glyph="cross" palette="petal" className="cp-report-thumb" />
            <div className="cp-report-copy">
              <p className="cp-micro">Healthcare</p>
              <h4 className="cp-report-title">A mobile clinic reached the hill villages</h4>
              <p className="cp-report-blurb">
                A partner clinic in northern Thailand spent three days in the hills, bringing check-ups and
                medicine to families who live far from the nearest road.
              </p>
              <p className="cp-report-meta">
                <span className="cp-report-place">
                  <Glyph name="pin" className="cp-report-pin" />
                  Northern Thailand
                </span>
                <span>2 days ago</span>
              </p>
            </div>
          </article>
          <p className="cp-note bloom">
            The balances, totals and field report shown here are illustrative. In the app, field reports come back
            from the ground so you can see, plainly, where your hearts went.
          </p>
        </div>
      </div>

      {flight && (
        <span key={flight.key} ref={travellerRef} className="cp-traveller" aria-hidden="true">
          <Glyph name="heart" />
        </span>
      )}
    </section>
  )
}
