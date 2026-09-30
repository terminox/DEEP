// Global Pause: the one dark moment on the page, told as a pause is lived. The night card opens to
// fill the screen as it arrives, pins, and walks through an evening: the countdown on a bare sky,
// then DJ Fuku's lounge, the live globe coming to rest, and the peace messages left afterwards.
// Each phase's copy scrolls past while its own visual crossfades in the pinned frame (Inside
// DEEP's grammar, on the night sky); the card closes back to a card just before the next section.
import { useEffect, useMemo, useRef, useState, type CSSProperties, type RefObject } from 'react'
import { prefersReducedMotion, useBloom, useInView } from '../components/shared.tsx'
import { FukuWindow, LiveGlobe, PeaceDrift } from './GlobalPausePhases.tsx'
import './GlobalPause.css'

// MARK: Schedule

/** The evening session goes live at 20:40 in Bangkok (UTC+7, no daylight saving) = 13:40 UTC. */
const LIVE_UTC_HOUR = 13
const LIVE_UTC_MINUTE = 40
const MINUTE = 60_000
const LOUNGE_LEAD = 10 * MINUTE
const SESSION_LENGTH = 10 * MINUTE

type SessionPhase = 'waiting' | 'lounge' | 'live'

function sessionState(now: number): { phase: SessionPhase; start: number } {
  const today = new Date(now)
  today.setUTCHours(LIVE_UTC_HOUR, LIVE_UTC_MINUTE, 0, 0)
  const start = today.getTime()
  if (now >= start && now < start + SESSION_LENGTH) return { phase: 'live', start }
  if (now >= start - LOUNGE_LEAD && now < start) return { phase: 'lounge', start }
  return { phase: 'waiting', start: now < start ? start : start + 24 * 60 * MINUTE }
}

const localTime = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' })
const bangkokTime = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Bangkok' })
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

// MARK: Countdown

function Countdown() {
  const ref = useRef<HTMLDivElement>(null)
  const visible = useInView(ref)
  const now = useNow(visible)
  const { phase, start } = sessionState(now)
  const remaining = Math.max(0, start - now)
  const h = Math.floor(remaining / 3_600_000)
  const m = Math.floor((remaining % 3_600_000) / MINUTE)
  const s = Math.floor((remaining % MINUTE) / 1000)

  return (
    <div ref={ref} className="gp-when bloom" style={{ '--bloom-delay': '240ms' } as CSSProperties}>
      {phase === 'live' ? (
        <>
          <span className="gp-pill gp-pill--live">
            <span className="gp-pill-dot" aria-hidden="true" />
            Live now
          </span>
          <p className="gp-when-note">The world is pausing. You can still slip in.</p>
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
          <p className="gp-when-note">
            At {localTime.format(start)} your time, {bangkokTime.format(start)} in Bangkok
          </p>
        </>
      )}
    </div>
  )
}

// MARK: Phases

type Phase = {
  /** Minutes from the live start, for the local time in the eyebrow. */
  offset: number
  label: string
  /** The headline, then its italic accent. */
  title: [string, string]
  body: string
}

const phases: Phase[] = [
  {
    offset: -LOUNGE_LEAD,
    label: 'Fuku’s Lounge',
    title: ['The lounge', 'opens'],
    body: 'Ten minutes before, your host DJ Fuku plays you in. The music stays low and the light warm while people gather from everywhere, and a few words of welcome carry you to the start.',
  },
  {
    offset: 0,
    label: 'Live',
    title: ['Ten minutes of', 'shared stillness'],
    body: 'Everyone hears the same moment. The globe comes to rest, a light wakes wherever someone is pausing, and there is nothing to pause or skip, only the pause itself.',
  },
  {
    offset: SESSION_LENGTH,
    label: 'Reflection',
    title: ['A peace message', 'for the world'],
    body: 'Afterwards, you leave a few words for someone you may never meet. They drift through the lounge for others to find.',
  },
]

function PhaseCopy({ phase, start }: { phase: Phase; start: number }) {
  return (
    <>
      <p className="eyebrow gp-phase-eyebrow">
        {localTime.format(start + phase.offset)} · {phase.label}
      </p>
      <h3 className="gp-phase-title">
        {phase.title[0]} <em>{phase.title[1]}</em>
      </h3>
      <p className="lede gp-phase-body">{phase.body}</p>
    </>
  )
}

// MARK: Scroll

/** How far the section top travels (in viewport heights) while the card opens to full bleed. */
const OPEN_RUN = 0.9
/** How long (in viewport heights) the card spends closing again before it leaves the screen. */
const CLOSE_RUN = 0.45

/**
 * Scrubs the card to the scroll. `--gp-rest` is 1 for the resting card and 0 for full bleed: it
 * opens as the section rises to the top, and closes over the last stretch before the frame
 * un-pins. `--gp-live` runs 0 → 1 across the live chapter and fills the progress line. Written
 * straight to the frame's style, so scrolling never re-renders React.
 */
function useCardScroll(
  sectionRef: RefObject<HTMLElement | null>,
  frameRef: RefObject<HTMLDivElement | null>,
  liveRef: RefObject<HTMLLIElement | null>,
) {
  useEffect(() => {
    const section = sectionRef.current
    const frame = frameRef.current
    if (!section || !frame) return
    const still = prefersReducedMotion()
    let raf = 0

    const update = () => {
      raf = 0
      const vh = window.innerHeight
      const box = section.getBoundingClientRect()
      const opening = smooth(0, vh * OPEN_RUN, box.top)
      const closing = 1 - smooth(vh, vh * (1 + CLOSE_RUN), box.bottom)
      frame.style.setProperty('--gp-rest', still ? '1' : Math.max(opening, closing).toFixed(4))

      const live = liveRef.current?.getBoundingClientRect()
      if (live) {
        const through = Math.min(1, Math.max(0, (vh / 2 - live.top) / live.height))
        frame.style.setProperty('--gp-live', through.toFixed(4))
      }
    }
    const schedule = () => {
      if (!raf) raf = requestAnimationFrame(update)
    }

    update()
    window.addEventListener('scroll', schedule, { passive: true })
    window.addEventListener('resize', schedule)
    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('scroll', schedule)
      window.removeEventListener('resize', schedule)
    }
  }, [sectionRef, frameRef, liveRef])
}

// MARK: Section

const LOUNGE = 1
const LIVE = 2
const PEACE = 3

export default function GlobalPause() {
  const ref = useBloom<HTMLElement>()
  const frameRef = useRef<HTMLDivElement>(null)
  const chaptersRef = useRef<HTMLOListElement>(null)
  const liveRef = useRef<HTMLLIElement>(null)
  const [start] = useState(() => sessionState(Date.now()).start)
  // 0 is the intro; 1–3 are the phases.
  const [active, setActive] = useState(0)

  useCardScroll(ref, frameRef, liveRef)

  // The chapter crossing the viewport's middle line is the one on screen.
  useEffect(() => {
    const chapters = chaptersRef.current?.querySelectorAll<HTMLElement>('[data-index]')
    if (!chapters) return
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) setActive(Number((entry.target as HTMLElement).dataset.index))
        }
      },
      { rootMargin: '-50% 0px -50% 0px' },
    )
    chapters.forEach((el) => observer.observe(el))
    return () => observer.disconnect()
  }, [])

  const on = (index: number) => (active === index ? ' is-active' : '')

  return (
    <section id="global-pause" ref={ref} className="gp" aria-labelledby="gp-title">
      <div ref={frameRef} className={`gp-frame${active === LIVE ? ' is-live' : ''}`}>
        <div className="gp-frame-shadow" aria-hidden="true" />
        <div className="gp-card">
          <NightSky />

          <div className="gp-grid">
            <div className="gp-visuals">
              <div className={`gp-visual gp-visual--lounge${on(LOUNGE)}`}>
                <FukuWindow active={active === LOUNGE} />
              </div>
              <div className={`gp-visual gp-visual--live${on(LIVE)}`}>
                <LiveGlobe active={active === LIVE} />
              </div>
              <div className={`gp-visual gp-visual--peace${on(PEACE)}`}>
                <PeaceDrift />
              </div>
              <div className={`gp-dots${active > 0 ? ' is-shown' : ''}`} aria-hidden="true">
                {phases.map((phase, i) => (
                  <span key={phase.label} className={active === i + 1 ? 'is-active' : undefined} />
                ))}
              </div>
            </div>
          </div>

          {/* Phones: the phase copy holds still in the lower band and crossfades in place, so it
              never scrolls across the pinned visual. Desktop reads it from the chapters below. */}
          <div className="gp-dock">
            {phases.map((phase, i) => (
              <div key={phase.label} className={`gp-dock-copy${on(i + 1)}`} aria-hidden={active !== i + 1}>
                <PhaseCopy phase={phase} start={start} />
              </div>
            ))}
          </div>
        </div>
      </div>

      <ol className="gp-chapters" ref={chaptersRef}>
        <li className="gp-chapter gp-chapter--intro" data-index={0}>
          <header className="gp-intro">
            <p className="eyebrow gp-eyebrow bloom">Global Pause</p>
            <h2 id="gp-title" className="headline gp-headline bloom" style={{ '--bloom-delay': '80ms' } as CSSProperties}>
              Pause with <em>the world.</em>
            </h2>
            <p className="lede gp-lede bloom" style={{ '--bloom-delay': '160ms' } as CSSProperties}>
              Every day, at the same moment, people everywhere stop together for ten minutes. The evening
              pause is 20:40 in Bangkok, with gentler hours around the day so one always fits yours.
            </p>
            <Countdown />
          </header>
        </li>
        {phases.map((phase, i) => (
          <li
            key={phase.label}
            ref={i + 1 === LIVE ? liveRef : undefined}
            className={`gp-chapter${on(i + 1)}`}
            data-index={i + 1}
          >
            <div className="gp-grid">
              <div className="gp-phase">
                <PhaseCopy phase={phase} start={start} />
              </div>
            </div>
          </li>
        ))}
        <li className="gp-chapter gp-chapter--tail" aria-hidden="true" />
      </ol>
    </section>
  )
}
