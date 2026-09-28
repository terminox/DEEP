// The welcome, layered like OnboardingIntroView.swift: a sunrise over still water, a cream veil
// fading down from the top, a deeper one rising from the bottom, and the glowing mark over the sun.
import type { CSSProperties } from 'react'
import { AmbientVideo, LogoMark, Wordmark, useBloom } from '../components/shared.tsx'
import './Hero.css'

// Desktop plays the generated landscape film; phones in portrait play the iOS welcome itself.
const LANDSCAPE = 'hero-lake'

export default function Hero() {
  const ref = useBloom<HTMLElement>()

  return (
    <header className="hero" id="top" ref={ref}>
      <div className="hero-film" aria-hidden="true">
        <AmbientVideo name={LANDSCAPE} portrait="welcome" className="hero-video" eager />
        <div className="hero-veil hero-veil--top" />
        <div className="hero-veil hero-veil--bottom" />
      </div>

      <div className="hero-content">
        <div className="hero-mark bloom">
          <LogoMark size={88} glow tint="var(--moon-cream)" />
        </div>
        <h1 className="hero-title bloom" style={{ '--bloom-delay': '120ms' } as CSSProperties}>
          <Wordmark className="hero-wordmark" />
          <span className="hero-tagline">peace begins within</span>
        </h1>

        <div className="hero-foot">
          <p className="hero-manifesto bloom" style={{ '--bloom-delay': '320ms' } as CSSProperties}>
            Pause. Breathe. Connect. Heal — together.
          </p>
          <p className="hero-lede bloom" style={{ '--bloom-delay': '420ms' } as CSSProperties}>
            A soft place to slow down. Breathe with a gentle guide, pause with people all over the world,
            and watch your quiet minutes grow into something that helps others.
          </p>
          <div className="hero-actions bloom" style={{ '--bloom-delay': '520ms' } as CSSProperties}>
            <a className="pill" href="#download">
              Download Deep
            </a>
            <a className="pill pill--ghost" href="#global-pause">
              See how it feels
            </a>
          </div>
        </div>
      </div>
    </header>
  )
}
