# DEEP

> *"Pause. Breathe. Connect. Heal — together."*

Deep is a companion app for slowing down, feeling held, and reconnecting with self and others. It is built on the belief that healing happens in stillness, not stimulation — so it optimizes for regulation and gentle return rather than engagement.

The app is five tabs — **Global Pause · Sounds · Garden · Portfolio · You** — around one shared idea: a person can stop, breathe, and know they are not doing it alone. One sound player is shared across every tab, and a guided breathing session can be launched from anywhere.

For the design language — colour, motion, typography, the feeling of the thing — see `DESIGN.md`.

## Key Features

### Global Pause

The world breathing together. Deep holds one synchronized pause every night that anyone, anywhere, can join — the premise being that ten minutes of stillness is different when thousands of people are in it with you.

The experience is three surfaces:

- **Fuku's Lounge** — the Global Pause lobby, opened from the DJ Fuku card on the home feed. One slow scroll: DJ Fuku full-bleed at the top, an ON AIR pill, the live globe card (Metal-rendered, interactive, with country lookup and halo ripples as people join), and beneath it the peace-message feed — messages from around the world, paging in forever as you scroll. The lounge is where the lobby's other roles live: playing the nightly theme and showing the welcome lines (both planned; see below).
- **The live session** — tapping the globe card lifts it into a full-screen meditation, one continuous motion (the card and the session backdrop are literally the same view re-parented mid-flight). The session has exactly one state: the live meditation. It can only be entered while the nightly meditation window is open — outside it, the card's caption counts down to the next one and the tap rests. It joins the shared stream at the synced offset, the globe decelerates to rest, and the screen stays deliberately near-empty: a LIVE mark, how many people are pausing with you, a thin progress line. No transport — the meditation cannot be paused; leaving is the only exit.
- **Reflection** — when the meditation ends (the stream completes or the window closes), the session crossfades into a thank-you, a peace-message composer, an intention picker, and a mood check-in. Closing it lands you back where you were, the globe already turning again.

**Global Pause Schedule**
- DEEP provides 1 Global Pause session per day, everyday.
- 20:30 - 21:00 Bangkok timezone (UTC+7). The server resolves the exact windows; the app keeps its clock synced to the server's.

**Global Pause Phases**
1. Lobby opens (20:30 - 20:39:50)
- Play lobby music (Global Pause theme) in Fuku's Lounge. *Planned — the audio URL already arrives with the schedule.*
- The globe rotates around.

2. Welcome message (20:39:50 - 20:40)
- Show brief welcome message(s) in the lounge. *Planned — the lines already arrive with the schedule.*

3. Live meditation session (20:40 - 20:50) — *built*
- The globe decelerates to stop.
- Stream meditation sound, which cannot be paused. Everyone hears the same moment; latecomers join at the live offset.

4. Meditation ends & Feedback phase (20:50 - 21:00) — *built as reflection*
- The globe starts rotating again.
- Users can leave feedback, known as Peace Message (plus an intention and a mood). Messages are displayed in the lounge's feed.

*Today:* the lounge, the live session, reflection, and the peace-message feed all run against the backend — schedule, synced clock, presence heartbeats, live participant counts lighting the globe, joins rippling outward, message paging and posting. The lounge's theme music and welcome lines are the open work. For testing, the dev server can time-travel (`scripts/pause-time-travel.sh live|off`): `live` keeps the nightly meditation live until switched off, and every client follows through the production code path — no debug code in the app.


### Deep Session

The guided breath at the centre of the app. One session is six rounds of four seconds in and six seconds out — about a minute. The long exhale is deliberate: that ratio is the physiological sigh that settles the nervous system.

An orb swells and softens with your breath, a cue reads *breathe in* / *breathe out*, and the round count sits quietly beneath. You can pause and take your time. It ends on *"You're here now"* — never a score.

*Today:* fully working. It presents full-screen over the tab bar, so any tab can offer the same session; the Garden's daily practice card and Deep Sound's Breathe card both open this. One session ships (`balancingBreath`); the model supports any inhale/exhale/round pattern.

### Deep Sound

Somewhere to land when you don't want to be guided. Collections of soundscapes — an album's worth of tracks each, standing on their own without a creator's name attached — organised across five shelves: **Calm, Morning, Sleep, Deep Teacher, Deep Kids**.

Start something and it follows you: the player docks into the tab bar as a mini player and expands into a full Now Playing. A sound started here and a sound started in Global Pause are the same player.

*Today:* browsing, collection detail, the mini player, and Now Playing all work against a static library. The track model already distinguishes instrumental soundscapes from spoken-word guided meditations, so voice content can arrive without reshaping anything.

**System requirements**
- The screen fetches categories, items, and (maybe) layout from backend.
- Admins can manage categories, items, and (maybe) layout from admin panel.
- Sounds will use streaming system, not just in-app files.
- Some sounds may have lyrics. Lyrics support multiple languages.


### Mind Garden

Your practice, reflected back as growth rather than performance. There are no streaks to break and nothing to fail — the garden simply grows alongside you.

The screen greets you with today's minutes against a gentle goal, nudges you into today's practice, and shows your plants: **Seedling** at day one, **Sprout** at a week, **Bloom** at three weeks, a **Willow** at forty days. Later plants sit dormant until you reach them.

*Today:* the layout and the plant journey are built, driven by sample state. Nothing persists yet, and which plants are unlocked is hardcoded rather than derived from a real streak — wiring the garden to actual practice is the open work here.

### Compassion Portfolio

Where practice turns outward. Time spent in Deep earns hearts; hearts are given to causes; Deep donates real money to real partner organisations in proportion to where the community's hearts have gone.

You hold a balance, choose a cause — Peace & Well-being, Healthcare, Education, and others — and send a heart to it or to a specific project inside it. Each cause names its partner organisation and the share of giving it receives. Field reports come back from the ground so the loop closes: hearts given, lives touched, told plainly.

*Today:* the ledger is live and shared across every screen — sending a heart anywhere updates your balance and the cause's pooled total everywhere at once. Balances and causes are in-memory fixtures; nothing is earned from real practice and no money moves yet.

## Other Features

### Onboarding

Four steps before the app opens: a welcome, two questions, a choice, and a moment of shaping.

The questions are invitations, not a form — *"What brings you here today?"* and *"What do you long for right now?"* Then you pick a Mind Tree (**Oak**, steady and strong · **Sakura**, gentle and open · **Lotus**, calm and mindful · **Orange**, warm and joyful) as a small emblem of how you'd like to grow, and a quiet loader shapes your space.

*Today:* the flow is complete. Answers are kept as a flat question→answer map, so questions can be added or reordered without breaking anyone's saved state. The Mind Tree choice isn't persisted yet — connecting it to the Mind Garden is pending. Subscription plumbing exists (StoreKit and RevenueCat) but no paywall sits in the flow.

**System requirements**
- Persist answers, especially mind tree as it will affect Mind Garden feature soon in the future.

### Home

Home isn't a tab of its own — it's the root of **Global Pause**, which is deliberate: the world's pause is the first thing you see.

It's one slow scroll. A video sky stretches under the status bar, and the content rides up over it: the DJ Fuku lounge card (the doorway into Fuku's Lounge and the world's pause), a doorway into today's Deep Session, then the content shelves and an explore grid.

*Today:* the feed is built and navigable; every item opens a detail screen. The shelves below the two fixed cards are composed by the backend.

### Settings

The **You** tab. Your avatar, your name, how you signed in — and a log out that asks first, then gently returns you to the welcome flow rather than dumping you at a login wall.

*Today:* that's the whole tab. Settings proper — notifications, reminders, sound preferences, subscription management, data and privacy controls — aren't built.

## Status

Deep is a working prototype of the whole experience, backed by a real API (`deep-api`) where it matters most: the home feed's shelves, the sound library (streamed audio), and all of **Global Pause** — schedule, synced clock, presence, live counts, peace messages — are served by the backend. Onboarding persists locally: whether you finished it, and what you answered.

Two areas carry known gaps. The **Mind Garden** and **Compassion Portfolio** both display fixture state that nothing writes to — practice doesn't yet feed minutes, streaks, or hearts. And inside **Global Pause**, the lounge's remaining roles — the nightly theme music and the welcome lines — are modelled (the schedule already carries both) but not yet played or shown.

## Login

**System requirements**
- DEEP supports 3 login methods: Email/password, Apple, and Gmail

## Premium Feature & In-app Purchases

Subscribed users will have access to premium sounds in Deep Sound and exclusive plants (and theme) in Mind Garden.
