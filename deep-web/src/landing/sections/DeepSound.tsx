// DEEP Sound: the iOS sound home (DeepSoundHomeView.swift) as a landing moment. A sky band with the
// shelves riding up over it, and one glass mini player docked at the foot of the section that expands
// into Now Playing. Everything is visual; no audio plays.
import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react'
import { AmbientVideo, Atmosphere, useBloom, useInView } from '../components/shared.tsx'
import './DeepSound.css'

// MARK: Palettes (ArtworkPalette.swift)

const deepen = (token: string, from: number, to: number) => [
  from === 0 ? `var(${token})` : `color-mix(in srgb, var(${token}), var(--deep-plum) ${from}%)`,
  `color-mix(in srgb, var(${token}), var(--deep-plum) ${to}%)`,
]

const palettes = {
  tide: ['var(--sky-wash)', 'var(--soft-lilac)'],
  dusk: ['var(--lavender-mist)', 'var(--blush-powder)'],
  bloom: ['var(--blush-powder)', 'var(--soft-lilac)'],
  ember: ['var(--peach-cloud)', 'var(--blush-powder)'],
  mist: ['var(--soft-lilac)', 'var(--sky-wash)'],
  aurora: ['var(--sky-wash)', 'var(--lavender-mist)', 'var(--blush-powder)'],
  dawn: ['var(--moon-cream)', 'var(--peach-cloud)'],
  veil: deepen('--soft-lilac', 0, 8),
  petal: deepen('--blush-powder', 0, 12),
  iris: deepen('--lavender-mist', 22, 34),
  shore: deepen('--sky-wash', 0, 12),
  hearth: deepen('--peach-cloud', 0, 12),
} as const

type Palette = keyof typeof palettes

/** SoundArtwork: palette linear top-leading to bottom-trailing, with a deepPlum .12 radial in the far corner. */
const artwork = (palette: Palette): CSSProperties => ({
  backgroundImage: `radial-gradient(circle at 100% 100%, rgb(from var(--deep-plum) r g b / 0.12), transparent 240px), linear-gradient(to bottom right, ${palettes[palette].join(', ')})`,
})

// MARK: Sample library

type Collection = {
  id: string
  title: string
  subtitle: string
  palette: Palette
  tracks: string[]
}

type Shelf = { title: string; collections: Collection[] }

const c = (id: string, title: string, subtitle: string, palette: Palette, tracks: string[]): Collection => ({
  id,
  title,
  subtitle,
  palette,
  tracks,
})

const shelves: Shelf[] = [
  {
    title: 'Calm',
    collections: [
      c('still-water', 'Still Water', 'A lake with no wind', 'tide', ['Surface', 'Reeds', 'Far Bank']),
      c('soft-rain', 'Soft Rain Hours', 'Rain on a paper roof', 'mist', ['First Drops', 'Eaves', 'Puddle Light']),
      c('lantern-drift', 'Lantern Drift', 'Warm light, slow river', 'dusk', ['Release', 'Downstream', 'Glow']),
      c('hush-of-pines', 'Hush of Pines', 'Wind through tall trees', 'veil', ['Needles', 'High Branches', 'Resin']),
      c('quiet-harbour', 'Quiet Harbour', 'Boats resting at dusk', 'shore', ['Moorings', 'Low Swell', 'Gulls Asleep']),
      c('feather-light', 'Feather Light', 'Almost nothing at all', 'bloom', ['Down', 'Float', 'Settle']),
    ],
  },
  {
    title: 'Morning',
    collections: [
      c('first-light', 'First Light', 'Before the world wakes', 'dawn', ['Grey Blue', 'Horizon', 'Gold Edge']),
      c('open-window', 'Open Window', 'Curtains and a breeze', 'ember', ['Latch', 'Linen', 'Street Below']),
      c('dew-garden', 'Dew Garden', 'Wet grass, bright birds', 'aurora', ['Dew', 'Wren', 'Unfurling']),
      c('kettle-birdsong', 'Kettle and Birdsong', 'A slow start to the day', 'hearth', ['Steam', 'Sill', 'First Cup']),
      c('sunlit-linen', 'Sunlit Linen', 'Warmth across the bed', 'petal', ['Stretch', 'Sunbeam', 'Rise']),
      c('morning-tide', 'Morning Tide', 'The sea coming in', 'tide', ['Shoreline', 'Foam', 'Glass Water']),
    ],
  },
  {
    title: 'Sleep',
    collections: [
      c('moonwater', 'Moonwater', 'Silver on a dark lake', 'iris', ['Moonrise', 'Silver', 'Deep Water']),
      c('night-garden', 'Night Garden', 'Crickets and cool air', 'veil', ['Dusk Bloom', 'Crickets', 'Night Jasmine']),
      c('slow-stars', 'Slow Stars', 'Counting nothing', 'aurora', ['Orion', 'Drifting', 'Far Away']),
      c('blanket-of-snow', 'Blanket of Snow', 'Everything goes quiet', 'mist', ['Falling', 'Hush', 'White Field']),
      c('low-tide-lullaby', 'Low Tide Lullaby', 'Waves a long way off', 'shore', ['Ebb', 'Sand Ripples', 'Asleep']),
      c('ember-glow', 'Ember Glow', 'A fire burning down', 'ember', ['Crackle', 'Coals', 'Last Light']),
    ],
  },
]

const duration = (collection: Collection, track: number) => 196 + ((collection.id.length * 37 + track * 53) % 140)

const clock = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`

// MARK: Glyphs

type GlyphName = 'play' | 'pause' | 'forward' | 'backward' | 'down'

function Glyph({ name, className }: { name: GlyphName; className?: string }) {
  const d: Record<GlyphName, string> = {
    play: 'M8 5.4v13.2c0 .8.9 1.3 1.6.9l10.2-6.6c.6-.4.6-1.3 0-1.7L9.6 4.6C8.9 4.1 8 4.6 8 5.4z',
    pause: 'M7 5h2.6c.6 0 1 .4 1 1v12c0 .6-.4 1-1 1H7c-.6 0-1-.4-1-1V6c0-.6.4-1 1-1zm7.4 0H17c.6 0 1 .4 1 1v12c0 .6-.4 1-1 1h-2.6c-.6 0-1-.4-1-1V6c0-.6.4-1 1-1z',
    forward:
      'M2.5 7.2v9.6c0 .7.8 1.1 1.4.7l7-4.8c.5-.4.5-1.1 0-1.5l-7-4.8c-.6-.3-1.4.1-1.4.8zm9.5 0v9.6c0 .7.8 1.1 1.4.7l7-4.8c.5-.4.5-1.1 0-1.5l-7-4.8c-.6-.3-1.4.1-1.4.8z',
    backward:
      'M21.5 7.2v9.6c0 .7-.8 1.1-1.4.7l-7-4.8c-.5-.4-.5-1.1 0-1.5l7-4.8c.6-.3 1.4.1 1.4.8zm-9.5 0v9.6c0 .7-.8 1.1-1.4.7l-7-4.8c-.5-.4-.5-1.1 0-1.5l7-4.8c.6-.3 1.4.1 1.4.8z',
    down: 'M5.3 9.3a1 1 0 0 1 1.4 0L12 14.6l5.3-5.3a1 1 0 1 1 1.4 1.4l-6 6a1 1 0 0 1-1.4 0l-6-6a1 1 0 0 1 0-1.4z',
  }
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d={d[name]} />
    </svg>
  )
}

/** Swaps between play and pause with a soft crossfade rather than a cut. */
function PlayPause({ playing, className }: { playing: boolean; className: string }) {
  return (
    <span className={`snd-pp ${className}`} data-playing={playing}>
      <Glyph name="play" className="snd-pp-play" />
      <Glyph name="pause" className="snd-pp-pause" />
    </span>
  )
}

/** Keeps the outgoing value around for one bloom so two layers can crossfade. */
function useCrossfade<T>(value: T, ms = 700) {
  const [layers, setLayers] = useState<{ current: T; previous: { value: T } | null }>({ current: value, previous: null })
  useEffect(() => {
    setLayers((l) => (l.current === value ? l : { current: value, previous: { value: l.current } }))
    const t = window.setTimeout(() => setLayers((l) => ({ ...l, previous: null })), ms)
    return () => window.clearTimeout(t)
  }, [value, ms])
  return layers
}

// MARK: Pieces

function CollectionTile({
  collection,
  active,
  onPlay,
}: {
  collection: Collection
  active: boolean
  onPlay: (c: Collection) => void
}) {
  return (
    <button
      type="button"
      className={`snd-tile${active ? ' is-active' : ''}`}
      onClick={() => onPlay(collection)}
      aria-label={`Play ${collection.title}`}
    >
      <span className="snd-art snd-tile-art" style={artwork(collection.palette)} />
      <span className="snd-tile-title">{collection.title}</span>
      <span className="snd-tile-subtitle">{collection.subtitle}</span>
    </button>
  )
}

type Now = { collection: Collection; track: number }

const nowKey = (n: Now | null) => (n ? `${n.collection.id}-${n.track}` : 'idle')

function MiniInfo({ now }: { now: Now | null }) {
  return (
    <span className="snd-mini-info">
      <span className="snd-art snd-mini-art" style={artwork(now?.collection.palette ?? 'mist')} />
      <span className="snd-mini-text">
        <span className="snd-mini-title">{now ? now.collection.tracks[now.track] : 'Not playing'}</span>
        <span className="snd-mini-subtitle">{now ? now.collection.title : 'Choose a sound to begin'}</span>
      </span>
    </span>
  )
}

// MARK: Section

export default function DeepSound() {
  const rootRef = useBloom<HTMLElement>()
  const dockRef = useRef<HTMLDivElement>(null)
  const shelvesRef = useRef<HTMLDivElement>(null)
  // The player surfaces once the shelves are on screen, not while the sky band is still arriving.
  const shelvesInView = useInView(shelvesRef, '0px 0px -25% 0px')
  const [now, setNow] = useState<Now | null>(null)
  const [playing, setPlaying] = useState(false)
  const [elapsed, setElapsed] = useState(0)
  const [expanded, setExpanded] = useState(false)

  const total = now ? duration(now.collection, now.track) : 1
  const progress = now ? Math.min(1, elapsed / total) : 0
  const mini = useCrossfade(now)

  // A quiet clock: advance while playing, and roll on to the next track at the end.
  useEffect(() => {
    if (!playing || !now) return
    const id = window.setInterval(() => {
      setElapsed((e) => e + 0.5)
    }, 500)
    return () => window.clearInterval(id)
  }, [playing, now])

  useEffect(() => {
    if (!now || elapsed < total) return
    setNow({ ...now, track: (now.track + 1) % now.collection.tracks.length })
    setElapsed(0)
  }, [elapsed, total, now])

  const load = useCallback((collection: Collection) => {
    setNow((n) => (n?.collection.id === collection.id ? n : { collection, track: 0 }))
    setElapsed((e) => (now?.collection.id === collection.id ? e : 0))
    setPlaying(true)
  }, [now])

  const toggle = () => {
    if (!now) {
      load(shelves[0].collections[0])
      return
    }
    setPlaying((p) => !p)
  }

  const skip = (step: 1 | -1) => {
    if (!now) return
    const count = now.collection.tracks.length
    setNow({ ...now, track: (now.track + step + count) % count })
    setElapsed(0)
  }

  // Now Playing closes on Escape or a press anywhere outside the dock.
  useEffect(() => {
    if (!expanded) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setExpanded(false)
    const onDown = (e: PointerEvent) => {
      if (dockRef.current && !dockRef.current.contains(e.target as Node)) setExpanded(false)
    }
    window.addEventListener('keydown', onKey)
    window.addEventListener('pointerdown', onDown)
    return () => {
      window.removeEventListener('keydown', onKey)
      window.removeEventListener('pointerdown', onDown)
    }
  }, [expanded])

  return (
    <section id="deep-sound" className="snd" ref={rootRef}>
      <Atmosphere className="snd-atmosphere" />

      <div className="snd-inner">
        {/* The sky band: StretchyHero(media: .video("sky")), rounded and melting into the page. */}
        <div className="snd-band bloom">
          <AmbientVideo name="sky" className="snd-band-video" />
          <div className="snd-band-copy">
            <p className="eyebrow snd-band-eyebrow">DEEP Sound</p>
            <h2 className="headline snd-band-headline">
              Collection of tracks <em>for mind</em>
            </h2>
            <p className="lede snd-band-lede">
              Somewhere to land when you don't want to be guided. Soundscapes gathered into collections, an
              album's worth each, ready whenever you are.
            </p>
          </div>
        </div>

        {/* CollectionCarousel rows ride up over the band. */}
        <div className="snd-shelves" ref={shelvesRef}>
          {shelves.map((shelf, s) => (
            <div key={shelf.title} className="snd-shelf bloom" style={{ '--bloom-delay': `${s * 120}ms` } as CSSProperties}>
              <h3 className="snd-shelf-title">{shelf.title}</h3>
              <div className="snd-row" role="list">
                {shelf.collections.map((col) => (
                  <div key={col.id} role="listitem" className="snd-row-item">
                    <CollectionTile collection={col} active={now?.collection.id === col.id} onPlay={load} />
                  </div>
                ))}
              </div>
            </div>
          ))}
          <p className="snd-note bloom">Plus DEEP Teacher and DEEP Kids in the app. Collection names here are samples.</p>
        </div>

        {/* One player that follows you: the docked glass capsule, and Now Playing above it. */}
        <div className={`snd-dock${shelvesInView || now ? ' is-present' : ''}`} ref={dockRef}>
          {expanded && now && (
            <div className="snd-np" role="dialog" aria-label="Now playing">
              <button type="button" className="snd-np-close" onClick={() => setExpanded(false)} aria-label="Close the player">
                <Glyph name="down" />
              </button>
              <div className="snd-np-stage">
                <span
                  key={now.collection.id}
                  className={`snd-art snd-np-art${playing ? ' is-playing' : ''}`}
                  style={artwork(now.collection.palette)}
                />
              </div>
              <div className="snd-np-title">
                <span key={`${now.collection.id}-${now.track}`} className="snd-np-track">
                  {now.collection.tracks[now.track]}
                </span>
                <span className="snd-np-collection">{now.collection.title}</span>
              </div>
              <div className="snd-np-scrub">
                <span className="snd-np-bar">
                  <span className="snd-np-fill" style={{ transform: `scaleX(${progress})` }} />
                </span>
                <span className="snd-np-times">
                  <span>{clock(elapsed)}</span>
                  <span>-{clock(Math.max(0, total - elapsed))}</span>
                </span>
              </div>
              <div className="snd-np-transport">
                <button type="button" className="snd-np-skip" onClick={() => skip(-1)} aria-label="Previous track">
                  <Glyph name="backward" />
                </button>
                <button type="button" className="snd-np-play" onClick={toggle} aria-label={playing ? 'Pause' : 'Play'}>
                  <PlayPause playing={playing} className="snd-np-pp" />
                </button>
                <button type="button" className="snd-np-skip" onClick={() => skip(1)} aria-label="Next track">
                  <Glyph name="forward" />
                </button>
              </div>
            </div>
          )}

          <div className={`snd-mini${now ? ' is-loaded' : ''}`}>
            <button
              type="button"
              className="snd-mini-expand"
              onClick={() => (now ? setExpanded((e) => !e) : toggle())}
              aria-label={now ? `Now playing ${now.collection.tracks[now.track]}. Open the player.` : 'Start listening'}
              aria-expanded={now ? expanded : undefined}
            >
              <span className="snd-mini-layers">
                {mini.previous && (
                  <span className="snd-mini-layer is-leaving" key={`out-${nowKey(mini.previous.value)}`}>
                    <MiniInfo now={mini.previous.value} />
                  </span>
                )}
                <span className="snd-mini-layer is-entering" key={`in-${nowKey(mini.current)}`}>
                  <MiniInfo now={mini.current} />
                </span>
              </span>
            </button>
            <button type="button" className="snd-mini-btn" onClick={toggle} aria-label={playing ? 'Pause' : 'Play'}>
              <PlayPause playing={playing} className="snd-mini-pp" />
            </button>
            <button type="button" className="snd-mini-btn snd-mini-btn--next" onClick={() => skip(1)} aria-label="Next track">
              <Glyph name="forward" />
            </button>
            <span className="snd-mini-progress" style={{ transform: `scaleX(${progress})` }} aria-hidden="true" />
          </div>
        </div>
      </div>
    </section>
  )
}
