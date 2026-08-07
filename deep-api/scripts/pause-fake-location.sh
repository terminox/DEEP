#!/usr/bin/env bash
#
# Dev override for Global Pause's IP geolocation, so the globe's points can be
# exercised without real participants spread across the world.
#
#   ./scripts/pause-fake-location.sh off              # real IP lookups
#   ./scripts/pause-fake-location.sh fixed 35.6 139.7  # pin every new join here
#   ./scripts/pause-fake-location.sh scatter 40        # seed 40 fake presences
#   ./scripts/pause-fake-location.sh drip 10 2         # join 10 fake participants, 2s apart
#
# Requires deep-api running with ALLOW_TIME_OVERRIDE=true in its .env (the
# route does not exist otherwise).
set -euo pipefail

host="${DEEP_API_HOST:-localhost:8080}"

mode="${1:-}"
case "$mode" in
  off)
    body='{"mode":"off"}'
    ;;
  fixed)
    lat="${2:-}"
    lon="${3:-}"
    if [ -z "$lat" ] || [ -z "$lon" ]; then
      echo "usage: $0 fixed <lat> <lon>" >&2
      exit 2
    fi
    body="{\"mode\":\"fixed\",\"lat\":$lat,\"lon\":$lon}"
    ;;
  scatter)
    n="${2:-}"
    if [ -z "$n" ]; then
      echo "usage: $0 scatter <n>" >&2
      exit 2
    fi
    body="{\"mode\":\"scatter\",\"seed\":$n}"
    ;;
  drip)
    n="${2:-}"
    interval_s="${3:-4}"
    if [ -z "$n" ]; then
      echo "usage: $0 drip <n> [interval-seconds]" >&2
      exit 2
    fi
    interval_ms=$(awk "BEGIN { printf \"%d\", $interval_s * 1000 }")
    body="{\"mode\":\"drip\",\"seed\":$n,\"intervalMs\":$interval_ms}"
    ;;
  *)
    echo "usage: $0 off|fixed <lat> <lon>|scatter <n>|drip <n> [interval-seconds]" >&2
    exit 2
    ;;
esac

if ! response=$(curl -sf -X POST "http://$host/dev/pause/fake-location" \
  -H 'Content-Type: application/json' -d "$body"); then
  echo "error: could not reach the fake-location route on $host." >&2
  echo "       Is deep-api running with ALLOW_TIME_OVERRIDE=true in its .env?" >&2
  exit 1
fi

echo "$response"
