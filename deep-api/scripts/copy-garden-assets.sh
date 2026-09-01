#!/usr/bin/env bash
#
# Copies the oak Mind Garden artwork into media/garden/{images,videos}/ so the
# seed's oak stages have real art to point at.
#
#   ./scripts/copy-garden-assets.sh
#
# Source of truth is references/oak/ at the repo root — the same art the iOS
# bundle ships, and the copy that is committed. (This script used to read
# MindGardenOak*.imageset out of the asset catalog; those imagesets were
# deleted, which left `npm run seed:assets` failing and, in turn, `npm run seed`
# throwing on a fresh clone.)
#
# media/garden/ is gitignored runtime data. In a git worktree that directory is
# usually a symlink to the main checkout — see scripts/dev-setup.sh — so
# everything written here is shared by every checkout on this machine.
#
# Idempotent: safe to re-run; always overwrites the destination with the
# current source file.
set -euo pipefail

cd "$(dirname "$0")/.."

# deep-api/ -> repo root -> references/oak/
repo_root="$(cd .. && pwd)"
oak_dir="$repo_root/references/oak"

images_dst="media/garden/images"
videos_dst="media/garden/videos"
mkdir -p "$images_dst" "$videos_dst"

copy_asset() {
  local src_name="$1" dst="$2"
  local src="$oak_dir/$src_name"
  if [ ! -f "$src" ]; then
    echo "error: missing source asset $src" >&2
    exit 1
  fi
  cp "$src" "$dst"
  echo "copied $src_name -> $dst"
}

copy_asset "deep_oak_seedling.png" "$images_dst/oak-seedling.png"
copy_asset "deep_oak_young.png"    "$images_dst/oak-young.png"
copy_asset "deep_oak_mature.png"   "$images_dst/oak-mature.png"
copy_asset "deep_oak_mature.mp4"   "$videos_dst/oak-mature.mp4"

echo "garden assets ready in $images_dst and $videos_dst."
