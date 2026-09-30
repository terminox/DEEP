// Shared landing primitives: blooming on scroll, videos that only play in view, the DEEP mark
// and wordmark. Section files compose these; they never re-implement them.
import { useEffect, useId, useRef, useState, type CSSProperties, type ReactNode, type RefObject } from 'react'
import { LOCKUP_BOX, TAGLINE_PATH, WORD_BOX, WORD_PATH } from './wordmarkPaths.ts'
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
  /** Holds the video on its current frame even while visible, e.g. a screen stacked under another. */
  paused?: boolean
}

/** A muted, looping, inline video that only plays while visible, and stays a poster under reduced motion. */
export function AmbientVideo({ name, portrait, className, style, eager, paused = false }: VideoProps) {
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
    if (near && !paused) video.play().catch(() => {})
    else video.pause()
  }, [near, armed, reduce, paused])

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

/**
 * The DEEP mark: a thin ring with a dot at its centre (DeepLogoMark.swift). Stroke 2%, dot 13%.
 * Glowing, it carries the iOS bloom: blurred copies of the ring and dot under the crisp pass, then a
 * tight bright halo inside a wide soft one, all proportional to size. A caller can re-tint it from
 * CSS through `--mark-tint` (the Increase Contrast path), which wins over the `tint` prop.
 * `size` is pixels, or any CSS length when the mark scales with its surroundings.
 */
export function LogoMark({ size = 40, glow = false, tint = 'var(--iris-dusk)' }: { size?: number | string; glow?: boolean; tint?: string }) {
  const length = typeof size === 'number' ? `${size}px` : size
  // useId's delimiters aren't safe inside url(#…), so keep only the identifier characters.
  const bloomId = `mark${useId().replace(/[^\w-]/g, '')}`
  const ring = <circle cx="50" cy="50" r="49" fill="none" stroke="currentColor" strokeWidth="2" />
  const dot = <circle cx="50" cy="50" r="6.5" fill="currentColor" />
  return (
    <svg
      className={`logo-mark${glow ? ' logo-mark--glow' : ''}`}
      viewBox="0 0 100 100"
      style={{ width: length, height: length, color: `var(--mark-tint, ${tint})`, '--mark-size': length } as CSSProperties}
      aria-hidden="true"
    >
      {glow && (
        <>
          <defs>
            {/* Blur radii from DeepLogoMark.swift: 0.9 × stroke for the ring, 0.45 × dot for the dot. */}
            <filter id={`${bloomId}-ring`} x="-10%" y="-10%" width="120%" height="120%">
              <feGaussianBlur stdDeviation="1.8" />
            </filter>
            <filter id={`${bloomId}-dot`} x="-100%" y="-100%" width="300%" height="300%">
              <feGaussianBlur stdDeviation="5.85" />
            </filter>
          </defs>
          <g className="logo-mark-bloom" opacity="0.6">
            <g filter={`url(#${bloomId}-ring)`}>{ring}</g>
            <g filter={`url(#${bloomId}-dot)`}>{dot}</g>
          </g>
        </>
      )}
      {ring}
      {dot}
    </svg>
  )
}

/**
 * The DEEP wordmark, traced from the iOS OnboardingLogoText artwork and filled with the current
 * colour (iris dusk by default, the tint iOS gives it). `tagline` adds "peace begins within." below.
 */
export function Wordmark({ className = '', tagline = false }: { className?: string; tagline?: boolean }) {
  const box = tagline ? LOCKUP_BOX : WORD_BOX
  return (
    <svg
      className={`wordmark ${className}`}
      viewBox={`0 0 ${box.width} ${box.height}`}
      fill="currentColor"
      aria-hidden="true"
    >
      <path fillRule="evenodd" d={WORD_PATH} />
      {tagline && <path fillRule="evenodd" d={TAGLINE_PATH} />}
    </svg>
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
