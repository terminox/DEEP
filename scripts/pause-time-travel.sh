#!/usr/bin/env bash
#
# Global Pause time travel — "live" holds a meditation window perpetually open
# on the dev server (its clock loops inside the window), so the session can be
# entered any time until switched off. "countdown" counts ~15 minutes down into
# the live meditation, then wraps back to the countdown start, so you can watch
# the card's countdown reach 00:00 and flip live. No client-side debug code
# involved: the app syncs its clock to serverNow on every response.
#
#   ./scripts/pause-time-travel.sh live       # meditation live until switched off
#   ./scripts/pause-time-travel.sh countdown  # counts down into the meditation, then wraps
#   ./scripts/pause-time-travel.sh lobby      # loops the lobby phase, so Fuku's set replays
#   ./scripts/pause-time-travel.sh off        # real time (ends a running session → reflection)
#
# A day can hold more than one session, so an optional second argument picks
# which one: a 1-based position in clock order, or a session id. Left out, it
# takes whichever session is live now or coming up next.
#
#   ./scripts/pause-time-travel.sh live 2     # the day's second session
#   ./scripts/pause-time-travel.sh countdown 1
#
# The reply names the session it picked (slotId + meditationStartsAt), because
# with several on the schedule that is the first thing you want to know.
#
# "lobby" holds the lobby phase (lobbyStart → welcomeStart) open on a loop, which
# is where DJ Fuku's broadcast lives: the intro plays with sound, hands off to
# the time-of-day clip, the merged set streams, and the ON AIR badge goes dark
# when it ends — then the window wraps and it all runs again.
#
# Requires deep-api running with ALLOW_TIME_OVERRIDE=true in its .env (the
# route does not exist otherwise). A running session picks a change up within
# ~5 s via its live poll; an idle app needs a foreground-cycle or relaunch.
set -euo pipefail

host="${DEEP_API_HOST:-localhost:8080}"

case "${1:-}" in
  live | countdown | lobby | off) mode="$1" ;;
  *)
    echo "usage: $0 live|countdown|lobby|off [session]" >&2
    echo "       session: 1-based position in the day, or a session id" >&2
    exit 2
    ;;
esac

slot="${2:-}"
if [ -z "$slot" ]; then
  payload="{\"mode\":\"$mode\"}"
elif [[ "$slot" =~ ^[0-9]+$ ]]; then
  payload="{\"mode\":\"$mode\",\"slot\":$slot}"
else
  payload="{\"mode\":\"$mode\",\"slot\":\"$slot\"}"
fi

if ! response=$(curl -sf -X POST "http://$host/dev/pause/time-travel" \
  -H 'Content-Type: application/json' -d "$payload"); then
  echo "error: could not reach the time-travel route on $host, or it refused the" >&2
  echo "       session you asked for. Is deep-api running with" >&2
  echo "       ALLOW_TIME_OVERRIDE=true in its .env?" >&2
  exit 1
fi

echo "$response"
if [ "$mode" = "live" ] || [ "$mode" = "countdown" ] || [ "$mode" = "lobby" ]; then
  echo "note: a running session follows within ~5 s; an idle app needs a foreground or relaunch."
fi
