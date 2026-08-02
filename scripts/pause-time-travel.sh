#!/usr/bin/env bash
#
# Global Pause time travel — pins the dev server's clock just inside a phase
# window, so every client goes live (or ends) through the real code path.
# No client-side debug code involved: the app syncs its clock to serverNow
# on every response.
#
#   ./scripts/pause-time-travel.sh live    # jump into the live meditation
#   ./scripts/pause-time-travel.sh end     # end it (feedback window) → reflection
#   ./scripts/pause-time-travel.sh off     # back to real time
#   ./scripts/pause-time-travel.sh lobby|welcome|meditation|feedback   # raw phases
#
# Requires deep-api running with ALLOW_TIME_OVERRIDE=true in its .env (the
# route does not exist otherwise). A running session picks the jump up within
# ~5 s via its live poll; an idle app needs a foreground-cycle or relaunch.
set -euo pipefail

host="${DEEP_API_HOST:-localhost:8080}"

case "${1:-}" in
  live) phase="meditation" ;;
  end) phase="feedback" ;;
  off) phase="off" ;;
  lobby | welcome | meditation | feedback) phase="$1" ;;
  *)
    echo "usage: $0 live|end|off|lobby|welcome|meditation|feedback" >&2
    exit 2
    ;;
esac

if ! response=$(curl -sf -X POST "http://$host/dev/pause/time-travel" \
  -H 'Content-Type: application/json' -d "{\"phase\":\"$phase\"}"); then
  echo "error: could not reach the time-travel route on $host." >&2
  echo "       Is deep-api running with ALLOW_TIME_OVERRIDE=true in its .env?" >&2
  exit 1
fi

echo "$response"
if [ "$phase" != "off" ]; then
  echo "note: a running session follows within ~5 s; an idle app needs a foreground or relaunch."
fi
