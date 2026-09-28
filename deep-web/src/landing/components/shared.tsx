// Shared landing primitives: blooming on scroll, videos that only play in view, the Deep mark,
// and the store badges. Section files compose these; they never re-implement them.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode, type RefObject } from 'react'
import './shared.css'

export const prefersReducedMotion = () =>
  typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches

/** True while the element is (at least partly) on screen. */
export function useInView<T extends Element>(ref: RefObject<T | null>, rootMargin = '0px') {
  const [inView, setInView] = useState(false)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(([entry]) => setInView(entry.isIntersecting), { rootMargin })
    observer.observe(el)
    return () => observer.disconnect()
  }, [ref, rootMargin])
  return inView
}

/** Adds `is-in` to every `.bloom` inside the returned ref once it enters the viewport. */
export function useBloom<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  useEffect(() => {
    const root = ref.current
    if (!root) return
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue
          entry.target.classList.add('is-in')
          observer.unobserve(entry.target)
        }
      },
      { threshold: 0.15, rootMargin: '0px 0px -6% 0px' },
    )
    root.querySelectorAll('.bloom').forEach((el) => observer.observe(el))
    return () => observer.disconnect()
  }, [])
  return ref
}

type VideoProps = {
  /** Base name under /media, e.g. "sky" for /media/sky.mp4 and /media/sky-poster.jpg. */
  name: string
  /** Optional portrait source for narrow screens, same naming. */
  portrait?: string
  className?: string
  style?: CSSProperties
  /** Start loading immediately (the hero); otherwise loads when near the viewport. */
  eager?: boolean
}

/** A muted, looping, inline video that only plays while visible, and stays a poster under reduced motion. */
export function AmbientVideo({ name, portrait, className, style, eager }: VideoProps) {
  const ref = useRef<HTMLVideoElement>(null)
  const near = useInView(ref, '200px')
  const [reduce] = useState(prefersReducedMotion)
  const [armed, setArmed] = useState(!!eager)
  const [isPortrait] = useState(
    () => !!portrait && window.matchMedia('(orientation: portrait) and (max-width: 820px)').matches,
  )
  const base = isPortrait && portrait ? portrait : name

  useEffect(() => {
    if (near) setArmed(true)
  }, [near])

  useEffect(() => {
    const video = ref.current
    if (!video || reduce || !armed) return
    if (near) video.play().catch(() => {})
    else video.pause()
  }, [near, armed, reduce])

  return (
    <video
      ref={ref}
      className={className}
      style={style}
      poster={`/media/${base}-poster.jpg`}
      src={armed && !reduce ? `/media/${base}.mp4` : undefined}
      muted
      loop
      playsInline
      preload={eager ? 'auto' : 'none'}
      aria-hidden="true"
    />
  )
}

/** The Deep mark: a thin ring with a dot at its centre (DeepLogoMark.swift). Stroke 2%, dot 13%. */
export function LogoMark({ size = 40, glow = false, tint = 'var(--iris-dusk)' }: { size?: number; glow?: boolean; tint?: string }) {
  const stroke = 2 // of 100
  return (
    <svg
      className={`logo-mark${glow ? ' logo-mark--glow' : ''}`}
      width={size}
      height={size}
      viewBox="0 0 100 100"
      style={{ color: tint }}
      aria-hidden="true"
    >
      <circle cx="50" cy="50" r={50 - stroke / 2} fill="none" stroke="currentColor" strokeWidth={stroke} />
      <circle cx="50" cy="50" r="6.5" fill="currentColor" />
    </svg>
  )
}

export function Wordmark({ className = '' }: { className?: string }) {
  return <span className={`wordmark ${className}`}>deep</span>
}

export function StoreBadges({ align = 'center' }: { align?: 'center' | 'start' }) {
  return (
    <div className={`badges badges--${align}`}>
      <a className="badge badge--store" href="#">
        <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
          <path
            fill="currentColor"
            d="M16.4 12.6c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9s-1.8-.9-3-.8C7 7.4 5.6 8.3 4.8 9.7c-1.6 2.8-.4 6.9 1.2 9.1.8 1.1 1.7 2.3 2.8 2.3 1.1 0 1.6-.7 2.9-.7s1.7.7 2.9.7c1.2 0 2-1.1 2.7-2.2.9-1.3 1.2-2.5 1.2-2.6 0 0-2.3-.9-2.3-3.7zM14.2 5.8c.6-.7 1-1.8.9-2.8-.9 0-2 .6-2.6 1.3-.6.6-1.1 1.7-.9 2.7 1 .1 2-.5 2.6-1.2z"
          />
        </svg>
        <span className="badge-text">
          <span className="badge-small">Download on the</span>
          <span className="badge-big">App Store</span>
        </span>
      </a>
      <a className="badge badge--soon" href="#" aria-disabled="true" onClick={(e) => e.preventDefault()}>
        <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
          <path fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" d="M6 4.5v15l12-7.5z" />
        </svg>
        <span className="badge-text">
          <span className="badge-small">Coming soon to</span>
          <span className="badge-big">Google Play</span>
        </span>
      </a>
    </div>
  )
}

/** The iOS AtmosphereBackground: a pastel wash with three blurred orbs drifting over 14s. */
export function Atmosphere({ className = '' }: { className?: string }) {
  return (
    <div className={`atmosphere ${className}`} aria-hidden="true">
      <span className="atmosphere-orb atmosphere-orb--lavender" />
      <span className="atmosphere-orb atmosphere-orb--blush" />
      <span className="atmosphere-orb atmosphere-orb--sky" />
    </div>
  )
}

export function SectionHead({
  eyebrow,
  children,
  lede,
  align = 'start',
}: {
  eyebrow: string
  children: ReactNode
  lede?: ReactNode
  align?: 'start' | 'center'
}) {
  return (
    <header className={`section-head section-head--${align}`}>
      <p className="eyebrow bloom">{eyebrow}</p>
      <h2 className="headline bloom" style={{ '--bloom-delay': '80ms' } as CSSProperties}>
        {children}
      </h2>
      {lede && (
        <p className="lede bloom" style={{ '--bloom-delay': '160ms' } as CSSProperties}>
          {lede}
        </p>
      )}
    </header>
  )
}
