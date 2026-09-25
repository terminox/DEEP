# Deep for Android — Roadmap to v1.0.0

> *"Pause. Breathe. Connect. Heal — together."* — on a second platform.

Deep ships on iOS today. This document is the route to shipping the same product on Android,
in eight weeks, with a build in the client's hands at the end of every one of them.

For what the product *is*, see `PRODUCT.md`. For how it should look and move, see `DESIGN.md`.
For how to run any of it locally, see `DEVELOPMENT.md`.

---

## Destination

**An Android app at `v1.0.0`, eight weeks from the first commit, doing everything the iOS app
does today.**

"Everything the iOS app does today" is deliberate, and narrower than `PRODUCT.md`. That document
describes the product we are building toward; iOS has not reached all of it either. Holding
Android to the same line iOS actually stands on is what makes eight weeks honest. What falls
outside that line is listed under *Out of scope*, with the reason each one is there.

The client sees a build every week. Each week's build has a story a non-engineer can hold in one
sentence, because a demo that needs explaining is a demo that did not land.

---

## Decisions locked

Settled before the first line of Kotlin. Recorded here so they are not re-litigated in week five.

| Decision | Choice | Why |
|---|---|---|
| Stack | Kotlin + Jetpack Compose, native, in `android/` | Deep's whole differentiator is custom motion and custom surfaces. The shared layer between platforms is `deep-api`, not the UI — a cross-platform client would forfeit the ceiling on both and still need native audio and native GL. |
| minSdk | 26 | Reaches ~97% of devices, which matters where the audience is. Everything below is designed to degrade, not to require a newer floor. |
| Globe renderer | OpenGL ES 3.0 via `GLSurfaceView` | `EarthSurface.metal` is a sphere-SDF raymarch feeding a threshold, ping-pong blur and composite bloom chain. That is a multi-pass pipeline, which GL does natively and AGSL does awkwardly — and AGSL is API 33+, which would raise the floor for the app's signature screen. |
| Design policy | Deep's design language, Android's mechanics | Identical palette, typography, motion curves, radii, spacing and copy. Navigation, predictive back, edge-to-edge insets, haptics and the media notification follow Android convention. Deep should feel like Deep, and like it belongs on the phone. |
| App shell | A custom Compose bottom bar wearing Deep's tokens | Not stock Material 3 — the tab bar frames every screen, and stock Material is the fastest way to look like a cheaper product. Not a reproduction of the iOS 26 Liquid Glass bar either; that is an OS affordance, and rebuilding it would cost a week and fight the platform. |
| Client delivery | A signed APK each week | No accounts, no review queues, nothing between a finished build and the client's hands. A proper distribution track is a v1.0.0 concern, not a week-one one. |

---

## The eight weeks

| Week | Ships | The story | Unblocks |
|---|---|---|---|
| 1 | `v0.0.1` | It moves like Deep, and it's talking to our server | Everything — the theme, the shell and the network layer are what every later week plugs into |
| 2 | `v0.0.2` | Make an account, and the app shapes itself around you | Every authenticated endpoint |
| 3 | `v0.0.3` | Sound that follows you across the app | The shared player the whole app leans on |
| 4 | `v0.0.4` | Practice grows something | The earn loop that gives weeks 5 and 6 something to spend |
| 5 | `v0.0.5` | Give a heart — and the app speaks Thai | Feature-complete except the world's pause |
| 6 | `v0.0.6` | The world pauses together | The globe has somewhere to live |
| 7 | `v0.0.7` | The globe lands, and the card lifts into the session | Feature parity reached |
| 8 | `v1.0.0` | Release | — |

### Week 1 — `v0.0.1` · It moves like Deep, and it's talking to our server

Week one is not "get something running". Three things sink an eight-week port, and all three are
decided now: theming left placeheld and done properly later, which never converges because Deep's
identity *is* its atmosphere; the globe left until week six; and the audio model deferred so long
that every screen is re-laid-out when it arrives.

So: the design-token layer for real, the atmosphere, bundled fonts, the five-tab shell, the
complete network layer, the home feed reading live from the backend, and one whole practice.

The home feed is the week's quiet trick. `GET /pause/home` and `GET /sound/home` both tolerate
anonymous requests, so the shelves render against the real API with no login built at all — which
is what lets onboarding wait a week and get built properly.

Also: the pure, platform-free iOS test suites port to JUnit, giving a behavioural parity harness
for the next seven weeks at almost no cost. And a spike on the globe runs in the background all
week. It produces no globe. It answers, by Friday, whether a GLES pipeline can carry that shader
at an acceptable frame budget — because discovering the answer in week six is how this misses
v1.0.0.

### Week 2 — `v0.0.2` · Make an account, and the app shapes itself around you

Onboarding end to end: the welcome, the two server-driven questions, the Mind Tree, and the
moment of shaping. Then accounts — signup, login, session restore, logout — and the root phase
machine that decides which of the three you see.

The mini player's design is settled this week, before week three builds it.

### Week 3 — `v0.0.3` · Sound that follows you across the app

Deep Sound: the shelves, collection detail, lyrics. Underneath, the real work — Media3, a
`MediaSessionService`, background playback and a proper media notification. Then the mini player
docked above the tab bar and the full Now Playing above that.

This is the week that changes the shape of every screen, which is why it is early.

### Week 4 — `v0.0.4` · Practice grows something

Mind Garden, the reward ritual, the practice journal with its offline sync queue, and the wallet.
By Friday a finished session banks sunlight, the plant grows toward its next form, and hearts
land in a balance. The loop closes.

### Week 5 — `v0.0.5` · Give a heart — and the app speaks Thai

The Compassion Portfolio and the donate flow. The You tab, settings, account deletion, and the
daily reminder. And the language switch — the iOS app carries 291 strings with Thai for 285 of
them, and the server localizes content off `Accept-Language`, so Thai is parity, not a bonus.

### Week 6 — `v0.0.6` · The world pauses together

Global Pause, minus the globe: the schedule, the clock synced to the server's, presence
heartbeats, the live poll, Fuku's Lounge, the peace-message feed and composer, the meditation
that cannot be paused, and reflection. The globe is a placeholder this week — everything around
it is real.

### Week 7 — `v0.0.7` · The globe lands, and the card lifts into the session

The Earth renderer, the glow that lights where people are, the sparks as they join, the ripples,
the touch raycast and its momentum. Then the card lift — the single transition where the globe
card becomes the session backdrop without a cut.

### Week 8 — `v1.0.0` · Release

A Thai pass over everything written since week five. Accessibility: reduced motion, font scaling,
increased contrast. The device matrix on real hardware. The adaptive and monochrome icon, and the
splash that has to land on the app's first frame without a jump. Release signing, and a
build-and-verify script that checks the artifact against every rejection a store would report
after upload — the same job `scripts/archive-central-flight.sh` does for iOS.

---

## Out of scope for v1.0.0

Each of these is out because **iOS does not have it either**. They are product work, not port
work, and pulling any of them in would mean shipping Android features the iPhone app lacks.

- **Sign in with Apple and Google.** `PRODUCT.md` names three login methods. The server implements
  one: `deep-api/src/routes/auth.ts` is email and password, with no OAuth of any kind and no Apple
  fields in the schema. Adding either is backend work first, and iOS would still be email-only.
- **Premium and Play Billing.** `Deep/Deep/Deep.storekit` exists with empty product arrays, and
  the server's `isPremium` flags gate nothing on the purchase side. Neither platform has a paywall.
- **The lounge's theme music and welcome lines.** Both already arrive in the schedule payload.
  Neither is played or shown on iOS.
- **Dark mode.** iOS pins `.light` at every coordinator. There is no dark palette to port.
- **Tablet layouts.** iOS is portrait-phone-first in practice.

---

## Not yet specified

Deliberately unfinished. These are questions we can see coming but cannot yet state sharply
enough to answer; each gets written up properly as the work reaches it.

- ~~**How the mini player docks.**~~ **Settled in week 2: a floating pill.** A frosted capsule
  (`frostedCard`) 8dp above `DeepBottomBar`, shown with `AnimatedVisibility` only while a track is
  loaded; it does not move on scroll, and scrolling screens add bottom padding while it shows.
  Tap or swipe up opens Now Playing through a shared-element transform; swipe down or predictive
  back shrinks it back into the pill. Hidden during a Deep Session and Global Pause live. Chosen
  over a tray fused into the bar (Android-conventional, but dense against Deep's airy bottom edge)
  and over an iOS-26-style collapsing pill (a nested-scroll inset every screen must track —
  close to rebuilding the OS bar). The collapse can still layer on later without undoing this.
- ~~**The onboarding ripple-reveal.**~~ **Settled in week 2:** `RippleReveal.metal` ported
  one-to-one to AGSL for API 33+; below that the still fades out over the same duration. Not yet
  seen on a real API 26–32 device — the emulator images here are 35 and 36.
- **A lost refresh response signs the member out.** deep-api commits the refresh-token rotation
  before it answers; if the answer never arrives, the client still holds the old token, and
  presenting it next time reads as theft (`token_reuse`) and revokes the session. Both clients
  share this. The fix is server-side — a short idempotency window on rotation — not a client
  change.
- **Finishing onboarding offline.** Both platforms complete onboarding locally even when the
  shaping step's `PUT /me/onboarding` fails, so the next online launch hydrates the server's
  `completed: false` and replays the flow. Parity for now; a pending-sync marker would fix both.
- **The rounded-font substitute.** Three type tokens use SF Rounded, which Android has no
  equivalent for. Nunito is in place for week 1, but it ships no `tnum` table, and the 96sp session
  numeral rolls as the length slider moves — so either it has uniform figures by default, or that
  token needs a different face.
- **A reminder in a spring-forward gap.** iOS skips the day when the chosen wall-clock time does
  not exist; Kotlin's `ZonedDateTime` resolves forward by the gap instead. No test covers it
  because Asia/Bangkok has no DST, but the two platforms would differ for a member elsewhere.
  Settle it when reminders ship in week 5.
- **The `versionCode` scheme.** iOS stamps Unix epoch seconds. `versionCode` is a signed 32-bit
  int that can never decrease on a store track, so that does not survive the port.
- **Whether the two platforms share a version source** or diverge on the record.
- **CI.** The repo has none for any platform. Whether Android is the excuse to add it, or whether
  that waits, is a week-8 question.

---

## Risks

| Risk | Mitigation |
|---|---|
| **The globe.** ~900 lines of Metal plus a multi-pass bloom chain, with no mechanical translation. The single largest unknown in the effort. | A spike in week 1 that answers the feasibility question seven weeks before the work is due, and a 2D placeholder in week 6 so Global Pause ships even if the globe slips. |
| **`maxInstances = 1` on Cloud Run.** Global Pause presence lives in an in-memory `Map` (`deep-api/src/lib/pausePresence.ts`), so a second instance splits participant counts. A second client platform, polling every five seconds, presses directly on that ceiling. | Not an Android problem to fix, but an Android problem to surface. Flag before week 6 load-tests it. |
| **Typography diverges from iOS by necessity.** iOS ships no font files; Android must bundle real ones. | Settled in week 1, reviewed side by side against iOS, and recorded here rather than discovered on a client call. |
| **No CI anywhere.** Every build and release step in this repo is a local script run by hand. | Accepted for the eight weeks. Revisited in week 8. |
| **Emulator-only testing until late.** Frame timings, blur cost and audio behaviour all mislead on an emulator. | Hardware checkpoint scheduled into the globe work; kept visible here until it happens. |

---

## How we ship

A branch per week, a PR into `dev`, screenshots in the PR, and a signed APK attached for the
client. Weekly, on the same day, whether or not the week went well — a slipped feature is a
conversation, and a missed build is a surprise.
