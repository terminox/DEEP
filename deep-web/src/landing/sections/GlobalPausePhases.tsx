// The three pinned visuals of Global Pause, one per phase: DJ Fuku's lounge, the live globe
// coming to rest, and the peace messages left afterwards. GlobalPause.tsx stacks them in its
// sticky frame and crossfades to the phase being read; its stylesheet styles them.
import { useEffect, useRef, useState, type CSSProperties } from 'react'
import { AmbientVideo, prefersReducedMotion } from '../components/shared.tsx'
import { GLOBE_FILL, GlassGlobe } from '../components/GlassGlobe.ts'

const countFormat = new Intl.NumberFormat()

// MARK: Lounge (DJFukuLoungeCard.swift; the set already hangs its own ON AIR sign)

export function FukuWindow({ active }: { active: boolean }) {
  return (
    <figure className="gp-fuku">
      <span className="gp-fuku-glow" aria-hidden="true" />
      <div className="gp-fuku-window">
        <AmbientVideo name="fuku-intro" className="gp-fuku-video" paused={!active} />
      </div>
      <figcaption className="gp-fuku-caption">DJ Fuku, your host in the lounge</figcaption>
    </figure>
  )
}

// MARK: Live (GlobalPauseMeditationView.swift)

/** How long the globe keeps drawing after its phase hands over, so it fades out still turning. */
const GLOBE_LINGER = 1200

function Globe({ active, resting, onJoin }: { active: boolean; resting: boolean; onJoin: () => void }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const overlayRef = useRef<HTMLCanvasElement>(null)
  const hitRef = useRef<HTMLDivElement>(null)
  const globeRef = useRef<GlassGlobe | null>(null)
  const [status, setStatus] = useState<'loading' | 'ready' | 'fallback'>('loading')
  const [running, setRunning] = useState(active)
  const joinRef = useRef(onJoin)
  joinRef.current = onJoin

  useEffect(() => {
    const canvas = canvasRef.current
    const overlay = overlayRef.current
    const hit = hitRef.current
    if (!canvas || !overlay || !hit) return
    const globe = GlassGlobe.create(canvas, overlay, {
      reducedMotion: prefersReducedMotion(),
      hitTarget: hit,
      onJoin: () => joinRef.current(),
      onReady: () => setStatus('ready'),
    })
    if (!globe) {
      setStatus('fallback')
      return
    }
    globeRef.current = globe
    const observer = new ResizeObserver(([entry]) => globe.resize(entry.contentRect.width))
    observer.observe(canvas)
    return () => {
      observer.disconnect()
      globe.destroy()
      globeRef.current = null
    }
  }, [])

  // Keeps drawing a moment past the handover, so the crossfade out isn't a frozen frame.
  useEffect(() => {
    if (active) {
      setRunning(true)
      return
    }
    const id = window.setTimeout(() => setRunning(false), GLOBE_LINGER)
    return () => window.clearTimeout(id)
  }, [active])

  useEffect(() => {
    const globe = globeRef.current
    if (!globe) return
    const sync = () => globe.setActive(running && document.visibilityState === 'visible')
    sync()
    document.addEventListener('visibilitychange', sync)
    return () => document.removeEventListener('visibilitychange', sync)
  }, [running, status])

  useEffect(() => {
    globeRef.current?.setResting(resting)
  }, [resting, status])

  return (
    <div className={`gp-globe gp-globe--${status}`} style={{ '--gp-fill': GLOBE_FILL } as CSSProperties}>
      <div className="gp-globe-halo" aria-hidden="true" />
      <div className="gp-globe-cradle" aria-hidden="true" />
      <div className="gp-globe-bloom" aria-hidden="true" />
      {status === 'fallback' && <div className="gp-globe-fallback" aria-hidden="true" />}
      <canvas ref={canvasRef} className="gp-globe-canvas" aria-hidden="true" />
      <canvas ref={overlayRef} className="gp-globe-ripples" aria-hidden="true" />
      <div
        ref={hitRef}
        className="gp-globe-hit"
        role="img"
        aria-label="A glass globe of the world, softly lit wherever someone is pausing"
      />
    </div>
  )
}

/**
 * The live meditation, deliberately near-empty: the LIVE capsule and the count of company above
 * the globe, the progress line below. The line fills as the chapter scrolls (`--gp-live`).
 */
export function LiveGlobe({ active }: { active: boolean }) {
  const [count, setCount] = useState(() => 12_400 + Math.floor(Math.random() * 600))
  return (
    <div className="gp-live">
      <div className="gp-live-head">
        <span className="gp-live-capsule gp-cascade" aria-label="Live meditation in progress">
          <span className="gp-live-dot" aria-hidden="true" />
          LIVE · Worldwide
        </span>
        <p className="gp-live-company gp-cascade" style={{ '--order': 1 } as CSSProperties}>
          <span key={count} className="gp-live-number">
            {countFormat.format(count)}
          </span>{' '}
          people are pausing with you
        </p>
      </div>
      <Globe active={active} resting={active} onJoin={() => setCount((c) => c + 1)} />
      <div className="gp-live-progress gp-cascade" style={{ '--order': 2 } as CSSProperties} aria-hidden="true">
        <span />
      </div>
    </div>
  )
}

// MARK: Peace messages (PeaceMessagesSection.swift, PeaceMessageCardChrome.swift)

type Message = {
  id: string
  name: string
  country: string
  text: string
  intention: 'Peace' | 'Healing' | 'Gratitude' | 'Someone I love'
  /** Minutes since it was left. */
  age: number
}

// The first five are the app's own fixtures (FixturePauseEventRepository.sampleMessages).
const messages: Message[] = [
  { id: 'fixture-1', name: 'Nan', country: 'TH', text: 'Peace for every quiet heart tonight.', intention: 'Peace', age: 60 },
  { id: 'fixture-2', name: 'Haruki', country: 'JP', text: 'Breathing with you all from Kyoto.', intention: 'Peace', age: 70 },
  { id: 'fixture-3', name: 'Camille', country: 'FR', text: 'Ce soir, le monde respire ensemble.', intention: 'Peace', age: 83 },
  { id: 'fixture-4', name: 'Luana', country: 'BR', text: 'Sending warmth from São Paulo.', intention: 'Someone I love', age: 93 },
  { id: 'fixture-5', name: 'Amara', country: 'KE', text: 'May stillness find whoever needs it.', intention: 'Healing', age: 105 },
  { id: 'web-1', name: 'Priya', country: 'IN', text: 'Thinking of my grandmother tonight. Rest easy.', intention: 'Someone I love', age: 4 },
  { id: 'web-2', name: 'Jonas', country: 'DE', text: 'Ich atme mit euch. Danke für diesen Moment.', intention: 'Gratitude', age: 9 },
  { id: 'web-3', name: 'Mateo', country: 'MX', text: 'Diez minutos de silencio, y ya no me siento solo.', intention: 'Gratitude', age: 16 },
  { id: 'web-4', name: 'Grace', country: 'AU', text: 'My first pause in weeks. I needed this more than I knew.', intention: 'Healing', age: 24 },
  { id: 'web-5', name: 'Minh', country: 'VN', text: 'Bình an cho tất cả mọi người.', intention: 'Peace', age: 38 },
]

/** PeaceMessageIdentity.tint: the id hashed into one of four tints, so a person's colour holds. */
const tints = ['var(--lavender-mist)', 'var(--blush-powder)', 'var(--sky-wash)', 'var(--peach-cloud)']
function tint(seed: string) {
  let hash = 0
  for (const byte of new TextEncoder().encode(seed)) hash = (Math.imul(hash, 31) + byte) | 0
  return tints[Math.abs(hash) % tints.length]
}

const regionNames = (() => {
  try {
    return new Intl.DisplayNames(undefined, { type: 'region' })
  } catch {
    return null
  }
})()
const relative = new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' })
const ago = (minutes: number) =>
  minutes < 60 ? relative.format(-minutes, 'minute') : relative.format(-Math.round(minutes / 60), 'hour')

function PeaceMessageCard({ message }: { message: Message }) {
  const place = regionNames?.of(message.country) ?? message.country
  return (
    <li className="gp-message">
      <div className="gp-message-who">
        <span className="gp-message-avatar" style={{ '--tint': tint(message.id) } as CSSProperties} aria-hidden="true">
          {message.name[0]}
        </span>
        <span className="gp-message-id">
          <span className="gp-message-name">{message.name}</span>
          <span className="gp-message-place">{place}</span>
        </span>
      </div>
      <p className="gp-message-text">“{message.text}”</p>
      <div className="gp-message-foot">
        <span className="gp-message-time">{ago(message.age)}</span>
        <span className="gp-message-tag">{message.intention}</span>
      </div>
    </li>
  )
}

/** Two columns of messages rising at different speeds; each list runs twice so the loop is seamless. */
export function PeaceDrift() {
  const columns = [messages.filter((_, i) => i % 2 === 0), messages.filter((_, i) => i % 2 === 1)]
  return (
    <div className="gp-peace">
      {columns.map((column, c) => (
        <div key={c} className={`gp-peace-column gp-peace-column--${c}`}>
          {[0, 1].map((copy) => (
            <ul key={copy} className="gp-peace-list" aria-hidden={copy === 1 || undefined}>
              {column.map((m) => (
                <PeaceMessageCard key={m.id} message={m} />
              ))}
            </ul>
          ))}
        </div>
      ))}
    </div>
  )
}
