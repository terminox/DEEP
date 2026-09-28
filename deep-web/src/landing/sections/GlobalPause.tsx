// Global Pause: the one dark moment on the page. The iOS glass globe on its night sky, the next
// shared pause in the visitor's own hour, DJ Fuku's lounge, and the three quiet phases.
import { useEffect, useMemo, useRef, useState, type CSSProperties } from 'react'
import { AmbientVideo, prefersReducedMotion, useBloom, useInView } from '../components/shared.tsx'
import { GLOBE_FILL, GlassGlobe } from '../components/GlassGlobe.ts'
import './GlobalPause.css'

// MARK: Schedule

/** The evening session goes live at 20:40 in Bangkok (UTC+7, no daylight saving) = 13:40 UTC. */
const LIVE_UTC_HOUR = 13
const LIVE_UTC_MINUTE = 40
const MINUTE = 60_000
const LOUNGE_LEAD = 10 * MINUTE
const SESSION_LENGTH = 10 * MINUTE

type Phase = 'waiting' | 'lounge' | 'live'

function sessionState(now: number): { phase: Phase; start: number } {
  const today = new Date(now)
  today.setUTCHours(LIVE_UTC_HOUR, LIVE_UTC_MINUTE, 0, 0)
  const start = today.getTime()
  if (now >= start && now < start + SESSION_LENGTH) return { phase: 'live', start }
  if (now >= start - LOUNGE_LEAD && now < start) return { phase: 'lounge', start }
  return { phase: 'waiting', start: now < start ? start : start + 24 * 60 * MINUTE }
}

const localTime = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' })
const bangkokTime = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Bangkok' })
const countFormat = new Intl.NumberFormat()
const pad = (n: number) => String(n).padStart(2, '0')

function useNow(active: boolean) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    if (!active) return
    setNow(Date.now())
    const id = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(id)
  }, [active])
  return now
}

// MARK: Night sky (NightSkyBackground.swift)

type Star = { x: number; y: number; size: number; alpha: number; dim: number; period: number; delay: number; tint: string }

/** 90 seeded stars with the iOS defaults: 0.5–1.8pt cores, 0.3–1 alpha, 60% twinkle at ~0.5Hz. */
function makeStars(count = 90, seed = 1): Star[] {
  let s = seed + 0x5eed
  const rand = () => {
    s = (s + 0x6d2b79f5) | 0
    let t = Math.imul(s ^ (s >>> 15), 1 | s)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
  const cream = [251, 247, 255]
  const sky = [197, 216, 240]
  const lavender = [184, 167, 232]
  const cool = sky.map((c, i) => c + (lavender[i] - c) * 0.4)
  return Array.from({ length: count }, () => {
    const x = rand()
    const y = rand()
    const sizeT = rand()
    const brightT = rand()
    const jitter = 0.6 + rand() * 0.8
    const tintT = rand() * 0.5
    const twinkles = rand() < 0.6
    const fade = 1 - smooth(0.65, 1, y)
    const alpha = (0.3 + 0.7 * brightT) * fade
    const tint = cream.map((c, i) => Math.round(c + (cool[i] - c) * tintT)).join(' ')
    return {
      x,
      y,
      size: 0.5 + 1.3 * sizeT,
      alpha,
      dim: twinkles ? alpha * 0.5 : alpha,
      period: 1 / (0.5 * jitter),
      delay: -rand() * 4,
      tint,
    }
  })
}

function smooth(a: number, b: number, x: number) {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)))
  return t * t * (3 - 2 * t)
}

function NightSky() {
  const stars = useMemo(() => makeStars(), [])
  return (
    <div className="gp-sky" aria-hidden="true">
      <div className="gp-sky-horizon" />
      <div className="gp-stars">
        {stars.map((star, i) => (
          <span
            key={i}
            className="gp-star"
            style={
              {
                left: `${star.x * 100}%`,
                top: `${star.y * 100}%`,
                '--r': `${star.size}px`,
                '--a': star.alpha,
                '--a-dim': star.dim,
                '--tint': star.tint,
                animationDuration: `${star.period / 2}s`,
                animationDelay: `${star.delay}s`,
              } as CSSProperties
            }
          />
        ))}
      </div>
    </div>
  )
}

// MARK: Globe

function Globe({ onJoin }: { onJoin: () => void }) {
  const stageRef = useRef<HTMLDivElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const overlayRef = useRef<HTMLCanvasElement>(null)
  const hitRef = useRef<HTMLDivElement>(null)
  const globeRef = useRef<GlassGlobe | null>(null)
  const inView = useInView(stageRef, '120px')
  const [status, setStatus] = useState<'loading' | 'ready' | 'fallback'>('loading')
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

  useEffect(() => {
    const globe = globeRef.current
    if (!globe) return
    const sync = () => globe.setActive(inView && document.visibilityState === 'visible')
    sync()
    document.addEventListener('visibilitychange', sync)
    return () => document.removeEventListener('visibilitychange', sync)
  }, [inView, status])

  return (
    <div
      ref={stageRef}
      className={`gp-globe gp-globe--${status}`}
      style={{ '--gp-fill': GLOBE_FILL } as CSSProperties}
    >
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

// MARK: Live strip

function LiveStrip({ count }: { count: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const visible = useInView(ref)
  const now = useNow(visible)
  const { phase, start } = sessionState(now)
  const remaining = Math.max(0, start - now)
  const h = Math.floor(remaining / 3_600_000)
  const m = Math.floor((remaining % 3_600_000) / MINUTE)
  const s = Math.floor((remaining % MINUTE) / 1000)

  return (
    <div ref={ref} className="gp-live bloom" style={{ '--bloom-delay': '240ms' } as CSSProperties}>
      <div className="gp-live-when">
        {phase === 'live' ? (
          <>
            <span className="gp-pill gp-pill--live">
              <span className="gp-pill-dot" aria-hidden="true" />
              Live now
            </span>
            <p className="gp-live-note">The world is pausing. You can still slip in.</p>
          </>
        ) : (
          <>
            <span className="gp-pill">{phase === 'lounge' ? 'The lounge is open' : 'Next pause'}</span>
            <p className="gp-countdown" aria-label={`${h} hours ${m} minutes until the next pause`}>
              <span>{pad(h)}</span>
              <span className="gp-countdown-gap" aria-hidden="true" />
              <span>{pad(m)}</span>
              <span className="gp-countdown-gap" aria-hidden="true" />
              <span>{pad(s)}</span>
            </p>
            <p className="gp-live-note">
              At {localTime.format(start)} your time, {bangkokTime.format(start)} in Bangkok
            </p>
          </>
        )}
      </div>
      <p className="gp-live-count">
        <span key={count} className="gp-live-number">
          {countFormat.format(count)}
        </span>
        <span className="gp-live-label">people pausing with you</span>
      </p>
    </div>
  )
}

// MARK: Section

const phases = [
  {
    offset: -LOUNGE_LEAD,
    title: 'The lounge opens',
    body: 'Ten minutes before, DJ Fuku plays you in. The globe turns slowly while people gather from everywhere.',
  },
  {
    offset: 0,
    title: 'Ten minutes of shared stillness',
    body: 'Everyone hears the same moment. Nothing to pause, nothing to skip, only the pause itself.',
  },
  {
    offset: SESSION_LENGTH,
    title: 'A peace message for the world',
    body: 'Afterwards, you leave a few words for someone you may never meet. They drift through the lounge for others to find.',
  },
]

export default function GlobalPause() {
  const ref = useBloom<HTMLElement>()
  const [count, setCount] = useState(() => 12_400 + Math.floor(Math.random() * 600))
  const [start] = useState(() => sessionState(Date.now()).start)

  return (
    <section id="global-pause" ref={ref} className="gp" aria-labelledby="gp-title">
      <div className="gp-stage">
        <NightSky />

        <div className="gp-inner">
          <div className="gp-copy">
            <header className="gp-head">
              <p className="eyebrow gp-eyebrow bloom">Global Pause</p>
              <h2 id="gp-title" className="headline gp-headline bloom" style={{ '--bloom-delay': '80ms' } as CSSProperties}>
                Pause with <em>the world.</em>
              </h2>
              <p className="lede gp-lede bloom" style={{ '--bloom-delay': '160ms' } as CSSProperties}>
                Every day, at the same moment, people everywhere stop together for ten minutes. As each
                person arrives, a light wakes on the globe, until the whole world is quietly glowing with
                company. The evening pause is 20:40 in Bangkok, with gentler hours added around the day so
                one always fits yours.
              </p>
            </header>

            <LiveStrip count={count} />

            <article className="gp-fuku bloom" style={{ '--bloom-delay': '320ms' } as CSSProperties}>
              <AmbientVideo name="fuku-intro" className="gp-fuku-video" />
              <div className="gp-fuku-text">
                <p className="gp-fuku-kicker">Fuku's Lounge</p>
                <p className="gp-fuku-line">Your host, DJ Fuku, keeps the music low and the light warm while everyone arrives.</p>
              </div>
            </article>
          </div>

          <div className="gp-globe-slot bloom" style={{ '--bloom-delay': '120ms' } as CSSProperties}>
            <Globe onJoin={() => setCount((c) => c + 1)} />
          </div>
        </div>

        <ol className="gp-phases">
          {phases.map((phase, i) => (
            <li
              key={phase.title}
              className="gp-phase bloom"
              style={{ '--bloom-delay': `${120 + i * 120}ms` } as CSSProperties}
            >
              <span className="gp-phase-time">{localTime.format(start + phase.offset)}</span>
              <h3 className="gp-phase-title">{phase.title}</h3>
              <p className="gp-phase-body">{phase.body}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  )
}
