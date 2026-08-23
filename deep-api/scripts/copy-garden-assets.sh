#!/usr/bin/env bash
#
# Copies the oak Mind Garden assets bundled in the iOS app into
# media/garden/{images,videos}/ so the seed's oak stages have real art to
# point at. Source of truth is the iOS asset catalog / bundle — this script
# just mirrors those files server-side; it does not generate anything.
#
#   ./scripts/copy-garden-assets.sh
#
# Idempotent: safe to re-run; always overwrites the destination with the
# current source file.
set -euo pipefail

cd "$(dirname "$0")/.."

# deep-api/ -> repo root -> Deep/
repo_root="$(cd .. && pwd)"
assets_dir="$repo_root/Deep/Deep/Assets.xcassets"
resources_dir="$repo_root/Deep/Deep/Features/MindGarden/Resources"

images_dst="media/garden/images"
videos_dst="media/garden/videos"
mkdir -p "$images_dst" "$videos_dst"

# Finds the single PNG inside an .imageset directory (there's exactly one
# scale per oak imageset today; if that ever changes, pick the largest file).
find_imageset_png() {
  local imageset_dir="$1"
  find "$imageset_dir" -maxdepth 1 -name '*.png' -print0 | xargs -0 ls -S 2>/dev/null | head -n 1
}

copy_stage_image() {
  local imageset_name="$1" dest_name="$2"
  local imageset_dir="$assets_dir/${imageset_name}.imageset"
  if [ ! -d "$imageset_dir" ]; then
    echo "error: missing imageset $imageset_dir" >&2
    exit 1
  fi
  local src
  src="$(find_imageset_png "$imageset_dir")"
  if [ -z "$src" ]; then
    echo "error: no .png found in $imageset_dir" >&2
    exit 1
  fi
  cp "$src" "$images_dst/$dest_name"
  echo "copied $src -> $images_dst/$dest_name"
}

copy_stage_image "MindGardenOakSeedling" "oak-seedling.png"
copy_stage_image "MindGardenOakYoung" "oak-young.png"
copy_stage_image "MindGardenOakMature" "oak-mature.png"

video_src="$resources_dir/deep_oak_mature.mp4"
if [ ! -f "$video_src" ]; then
  echo "error: missing video $video_src" >&2
  exit 1
fi
cp "$video_src" "$videos_dst/oak-mature.mp4"
echo "copied $video_src -> $videos_dst/oak-mature.mp4"

echo "garden assets ready in $images_dst and $videos_dst."
