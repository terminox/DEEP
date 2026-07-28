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
| App loads, but audio and artwork 404 | `PUBLIC_BASE_URL` is set in `deep-api/.env`. Comment it out. |
| `npm run dev` exits immediately | No `deep-api/.env`. Run `./scripts/dev-setup.sh`. |
| Server starts but every DB call fails | Postgres is not up — `npm run db:up`. |
| Port 8080 already in use | A server from another worktree. `lsof -nP -iTCP:8080 -sTCP:LISTEN` |

## Simulator testing

See `CLAUDE.md` — headless control is via `baguette`, not the Simulator UI.
