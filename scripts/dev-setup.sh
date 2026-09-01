#!/usr/bin/env bash
#
# Points the DEEP Dev build at this Mac so it works on a physical iPhone.
#
# Prefers the Mac's mDNS name (e.g. my-mbp.local) over its LAN IP: the name
# survives DHCP handing out a new address, and mDNS is multicast on every
# interface, so it resolves over Wi-Fi and over a USB-tethered link alike.
# That is what removes the "re-enter my IP every time" step.
#
# Idempotent — safe to re-run whenever anything drifts.
#
#   ./scripts/dev-setup.sh                      # auto-detect (what you normally want)
#   ./scripts/dev-setup.sh --host 192.168.1.7   # force a host: raw IP, Tailscale name, ngrok
#   ./scripts/dev-setup.sh --port 9000          # non-default API port
#   ./scripts/dev-setup.sh --fix-env            # also comment out PUBLIC_BASE_URL in deep-api/.env
#   DEEP_DEV_HOST=my-mbp.local ./scripts/dev-setup.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCCONFIG="$ROOT/Deep/Config/Local.xcconfig"
API_ENV="$ROOT/deep-api/.env"
API_ENV_EXAMPLE="$ROOT/deep-api/.env.example"

if [ -t 1 ]; then
  bold=$'\033[1m'; dim=$'\033[2m'; green=$'\033[32m'; yellow=$'\033[33m'; reset=$'\033[0m'
else
  bold=""; dim=""; green=""; yellow=""; reset=""
fi
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$1"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$1"; }
die()  { printf '\n%serror:%s %s\n' "$yellow" "$reset" "$1" >&2; exit 1; }

host="${DEEP_DEV_HOST:-}"
port=8080
fix_env=0
while [ $# -gt 0 ]; do
  case "$1" in
    --host) host="${2:-}"; shift 2 || die "--host needs a value" ;;
    --port) port="${2:-}"; shift 2 || die "--port needs a value" ;;
    --fix-env) fix_env=1; shift ;;
    # Prints the header comment, however long it happens to be.
    -h|--help) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# Resolvable from this Mac is a decent proxy for resolvable from the phone:
# both go through the same mDNS responder on the same link.
resolves() {
  ping -c 1 -t 2 "$1" >/dev/null 2>&1 ||
    dscacheutil -q host -a name "$1" 2>/dev/null | grep -q 'ip_address'
}

printf '\n%sDEEP dev setup%s\n\n' "$bold" "$reset"

if [ -n "$host" ]; then
  ok "Using the host you specified: $host"
else
  mdns="$(scutil --get LocalHostName 2>/dev/null || true).local"
  if [ "$mdns" != ".local" ] && resolves "$mdns"; then
    host="$mdns"
    ok "Resolved this Mac's mDNS name: $host"
  else
    iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
    host="$(ipconfig getifaddr "${iface:-en0}" 2>/dev/null || true)"
    [ -n "$host" ] || die "could not work out how to reach this Mac. Connect to a network, or pass --host <ip>."
    warn "mDNS name did not resolve; falling back to the LAN IP $host"
    warn "That address is DHCP-assigned and will change eventually — re-run this script when it does."
  fi
fi

base_url="http://$host:$port"

# ---- 1. iOS: the gitignored per-machine host ----
cat > "$XCCONFIG" <<EOF
// Written by scripts/dev-setup.sh — gitignored, per-machine.
// Overrides the localhost default in Dev.xcconfig so device builds can reach
// this Mac. Re-run the script to regenerate; delete it to fall back to
// localhost (simulator only).
DEV_API_HOST = $host:$port
EOF
ok "Wrote Deep/Config/Local.xcconfig"

# ---- 2. Backend: make sure it can start at all ----
if [ -f "$API_ENV" ]; then
  if grep -Eq '^[[:space:]]*PUBLIC_BASE_URL[[:space:]]*=' "$API_ENV"; then
    # A .env predating this setup almost certainly carries the old
    # PUBLIC_BASE_URL="http://localhost:8080" default, which pins every audio and
    # artwork URL to localhost and 404s on a device. Never rewritten silently —
    # this file holds secrets, so the edit is opt-in and keeps a backup.
    if [ "$fix_env" = "1" ]; then
      cp "$API_ENV" "$API_ENV.bak"
      sed -i '' -E 's/^([[:space:]]*PUBLIC_BASE_URL[[:space:]]*=)/# \1/' "$API_ENV"
      ok "Commented out PUBLIC_BASE_URL in deep-api/.env (backup at .env.bak)"
      warn "Restart the API for that to take effect."
    else
      warn "deep-api/.env sets PUBLIC_BASE_URL - that pins media URLs to one origin,"
      warn "so audio and artwork will 404 on the device. Re-run with --fix-env to"
      warn "comment it out (a .env.bak backup is kept), or edit it yourself."
    fi
  else
    ok "deep-api/.env looks right (PUBLIC_BASE_URL unset, so media URLs follow the request)"
  fi
else
  cp "$API_ENV_EXAMPLE" "$API_ENV"
  ok "Created deep-api/.env from .env.example"
  warn "Set a real JWT_SECRET in deep-api/.env before doing anything that matters."
fi

# ---- 2b. Backend: share runtime media across git worktrees ----
# The database is shared by every checkout, but MEDIA_DIR resolves ./media
# against whichever one launched the API. Artwork uploaded through the admin
# therefore lands only in the checkout that served the upload, and every other
# one 404s on the rows pointing at it - Mind Trees and sound artwork silently
# degrade to bare gradients. media/garden/ and media/uploads/ are gitignored
# runtime data, so symlink them to the main checkout and every worktree serves
# the same files. media/audio/ is NOT linked: some of it is committed source.
main_root="$(dirname "$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)")"

link_shared_media() {
  local name="$1"
  local target="$main_root/deep-api/media/$name"
  local link="$ROOT/deep-api/media/$name"
  mkdir -p "$target"
  if [ -L "$link" ]; then
    ln -sfn "$target" "$link"
    ok "media/$name -> main checkout"
  elif [ -d "$link" ] && [ -n "$(ls -A "$link" 2>/dev/null)" ]; then
    warn "deep-api/media/$name already holds files; leaving it alone. Move them"
    warn "into $target and delete the directory to share them."
  else
    rmdir "$link" 2>/dev/null || true
    ln -sfn "$target" "$link"
    ok "media/$name -> main checkout"
  fi
}

if [ "$main_root" = "$ROOT" ]; then
  ok "Media lives in this checkout (deep-api/media)"
else
  mkdir -p "$ROOT/deep-api/media"
  link_shared_media garden
  link_shared_media uploads
fi

# ---- 3. Tell the developer where things stand ----
printf '\n%sDev build will talk to%s  %s\n' "$bold" "$reset" "$base_url"

if curl -fsS -m 2 "$base_url/health" >/dev/null 2>&1; then
  printf '\n'; ok "The API is up and answering on that URL."
else
  printf '\n'; warn "Nothing answering there yet. Start it with:"
  printf '      %scd deep-api && npm run db:up && npm run dev%s\n' "$dim" "$reset"
fi

cat <<EOF

${bold}On the iPhone${reset}
  1. Build the ${bold}Deep Dev${reset} scheme to the device (Wi-Fi or USB both fine).
  2. Tap ${bold}Allow${reset} on the "DEEP would like to find devices on your local
     network" prompt — without it, .local names cannot resolve.
  3. The phone must be on the same Wi-Fi as this Mac, or USB-tethered with
     Personal Hotspot over USB enabled.

Full runbook and troubleshooting: ${bold}DEVELOPMENT.md${reset}

EOF
