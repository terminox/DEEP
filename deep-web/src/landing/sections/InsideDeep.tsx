// Inside DEEP: the app's four everyday features, each shown as the real iOS screen. One iPhone
// stays pinned while the four chapters scroll past, and its screen crossfades to whichever chapter
// holds the middle of the viewport. On phones each chapter carries its own device.
import { useEffect, useRef, useState, type CSSProperties } from 'react'
import { AmbientVideo, Atmosphere, SectionHead, useBloom } from '../components/shared.tsx'
import { IPhoneFrame } from '../components/IPhoneFrame.tsx'
import './InsideDeep.css'

type Feature = {
  /** Matches the nav's entry in storyOrder.ts, so the nav jumps to and highlights the chapter. */
  id: string
  eyebrow: string
  /** The headline, then its italic accent. */
  title: [string, string]
  lede: string
  /** Screen recording under /media/app (the .mp4 and its -poster.jpg), captured from the iOS app. */
  capture: string
  /** The glow behind the device while this chapter is showing. */
  accent: string
}

const features: Feature[] = [
  {
    id: 'deep-session',
    eyebrow: 'DEEP Session',
    title: ['Be with', 'yourself'],
    lede: 'The guided breath at the heart of DEEP. An orb swells as you breathe in and softens as you breathe out, and for a few minutes there is nothing else to do.',
    capture: 'session',
    accent: 'var(--lavender-mist)',
  },
  {
    id: 'mind-garden',
    eyebrow: 'Mind Garden',
    title: ['Grow plants along with', 'yourself'],
    lede: 'Your practice, reflected back as growth rather than performance. Every DEEP Session and every Global Pause brings your plant sunlight, and at gentle thresholds it becomes its next form.',
    capture: 'garden',
    accent: 'var(--sage)',
  },
  {
    id: 'compassion',
    eyebrow: 'Compassion Portfolio',
    title: ['Make', 'real life impacts'],
    lede: 'Every quiet minute becomes a heart. Give your hearts to the causes you care about, and DEEP donates real money in proportion to where the community’s hearts have gone.',
    capture: 'compassion',
    accent: 'var(--blush-powder)',
  },
  {
    id: 'deep-sound',
    eyebrow: 'DEEP Sound',
    title: ['Collection of tracks', 'for mind'],
    lede: 'Somewhere to land when you don’t want to be guided. Soundscapes gathered into collections, an album’s worth each, ready whenever you are.',
    capture: 'sound',
    accent: 'var(--sky-wash)',
  },
]

export default function InsideDeep() {
  const ref = useBloom<HTMLElement>()
  const chaptersRef = useRef<HTMLOListElement>(null)
  const [active, setActive] = useState(0)

  // The chapter crossing the viewport's middle line is the one on screen.
  useEffect(() => {
    const chapters = chaptersRef.current?.querySelectorAll<HTMLElement>('.in-chapter')
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

  return (
    <section className="in" id="inside" ref={ref} aria-labelledby="in-title">
      <Atmosphere className="in-atmosphere" />
      <div className="in-inner">
        <SectionHead
          eyebrow="Inside DEEP"
          lede="After the pause, DEEP keeps you company: a breath to come back to, a plant that grows with you, hearts that reach real causes, and sound for when words are too much."
        >
          <span id="in-title">
            A quiet place that <em>stays with you</em>
          </span>
        </SectionHead>

        <div className="in-body">
          <ol className="in-chapters" ref={chaptersRef}>
            {features.map((f, i) => (
              <li key={f.id} id={f.id} className={`in-chapter${active === i ? ' is-active' : ''}`} data-index={i}>
                <div className="in-copy">
                  <p className="eyebrow">{f.eyebrow}</p>
                  <h3 className="in-heading">
                    {f.title[0]} <em>{f.title[1]}</em>
                  </h3>
                  <p className="lede">{f.lede}</p>
                </div>
                {/* Phones only: the pinned device is hidden, so each chapter shows its own screen. */}
                <div className="in-chapter-device">
                  <IPhoneFrame width="min(68vw, 290px)" label={`The ${f.eyebrow} screen in the DEEP app`}>
                    <AmbientVideo name={`app/${f.capture}`} />
                  </IPhoneFrame>
                </div>
              </li>
            ))}
          </ol>

          <div className="in-pin">
            <div className="in-stage">
              {features.map((f, i) => (
                <span
                  key={f.id}
                  className={`in-glow${active === i ? ' is-active' : ''}`}
                  style={{ '--accent': f.accent } as CSSProperties}
                  aria-hidden="true"
                />
              ))}
              <IPhoneFrame width="clamp(260px, 23vw, 330px)">
                {features.map((f, i) => (
                  <AmbientVideo
                    key={f.id}
                    name={`app/${f.capture}`}
                    className={`in-screen${active === i ? ' is-active' : ''}`}
                    paused={active !== i}
                  />
                ))}
              </IPhoneFrame>
              <div className="in-dots" aria-hidden="true">
                {features.map((f, i) => (
                  <span key={f.id} className={active === i ? 'is-active' : undefined} />
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
