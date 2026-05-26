# Deep — Design System

> *"Pause. Breathe. Connect. Heal — together."*

A soft place in the harsh. A companion app for slowing down, feeling held, and reconnecting with self and others.

---

## Brand Essence

- Gentle
- Dreamlike
- Safe
- Spiritual but universal
- Emotional calm
- Soft futuristic wellness

---

## UX Philosophy

Deep is built around the belief that healing happens in stillness, not stimulation. Every interaction is designed to slow the user's nervous system rather than capture their attention. Where most apps optimize for retention and engagement loops, Deep optimizes for **regulation, presence, and gentle return**.

**Core principles:**

- **Soft over sharp.** No hard edges, no abrupt cuts, no urgent reds. The interface should feel like exhaling.
- **Breathe with the user.** The app's rhythm matches the body — slow transitions, generous whitespace, time to land before being asked to act.
- **Invitation, never demand.** Notifications, prompts, and CTAs are phrased as gentle offerings. The user is never behind, never failing, never owed.
- **Held, not tracked.** Streaks, scores, and gamification are absent. Progress is reflected back as growth, not performance.
- **Privacy as care.** What is shared in Deep stays in Deep. The vulnerability of users is treated as sacred, not as data.
- **Together, at your pace.** Social features exist but never expose. Connection is opt-in, asynchronous, and protected by design.

The user should leave each session feeling **softer than they arrived.**

---

## Design Keywords

**Atmosphere:** dreamy · ethereal · weightless · luminous · hushed
**Texture:** translucent · iridescent · glassy · powdery · silken
**Feeling:** safe · held · tender · spacious · forgiving
**Motion:** drifting · floating · breathing · settling · unfolding
**Form:** orb · bubble · sphere · halo · cloud · droplet · mist

If a design choice cannot be described by one of these words, it likely belongs to a different product.

---

## Animation Styles

Motion in Deep is **always slower than expected.** The reference is breath, water, and floating particles — never spring-snap, never bounce-and-settle interfaces typical of consumer apps.

**Timing:**
- Default duration: **600–900ms** (vs. the typical 200–300ms).
- Easing: custom cubic-bezier approximating an exhale — slow start, slow end, no overshoot. Avoid `easeInOut` defaults; they feel mechanical here.
- Breathing loops: 4s inhale, 6s exhale (the physiological "sigh" ratio that calms the vagus nerve).

**Signature motions:**
- **Drift.** Bubbles, orbs, and background elements move on slow Lissajous paths — never linear, never repeating exactly. Like dust in a sunbeam.
- **Bloom.** New content appears by scaling from 0.92→1.0 with opacity 0→1 over ~700ms. No slide-ins.
- **Settle.** Tapped elements depress softly (scale 0.97) and release with damped overshoot — like pressing into foam.
- **Halo pulse.** Active states emit a single slow ring outward (1.2s, fading), once — not repeating.
- **Parallax mist.** Background gradients shift subtly with device motion or scroll. Never the foreground; only the atmosphere.

**Forbidden motions:** hard slides, modal pop-ins, shake/error wiggles, confetti, fast spinners, skeleton-shimmer loaders. Loading is a slowly rotating halo or a gently pulsing orb.

---

## UI Style

**Surfaces.** Cards are rounded with generous corner radii (**20–28pt** for cards, **full pill** for buttons). Backgrounds layer translucent gradient washes — lavender into lilac into blush into cream — with soft Gaussian blur to create depth without weight.

**Glassmorphism, restrained.** Frosted-glass panels (10–20% white tint, ~30pt blur) over the gradient backdrop. Borders are 0.5pt at 30% white. No heavy drop shadows — instead, a soft **ambient bloom** beneath cards (lavender at 8% opacity, large radius).

**Color palette:**

| Role | Color | Notes |
|---|---|---|
| Primary | `#B8A7E8` Lavender Mist | Logo, primary actions, halos |
| Secondary | `#D4C5F0` Soft Lilac | Surfaces, gradients |
| Accent warm | `#F4C9D4` Blush Powder | Highlights, hearts, warmth |
| Accent cool | `#C5D8F0` Sky Wash | Calm states, water, depth |
| Accent earth | `#F5D9C4` Peach Cloud | Gentle warmth, sun |
| Surface | `#FBF7FF` Moon Cream | App background base |
| Text primary | `#3D3654` Deep Plum | Never pure black |
| Text muted | `#8B82A8` Drift Grey | Secondary, captions |

All colors live within a desaturated pastel range (HSL saturation **20–45%**, lightness **75–95%**). High-saturation colors are forbidden — they read as alarm.

**Iconography.** Custom rounded line icons, 1.5pt stroke, soft terminals. SF Symbols are acceptable only in `.rounded` weight with reduced opacity. Icons often sit inside a soft translucent circle (their own little bubble).

**Imagery.** Hand-illustrated 3D-rendered orbs containing soft characters, dream landscapes, watercolor mountains. Never photography of people's faces — photography breaks the gentle abstraction. Stock-photo realism is banned.

**Layout.** Vertical, single-column, generously spaced. Default vertical rhythm: **24pt**. Edge padding: **20pt**. Nothing crowds an edge. Empty space is part of the design, not waste.

---

## Typography

A two-family system — a soft serif for emotional moments and a humanist sans for clarity in interface elements.

**Display / Serif — `Cormorant Garamond`** (or `Fraunces` as a modern alternative)
- Used for: the wordmark, hero headlines, affirmations, journal prompts, quotes.
- Weight: **Light (300)** and **Light Italic** almost exclusively. Bold serifs feel declarative; Deep does not declare.
- Tracking: **+2%** for headlines to let letters breathe.
- The wordmark "deep" is rendered in lowercase italic, with a lavender→lilac vertical gradient fill.

**Interface / Sans — `Inter`** (or SF Pro Rounded on Apple platforms)
- Used for: navigation, buttons, body copy, form fields, metadata.
- Weight: **Regular (400)** for body, **Medium (500)** for emphasis. Bold is rare.
- Line-height: **1.5–1.65** — taller than typical UI for a slower reading rhythm.

**Type scale:**

| Token | Size | Family | Use |
|---|---|---|---|
| Display | 56pt | Serif Light Italic | Wordmark, onboarding heroes |
| H1 | 32pt | Serif Light | Section titles, affirmations |
| H2 | 24pt | Serif Light | Card titles, prompts |
| H3 | 18pt | Sans Medium | UI section headers |
| Body | 16pt | Sans Regular | Default copy |
| Caption | 13pt | Sans Regular | Metadata, timestamps |
| Micro | 11pt | Sans Medium, +5% tracking | Labels, all-caps tags |

**Voice in text.** Sentence case everywhere except micro-labels. Punctuation is gentle — periods over exclamation marks. The app speaks in second person, present tense, with warmth: *"Take a moment. You're here now."*

---

## In summary

Every pixel of Deep should feel like the moment after a long exhale. If a component, color, or motion would startle a sleeping cat, it does not belong.
