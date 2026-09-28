// Deep Session, "Be with yourself". A web port of the iOS session screen: the BreathingOrb over the
// atmosphere, the serif cue beneath it, and one breath the visitor can actually take with us.
import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react'
import { Atmosphere, SectionHead, prefersReducedMotion, useBloom } from '../components/shared.tsx'
import './DeepSession.css'

type Phase = 'idle' | 'settle' | 'in' | 'out' | 'settled'

const ROUNDS = 3
const SETTLE_COUNT = 3

/** BreathingOrb.swift: the orb rests at 0.55 of the ring and meets it at full swell. */
const scaleFor = (swell: number) => `scale(${0.55 + 0.45 * swell})`

// Timings and curves come from the design tokens so CSS and JS can never drift apart.
function token(name: string) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
}

function tokenMs(name: string, fallback: number) {
  const raw = token(name)
  if (raw.endsWith('ms')) return parseFloat(raw)
  if (raw.endsWith('s')) return parseFloat(raw) * 1000
  return fallback
}

/** Carries an element from wherever it is now (mid-flight included) to `to`, like a SwiftUI withAnimation. */
function glide(el: HTMLElement | null, to: Record<string, string>, ms: number, easing: string) {
  if (!el) return
  const now = getComputedStyle(el)
  const from: Record<string, string> = {}
  for (const key of Object.keys(to)) from[key] = now.getPropertyValue(key)
  el.getAnimations().forEach((a) => a.cancel())
  el.animate([from, to], { duration: ms, easing, fill: 'forwards' })
}

const facts = [
  { title: 'Four seconds in, six out', body: 'The long exhale is the physiological sigh, the rhythm your body already uses to settle itself.' },
  { title: 'One to ten minutes', body: 'You set the length on the threshold before you begin, and the orb keeps time so you don’t have to.' },
  { title: 'Pause whenever you need', body: 'Take your time. The breath waits where you left it.' },
  { title: 'It ends on “You’re here now”', body: 'Never a score, never a tally. Just you, a little softer than when you arrived.' },
]

const lengths = [1, 3, 5, 10]

export default function DeepSession() {
  const rootRef = useBloom<HTMLElement>()
  const bodyRef = useRef<HTMLDivElement>(null)
  const glowRef = useRef<HTMLDivElement>(null)
  const [reduce] = useState(prefersReducedMotion)
  const [phase, setPhase] = useState<Phase>('idle')
  const [round, setRound] = useState(1)
  const [count, setCount] = useState(SETTLE_COUNT)

  // The orb itself: one motion per phase, at that phase's own tempo, on the breath curve.
  // Under reduced motion the orb holds still at 0.6 and breathes as light instead.
  useEffect(() => {
    const body = bodyRef.current
    const glow = glowRef.current
    if (!body || !glow) return
    const breath = token('--exhale') || 'cubic-bezier(0.32, 0, 0.36, 1)'
    const inhale = tokenMs('--inhale-length', 4000)
    const exhale = tokenMs('--exhale-length', 6000)

    if (phase === 'idle') {
      if (reduce) return
      // Before Begin: a slow, shallow breath at the same 4:6 ratio, well inside the ring.
      body.getAnimations().forEach((a) => a.cancel())
      body.animate(
        [
          { transform: scaleFor(0.12), easing: breath },
          { transform: scaleFor(0.42), easing: breath, offset: 0.4 },
          { transform: scaleFor(0.12) },
        ],
        { duration: inhale + exhale, iterations: Infinity },
      )
      glow.getAnimations().forEach((a) => a.cancel())
      glow.animate(
        [
          { opacity: 0.78, easing: breath },
          { opacity: 0.95, easing: breath, offset: 0.4 },
          { opacity: 0.78 },
        ],
        { duration: inhale + exhale, iterations: Infinity },
      )
      return
    }

    const plan: Record<Exclude<Phase, 'idle'>, { swell: number; glow: number; ms: number; easing: string }> = {
      // The orb gathers slightly, so the first inhale can fill from it.
      settle: { swell: 0.25, glow: 0.85, ms: SETTLE_COUNT * 1000, easing: breath },
      in: { swell: 1, glow: 1, ms: inhale, easing: breath },
      out: { swell: 0, glow: 0.7, ms: exhale, easing: breath },
      settled: { swell: 0.6, glow: 1, ms: tokenMs('--hush', 1050), easing: token('--hush-curve') || breath },
    }
    const step = plan[phase]
    if (!reduce) glide(body, { transform: scaleFor(step.swell) }, step.ms, step.easing)
    glide(glow, { opacity: String(step.glow) }, step.ms, step.easing)
  }, [phase, round, reduce])

  // The clock: a short settling count, then three rounds of 4s in and 6s out, then rest.
  useEffect(() => {
    if (phase === 'settle') {
      const t = window.setTimeout(() => {
        if (count > 1) setCount(count - 1)
        else setPhase('in')
      }, 1000)
      return () => window.clearTimeout(t)
    }
    if (phase === 'in') {
      const t = window.setTimeout(() => setPhase('out'), tokenMs('--inhale-length', 4000))
      return () => window.clearTimeout(t)
    }
    if (phase === 'out') {
      const t = window.setTimeout(() => {
        if (round < ROUNDS) {
          setRound(round + 1)
          setPhase('in')
        } else {
          setPhase('settled')
        }
      }, tokenMs('--exhale-length', 6000))
      return () => window.clearTimeout(t)
    }
  }, [phase, round, count])

  const begin = useCallback(() => {
    setRound(1)
    setCount(SETTLE_COUNT)
    setPhase('settle')
  }, [])

  const cueKey =
    phase === 'settle' ? `c${count}` : phase === 'in' || phase === 'out' ? phase : phase === 'settled' ? 'settled' : 'idle'
  const captionKey =
    phase === 'idle' ? 'idle' : phase === 'settle' ? 'settle' : phase === 'settled' ? 'settled' : `r${round}`

  const cues: { key: string; text: string; big?: boolean }[] = [
    { key: 'idle', text: 'Try one breath with us' },
    ...Array.from({ length: SETTLE_COUNT }, (_, i) => ({ key: `c${i + 1}`, text: String(i + 1), big: true })),
    { key: 'in', text: 'breathe in' },
    { key: 'out', text: 'breathe out' },
    { key: 'settled', text: 'You’re here now.' },
  ]
  const captions: { key: string; text: string }[] = [
    { key: 'idle', text: 'Three slow breaths, about half a minute' },
    { key: 'settle', text: 'Settling in' },
    ...Array.from({ length: ROUNDS }, (_, i) => ({ key: `r${i + 1}`, text: `${i + 1} of ${ROUNDS}` })),
    { key: 'settled', text: 'Stay as long as you like' },
  ]

  return (
    <section id="deep-session" className="ds" ref={rootRef} data-phase={phase} aria-label="Deep Session">
      <Atmosphere className="ds-atmosphere" />

      <div className="ds-inner">
        <div className="ds-head">
          <SectionHead
            eyebrow="Deep Session"
            lede="The guided breath at the heart of Deep. An orb swells as you breathe in and softens as you breathe out, and for a few minutes there is nothing else to do."
          >
            Be with <em>yourself</em>
          </SectionHead>
        </div>

        <div className="ds-stage bloom" style={{ '--bloom-delay': '120ms' } as CSSProperties}>
          <div className="ds-orb">
            <span className="ds-ring" aria-hidden="true" />
            <div className="ds-orb-glow" ref={glowRef} aria-hidden="true">
              <div className="ds-orb-body" ref={bodyRef} />
            </div>
          </div>

          <div className="ds-cue" aria-live="polite">
            <p className="ds-slots ds-cue-lines">
              {cues.map((c) => (
                <span
                  key={c.key}
                  className={`ds-cue-line${c.big ? ' ds-cue-line--count' : ''}${cueKey === c.key ? ' is-on' : ''}`}
                  aria-hidden={cueKey !== c.key}
                >
                  {c.text}
                </span>
              ))}
            </p>
            <p className="ds-slots ds-caption-lines">
              {captions.map((c) => (
                <span
                  key={c.key}
                  className={`ds-caption${captionKey === c.key ? ' is-on' : ''}`}
                  aria-hidden={captionKey !== c.key}
                >
                  {c.text}
                </span>
              ))}
            </p>
          </div>

          <div className="ds-slots ds-actions">
            <div className={`ds-action${phase === 'idle' ? ' is-on' : ''}`}>
              <button className="pill" type="button" onClick={begin} tabIndex={phase === 'idle' ? 0 : -1} aria-hidden={phase !== 'idle'}>
                Begin
              </button>
            </div>
            <div className={`ds-action${phase === 'settled' ? ' is-on' : ''}`}>
              <button
                className="pill pill--ghost"
                type="button"
                onClick={begin}
                tabIndex={phase === 'settled' ? 0 : -1}
                aria-hidden={phase !== 'settled'}
              >
                Once more
              </button>
            </div>
          </div>
        </div>

        <ul className="ds-facts">
          {facts.map((f, i) => (
            <li key={f.title} className="ds-fact bloom" style={{ '--bloom-delay': `${200 + i * 90}ms` } as CSSProperties}>
              <span className="ds-fact-bead" aria-hidden="true" />
              <span className="ds-fact-text">
                <span className="ds-fact-title">{f.title}</span>
                <span className="ds-fact-body">{f.body}</span>
              </span>
            </li>
          ))}
        </ul>

        <div className="ds-threshold frosted bloom" style={{ '--bloom-delay': '520ms' } as CSSProperties}>
          <div className="ds-threshold-copy">
            <p className="eyebrow">On the threshold</p>
            <p className="ds-threshold-title">Balancing breath</p>
            <p className="ds-threshold-meta">4s in, 6s out, 30 rounds</p>
          </div>
          <div className="ds-lengths" role="img" aria-label="Session length, chosen from one to ten minutes. Five minutes is set.">
            {lengths.map((m) => (
              <span key={m} className={`ds-length${m === 5 ? ' is-set' : ''}`} aria-hidden="true">
                <span className="ds-length-num">{m}</span>
                <span className="ds-length-unit">min</span>
              </span>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
