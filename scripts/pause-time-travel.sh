#!/usr/bin/env bash
#
# Global Pause time travel — "live" holds the nightly meditation window
# perpetually open on the dev server (its clock loops inside the window), so
# the session can be entered any time until switched off. No client-side debug
# code involved: the app syncs its clock to serverNow on every response.
#
#   ./scripts/pause-time-travel.sh live   # meditation live until switched off
#   ./scripts/pause-time-travel.sh off    # real time (ends a running session → reflection)
#
# Requires deep-api running with ALLOW_TIME_OVERRIDE=true in its .env (the
# route does not exist otherwise). A running session picks a change up within
# ~5 s via its live poll; an idle app needs a foreground-cycle or relaunch.
set -euo pipefail

host="${DEEP_API_HOST:-localhost:8080}"

case "${1:-}" in
  live | off) mode="$1" ;;
  *)
    echo "usage: $0 live|off" >&2
    exit 2
    ;;
esac

if ! response=$(curl -sf -X POST "http://$host/dev/pause/time-travel" \
  -H 'Content-Type: application/json' -d "{\"mode\":\"$mode\"}"); then
  echo "error: could not reach the time-travel route on $host." >&2
  echo "       Is deep-api running with ALLOW_TIME_OVERRIDE=true in its .env?" >&2
  exit 1
fi

echo "$response"
if [ "$mode" = "live" ]; then
  echo "note: a running session follows within ~5 s; an idle app needs a foreground or relaunch."
fi
