#!/usr/bin/env bash
# Generates a handful of royalty-free ambient loops (soft sine hum + filtered
# pink noise) so tracks have real audio to stream locally. No downloads, no
# licensing. One file per Deep Sound category.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)/media/audio"
mkdir -p "$DIR"

gen() {
  local name="$1" freq="$2"
  if [ -f "$DIR/$name.mp3" ]; then
    echo "skip $name.mp3 (exists)"
    return
  fi
  ffmpeg -y -loglevel error \
    -f lavfi -i "sine=frequency=${freq}:duration=60" \
    -f lavfi -i "anoisesrc=d=60:c=pink:a=0.05" \
    -filter_complex "[0:a]volume=0.10,tremolo=f=0.1:d=0.6[t];[1:a]lowpass=f=700[n];[t][n]amix=inputs=2:duration=shortest,volume=1.4,afade=t=in:d=3,afade=t=out:st=57:d=3" \
    -ac 2 -ar 44100 -b:a 128k "$DIR/$name.mp3"
  echo "made $name.mp3"
}

gen calm 174
gen morning 285
gen sleep 136
gen teacher 210
gen kids 396

echo "Audio assets ready in $DIR"
