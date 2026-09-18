# Development

## First time on a machine

```bash
./scripts/dev-setup.sh          # point the Dev build at this Mac
cd deep-api
npm install
npm run db:up                   # Postgres in Docker, host port 5434
npm run db:migrate && npm run db:seed
npm run dev                     # http://localhost:8080
```

`dev-setup.sh` is idempotent — re-run it any time.

In a git worktree it also symlinks `deep-api/media/garden` and
`deep-api/media/uploads` to the main checkout. The database is shared by every
checkout, so without that link a worktree's API 404s on every row uploaded
through the admin, and Mind Trees and sound artwork fall back to bare gradients.
`media/audio/` is left alone — some of it is committed source.

## Running on a real iPhone

There is nothing to type. `dev-setup.sh` writes `Deep/Config/Local.xcconfig`
(gitignored) with this Mac's **mDNS name**, e.g. `Terminox-MBP.local:8080`, and
`Dev.xcconfig` picks it up through an optional `#include?`.

An mDNS name is used rather than the LAN IP on purpose: it does not change when
DHCP hands the Mac a new address, and mDNS is multicast on every interface, so the
same value works over Wi-Fi **and** over a USB-tethered link.

1. `./scripts/dev-setup.sh` (once per machine)
2. Start the API — `cd deep-api && npm run dev`
3. Build the **Deep Dev** scheme to the device
4. Tap **Allow** on the local-network prompt at first launch

The phone needs to be on the same Wi-Fi as the Mac, or USB-tethered with Personal
Hotspot over USB switched on.

### Using some other host

Any host works — a raw IP, a Tailscale name, an ngrok URL:

```bash
./scripts/dev-setup.sh --host 100.x.y.z
./scripts/dev-setup.sh --host 192.168.1.7 --port 9000
```

### Simulator

Nothing to do — the simulator uses the same mDNS host and resolves it through the
Mac's own network stack. One host covers simulator and device, which also means
the media URLs in a response are identical either way.

Delete `Local.xcconfig` and the Dev build falls back to `http://localhost:8080`,
which is simulator-only.

## Running the Android app

The Android app lives in `android/`, alongside the iOS app in `Deep/`. It talks to
the same `deep-api`, so the backend steps above are unchanged.

```bash
cd android
./gradlew :app:installDevDebug     # builds and installs on the running emulator
```

Four product flavors mirror the four `.xcconfig` environments — `dev`, `staging`,
`pilot`, `prod` — with the same suffix trick (`.dev`, `.staging`, `.pilot`, none),
so all four install side by side on one device, exactly as on iOS.

### The emulator needs no setup

Android has two localhosts. The emulator reaches this Mac at the constant
`10.0.2.2`, which is the Gradle default, so a fresh clone builds and talks to a
local API with nothing to configure.

```bash
$ANDROID_HOME/emulator/emulator -avd Medium_Phone_API_36 &
adb install -r app/build/outputs/apk/dev/debug/app-dev-debug.apk
```

### A physical Android device does need setup

Run `./scripts/dev-setup.sh` from the repo root. It writes
`android/local.properties` (gitignored) the way it writes `Deep/Config/Local.xcconfig`.

**It writes a LAN IP there, not the mDNS name iOS gets.** Android has no mDNS
responder in its C library, so a `.local` name does not resolve through the
ordinary lookup an HTTP client performs — `NsdManager` is a separate discovery API
that OkHttp never consults. So Android takes the DHCP churn that the mDNS name was
chosen to avoid, and the script has to be re-run when this Mac changes address.

Cleartext to that host is permitted by a `network_security_config.xml` that lives
only in the `dev` source set, so no shipping flavor can merge it.

### Guardrail

`:app:checkApiHosts` runs before every build, the Android twin of the
**Check dev API host** phase in the Xcode project: it fails the build with the fix
in the message rather than installing an app whose every request times out.

Note it is necessarily softer than the iOS one. Xcode knows at build time whether
an artifact is device-bound (`PLATFORM_NAME`); Gradle does not, because the same
`devDebug` APK installs on both. So the task catches an unreachable *literal*
(`localhost`, a cleartext shipping URL) rather than the emulator-versus-device
mismatch, which only the runtime can see.

### Driving the emulator headlessly

The Android counterpart of `baguette`:

```bash
adb shell input tap <x> <y>
adb shell input swipe <x1> <y1> <x2> <y2> <ms>
adb exec-out screencap -p > shot.png
adb shell am start -n io.appbeyond.freelance.deep.dev/io.appbeyond.freelance.deep.MainActivity
```

## Why media URLs just work

`deep-api` returns **absolute** URLs for audio and artwork. Those used to be built
from a fixed `PUBLIC_BASE_URL`, so every track came back as
`http://localhost:8080/...` and 404'd on a device even when the app itself was
pointed at the Mac correctly.

They now follow the request: `lib/media.ts` reads a request-scoped base URL that
`app.ts` sets from the incoming `Host` header, so the simulator, the phone and the
admin SPA each get URLs they can reach — from one server, with no configuration.

**An explicit `PUBLIC_BASE_URL` always wins.** Leave it unset locally; staging,
pilot and prod must set it. That is also the security boundary — a deployed API
never trusts a client-supplied `Host` header.

## Guardrail

The app target has a **Check dev API host** build phase. A Dev build for a
physical device that still points at `localhost` fails at build time with the fix
in the error message, instead of installing an app whose every request times out.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Build fails: "still points at localhost" | Run `./scripts/dev-setup.sh`, then build again. |
| Every request times out on device | Local Network permission was denied. Settings ▸ DEEP Dev ▸ Local Network. |
| `.local` will not resolve | Guest/corporate Wi-Fi often blocks mDNS. Re-run with `--host <the Mac's IP>`. |
| App loads, but audio and artwork 404 | `PUBLIC_BASE_URL` is set in `deep-api/.env` — likely a `.env` predating this setup. `./scripts/dev-setup.sh --fix-env`, then restart the API. |
| Artwork 404s only when the API runs from a worktree | `deep-api/media/garden` is a real directory instead of a symlink to the main checkout. `./scripts/dev-setup.sh`, then restart the API. |
| Onboarding offers "Try again" instead of Mind Trees | `GET /onboarding/config` failed three times. The API is down, or the Dev host is unreachable — check `curl $(…)/health`. The flow never falls back to bundled trees. |
| Device build fails to sign | The Dev bundle id is `io.appbeyond.freelance.Deep.dev` and needs its own profile with Sign In with Apple. Build once from the Xcode UI, which auto-creates it; CLI `xcodebuild` cannot. |
| `npm run dev` exits immediately | No `deep-api/.env`. Run `./scripts/dev-setup.sh`. |
| Server starts but every DB call fails | Postgres is not up — `npm run db:up`. |
| Port 8080 already in use | A server from another worktree. `lsof -nP -iTCP:8080 -sTCP:LISTEN` |

## Simulator testing

See `CLAUDE.md` — headless control is via `baguette`, not the Simulator UI.

## Global Pause time travel

A Global Pause only goes live inside its own few minutes of the day. To test it
any time, shift the *server's* clock — every client syncs to `serverNow` on
every response, so the whole app follows through the production code path
(there is no debug code in the app):

```bash
./scripts/pause-time-travel.sh live       # meditation live until switched off
./scripts/pause-time-travel.sh countdown  # counts down into the meditation, then wraps
./scripts/pause-time-travel.sh off        # back to real time
```

A day can hold more than one session (the dev seed makes two: 08:10 and 20:40
Bangkok). An optional second argument picks which — a 1-based position in clock
order, or a session id — and the reply names the one it chose:

```bash
./scripts/pause-time-travel.sh live 2        # the day's second session
./scripts/pause-time-travel.sh countdown 1   # count down into the morning one
```

Left out, it takes whichever session is live now or coming up next, which is
what it always did when there was only ever one. Session times are managed in
the admin panel under Schedule.

`live` is sticky: the server's clock loops inside that session's meditation
window, so the session stays enterable no matter how long ago you ran it. Each pass
still elapses like a real night — a session that runs its course ends into
the reflection screen naturally. To end one early, run `off`: real time is
outside the window, so a running session crossfades into reflection within
~5 s via its live poll.

`countdown` loops server time from 15 minutes before the meditation through
its end, so you can watch the card's countdown reach 00:00 and flip live,
play through the meditation, then wrap back to counting down again. The
15-minute lead is an iOS-side constant (`GlobalPauseSession.countdownLead`)
mirrored by the route — it's dev tooling only, so a mismatch there would only
skew the dev preview.

Notes:
- Requires `ALLOW_TIME_OVERRIDE=true` in `deep-api/.env` (the route does not
  exist otherwise, and must never be set anywhere real).
- A running session picks a change up within ~5 s via its live poll. An idle
  app notices on foreground or relaunch — background-and-reopen after `live`.
- The switch is in-memory: restarting `deep-api` returns to real time.
- It affects every client of that dev server — handy for watching two
  simulators go live together.
