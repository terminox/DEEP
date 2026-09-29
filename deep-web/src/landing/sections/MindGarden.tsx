// Mind Garden, "Grow plants along with yourself". A web port of the iOS garden home
// (MindGardenHomeView.swift): the oak's video hero fading into the page, the growth card and today's
// practice riding up over its edge, then the oak's three forms and the other Mind Trees.
import { useId, useState, type CSSProperties } from 'react'
import { AmbientVideo, SectionHead, useBloom } from '../components/shared.tsx'
import './MindGarden.css'

/** The sample garden, as in the iOS fixtures: a Young Oak 240 of 700 toward Mature Oak, 7 of 10 minutes today. */
const growth = { stage: 'Young Oak', next: 'Mature Oak', sunlight: 240, goal: 700 }
const today = { minutes: 7, goal: 10 }

const stages = [
  { name: 'Oak Seedling', line: 'A quiet seed, just planted.', src: '/media/oak-seedling.jpg' },
  { name: 'Young Oak', line: 'Reaching a little more each day.', src: '/media/oak-young.jpg' },
  { name: 'Mature Oak', line: 'Shade, grown from small moments.', src: '/media/oak-mature.jpg' },
]

const trees = [
  { name: 'Oak', line: 'steady and strong', tint: 'var(--fern)' },
  { name: 'Sakura', line: 'gentle and open', tint: 'var(--blush-powder)' },
  { name: 'Lotus', line: 'calm and mindful', tint: 'var(--lavender-mist)' },
  { name: 'Orange', line: 'warm and joyful', tint: 'var(--peach-cloud)' },
]

/** GardenGreeting.current(): the salutation follows the visitor's own hour. */
function salutation(hour = new Date().getHours()) {
  if (hour >= 5 && hour < 12) return 'Good morning'
  if (hour >= 12 && hour < 17) return 'Good afternoon'
  return 'Good evening'
}

type RingProps = {
  /** Outer diameter in px. */
  size: number
  width: number
  progress: number
  track: string
  from: string
  to: string
  className?: string
}

/** A progress ring after CompassionRing: a track, the arc, and a blurred copy of the arc glowing beneath it. */
function Ring({ size, width, progress, track, from, to, className = '' }: RingProps) {
  const id = useId()
  const c = size / 2
  const r = (size - width) / 2
  const arc = {
    cx: c,
    cy: c,
    r,
    fill: 'none',
    stroke: `url(#${id}-g)`,
    strokeWidth: width,
    strokeLinecap: 'round' as const,
    pathLength: 100,
    transform: `rotate(-90 ${c} ${c})`,
  }
  return (
    <svg
      className={`mg-ring ${className}`}
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      style={{ '--mg-progress': Math.round(progress * 100) } as CSSProperties}
      aria-hidden="true"
    >
      <defs>
        <linearGradient id={`${id}-g`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" style={{ stopColor: from }} />
          <stop offset="1" style={{ stopColor: to }} />
        </linearGradient>
        <filter id={`${id}-b`} x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation={width * 0.6} />
        </filter>
      </defs>
      <circle cx={c} cy={c} r={r} fill="none" style={{ stroke: track }} strokeWidth={width} />
      <circle {...arc} className="mg-arc mg-arc--bloom" filter={`url(#${id}-b)`} />
      <circle {...arc} className="mg-arc" />
    </svg>
  )
}

/** SunlightFact.swift: sun.max.fill, drawn as a rounded glyph in sunbeam. */
function SunGlyph() {
  const rays = Array.from({ length: 8 }, (_, i) => (i * Math.PI) / 4)
  return (
    <svg className="mg-sun-glyph" viewBox="0 0 24 24" width="13" height="13" aria-hidden="true">
      <circle cx="12" cy="12" r="4.6" fill="currentColor" />
      {rays.map((a) => (
        <line
          key={a}
          x1={12 + Math.cos(a) * 7.6}
          y1={12 + Math.sin(a) * 7.6}
          x2={12 + Math.cos(a) * 10.2}
          y2={12 + Math.sin(a) * 10.2}
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
        />
      ))}
    </svg>
  )
}

/** PlantGrowthHalo: an 84px portrait with a rim vignette, inside a ring of growth (gap 5, width 3.5). */
function PlantGrowthHalo({ src, progress }: { src: string; progress: number }) {
  const portrait = 84
  const gap = 5
  const width = 3.5
  const total = portrait + 2 * (gap + width)
  return (
    <div className="mg-halo" style={{ width: total, height: total }}>
      <Ring
        size={total}
        width={width}
        progress={progress}
        track="rgb(from var(--meadow) r g b / 0.55)"
        from="var(--sage)"
        to="var(--fern)"
      />
      <span className="mg-portrait" style={{ width: portrait, height: portrait }}>
        <img src={src} alt="" loading="lazy" />
      </span>
    </div>
  )
}

export default function MindGarden() {
  const rootRef = useBloom<HTMLElement>()
  const [hello] = useState(() => salutation())

  return (
    <section id="mind-garden" className="mg" ref={rootRef} aria-label="Mind Garden">
      <div className="mg-inner">
        <SectionHead
          eyebrow="Mind Garden"
          lede="Your practice, reflected back as growth rather than performance. Every DEEP Session and every Global Pause brings your plant sunlight, and at gentle thresholds it becomes its next form."
        >
          Grow plants along with <em>yourself</em>
        </SectionHead>

        <div className="mg-home">
          <div className="mg-hero bloom" style={{ '--bloom-delay': '120ms' } as CSSProperties}>
            <AmbientVideo name="oak-mature" className="mg-video" />
          </div>

          <div className="mg-cards">
            <article
              className="mg-growth frosted bloom"
              style={{ '--bloom-delay': '260ms' } as CSSProperties}
              aria-label={`${growth.stage}, ${growth.sunlight} of ${growth.goal} sunlight to ${growth.next}`}
            >
              <div className="mg-salutation">
                <p className="mg-hello">{hello}</p>
                <p className="mg-quote">Your oak has been growing quietly.</p>
              </div>
              <div className="mg-plant" aria-hidden="true">
                <PlantGrowthHalo src="/media/oak-young.jpg" progress={growth.sunlight / growth.goal} />
                <div className="mg-plant-copy">
                  <p className="mg-stage">{growth.stage}</p>
                  <p className="mg-sunlight">
                    <SunGlyph />
                    <span>
                      <strong>{growth.sunlight}</strong>/{growth.goal} to {growth.next}
                    </span>
                  </p>
                </div>
              </div>
            </article>

            <a
              className="mg-practice frosted bloom"
              href="#deep-session"
              style={{ '--bloom-delay': '360ms' } as CSSProperties}
              aria-label={`Begin today’s practice, ${today.minutes} of ${today.goal} minutes complete`}
            >
              <span className="mg-practice-copy">
                <span className="eyebrow">Today’s practice</span>
                <span className="mg-practice-title">Tend your garden</span>
                <span className="mg-practice-sub">Each session feeds your oak</span>
              </span>
              <span className="mg-dial">
                <span className="mg-dial-ring">
                  <Ring
                    size={69}
                    width={3.5}
                    progress={today.minutes / today.goal}
                    track="rgb(from var(--lavender-mist) r g b / 0.16)"
                    from="var(--lavender-mist)"
                    to="var(--blush-powder)"
                  />
                  <span className="mg-play">
                    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
                      <path d="M8 5.6c0-.8.9-1.3 1.6-.9l9.4 5.9c.6.4.6 1.4 0 1.8l-9.4 5.9c-.7.4-1.6-.1-1.6-.9z" fill="currentColor" />
                    </svg>
                  </span>
                </span>
                <span className="mg-dial-label">
                  {today.minutes} of {today.goal} min
                </span>
              </span>
            </a>
          </div>
        </div>

        <div className="mg-lower">
          <div className="mg-path">
            <div className="mg-path-head bloom">
              <h3 className="mg-path-title">
                One oak, <em>three forms</em>
              </h3>
              <p className="mg-path-body">
                From a quiet seedling to a sheltering tree, at the pace of your breath. There are no
                streaks to break and nothing to fail. A quiet day costs you nothing, and your oak is simply there,
                growing when you return.
              </p>
            </div>
            <ol className="mg-stages">
              {stages.map((s, i) => (
                <li
                  key={s.name}
                  className={`mg-stage-fig mg-stage-fig--${i + 1} bloom`}
                  style={{ '--bloom-delay': `${160 + i * 160}ms` } as CSSProperties}
                >
                  <span className="mg-stage-art">
                    <img src={s.src} alt="" loading="lazy" />
                  </span>
                  <span className="mg-stage-name">{s.name}</span>
                  <span className="mg-stage-line">{s.line}</span>
                </li>
              ))}
            </ol>
          </div>

          <aside className="mg-trees frosted bloom" style={{ '--bloom-delay': '240ms' } as CSSProperties}>
            <span className="mg-trees-portrait">
              <img src="/media/sakura-mature.jpg" alt="A sakura tree in full bloom, holding a softly glowing heart" loading="lazy" />
            </span>
            <p className="mg-trees-title">
              Other <em>Mind Trees</em>
            </p>
            <p className="mg-trees-body">
              When you arrive, you choose a Mind Tree, a small emblem of how you’d like to grow.
            </p>
            <ul className="mg-tree-list">
              {trees.map((t) => (
                <li key={t.name} className="mg-tree">
                  <span className="mg-tree-dot" style={{ background: t.tint }} aria-hidden="true" />
                  <span className="mg-tree-name">{t.name}</span>
                  <span className="mg-tree-line">{t.line}</span>
                </li>
              ))}
            </ul>
          </aside>
        </div>
      </div>
    </section>
  )
}
