#!/usr/bin/env bash
# Generates a handful of royalty-free ambient loops (soft sine hum + filtered
# pink noise) so tracks have real audio to stream locally. No downloads, no
# licensing. One file per Deep Sound category.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)/media/audio"
mkdir -p "$DIR"

gen() {
  local name="$1" freq="$2" dur="${3:-60}"
  if [ -f "$DIR/$name.mp3" ]; then
    echo "skip $name.mp3 (exists)"
    return
  fi
  ffmpeg -y -loglevel error \
    -f lavfi -i "sine=frequency=${freq}:duration=${dur}" \
    -f lavfi -i "anoisesrc=d=${dur}:c=pink:a=0.05" \
    -filter_complex "[0:a]volume=0.10,tremolo=f=0.1:d=0.6[t];[1:a]lowpass=f=700[n];[t][n]amix=inputs=2:duration=shortest,volume=1.4,afade=t=in:d=3,afade=t=out:st=$((dur - 3)):d=3" \
    -ac 2 -ar 44100 -b:a 128k "$DIR/$name.mp3"
  echo "made $name.mp3"
}

gen calm 174
gen morning 285
gen sleep 136
gen teacher 210
gen kids 396

# Global Pause event audio. The real lobby theme lives in ../references/
# (global-pause.mp3) and is preferred when present; the generated tones are
# only placeholders so a fresh checkout still serves both endpoints.
# inner-light runs 600s so mid-stream meditation joins have room to seek.
if [ -f "$DIR/../../../references/global-pause.mp3" ] && [ ! -f "$DIR/global-pause.mp3" ]; then
  cp "$DIR/../../../references/global-pause.mp3" "$DIR/global-pause.mp3"
  echo "copied global-pause.mp3 from references/"
fi
gen global-pause 432 90
gen inner-light 528 600

echo "Audio assets ready in $DIR"
