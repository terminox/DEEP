#!/usr/bin/env bash
#
# Downloads the GeoLite2-City database used by src/lib/geoip.ts for Global
# Pause's IP geolocation. Requires a free MaxMind license key:
# https://www.maxmind.com/en/geolite2/signup
#
#   MAXMIND_LICENSE_KEY=xxxx ./scripts/geoip-update.sh
#
# ...or set MAXMIND_LICENSE_KEY in deep-api/.env. Without a key present,
# geoip.ts falls back to null lookups and Global Pause shows country-only
# presence, so this script (and the key) is optional.
set -euo pipefail

cd "$(dirname "$0")/.."

license_key="${MAXMIND_LICENSE_KEY:-}"
if [ -z "$license_key" ] && [ -f .env ]; then
  license_key="$(grep -E '^MAXMIND_LICENSE_KEY=' .env | tail -1 | cut -d= -f2- | tr -d '"')"
fi

if [ -z "$license_key" ]; then
  echo "error: MAXMIND_LICENSE_KEY is not set." >&2
  echo "       Set it in the environment or in deep-api/.env, then re-run." >&2
  echo "       Get a free key at https://www.maxmind.com/en/geolite2/signup" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "downloading GeoLite2-City..."
if ! curl -sf "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${license_key}&suffix=tar.gz" \
  -o "$tmp_dir/geolite.tar.gz"; then
  echo "error: download failed. Is MAXMIND_LICENSE_KEY valid?" >&2
  exit 1
fi

tar -xzf "$tmp_dir/geolite.tar.gz" -C "$tmp_dir"

mmdb_path="$(find "$tmp_dir" -name '*.mmdb' -print -quit)"
if [ -z "$mmdb_path" ]; then
  echo "error: no .mmdb file found in the downloaded archive." >&2
  exit 1
fi

mkdir -p geoip
mv "$mmdb_path" geoip/GeoLite2-City.mmdb

echo "geoip/GeoLite2-City.mmdb updated."
