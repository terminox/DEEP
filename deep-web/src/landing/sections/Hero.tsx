// The welcome, as OnboardingIntroView.swift lays it out: a sunrise over still water, the glowing cream
// mark, and the iris-dusk wordmark lockup beneath it. The logo keeps the app's exact colours, so
// legibility comes from shaping the light behind each part instead: the sky is deepened above the
// sun so the cream mark reads as light, and a frosted cream mist settles behind the wordmark.
import type { CSSProperties } from 'react'
import { AmbientVideo, LogoMark, useBloom, Wordmark } from '../components/shared.tsx'
import './Hero.css'

// Desktop plays the generated landscape film; phones in portrait play the iOS welcome itself.
const LANDSCAPE = 'hero-lake'

export default function Hero() {
  const ref = useBloom<HTMLElement>()

  return (
    <header className="hero" id="top" ref={ref}>
      <div className="hero-film" aria-hidden="true">
        <AmbientVideo name={LANDSCAPE} portrait="welcome" className="hero-video" eager />
        <div className="hero-dusk" />
        <div className="hero-veil" />
      </div>

      <div className="hero-content">
        <h1 className="hero-lockup" aria-label="DEEP — peace begins within">
          <span className="hero-seat hero-seat--mark">
            <span className="hero-pool" aria-hidden="true" />
            <span className="hero-mark bloom">
              <LogoMark size="var(--mark)" glow tint="var(--moon-cream)" />
            </span>
          </span>
          <span className="hero-seat hero-seat--word">
            <span className="hero-mist" aria-hidden="true" />
            <span className="hero-word bloom" style={{ '--bloom-delay': '120ms' } as CSSProperties}>
              <Wordmark tagline className="hero-wordmark" />
            </span>
          </span>
        </h1>

        <div className="hero-foot">
          <p className="hero-manifesto bloom" style={{ '--bloom-delay': '320ms' } as CSSProperties}>
            Pause. Breathe. Connect. Heal&nbsp;— together.
          </p>
          <p className="hero-lede bloom" style={{ '--bloom-delay': '420ms' } as CSSProperties}>
            A soft place to slow down. Breathe with a gentle guide, pause with people all over the world,
            and watch your quiet minutes grow into something that helps others.
          </p>
          <div className="hero-actions bloom" style={{ '--bloom-delay': '520ms' } as CSSProperties}>
            <a className="pill pill--ghost" href="#global-pause">
              See how it feels
            </a>
          </div>
        </div>
      </div>
    </header>
  )
}
