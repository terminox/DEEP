#!/usr/bin/env bash
#
# Unpacks Interaxon's LibMuse SDK (Muse 2 headband) so device builds can link it.
#
# The SDK is confidential under its licence and this repository is public, so it is
# never committed. This script copies Muse.framework from your local SDK archive into
# the gitignored Deep/Vendor/Muse/, gives it a module map (so Swift can `import Muse`
# without a bridging header), and writes the gitignored Deep/Config/MuseSDK.local.xcconfig
# that turns it on for device builds (Dev and TestFlight; see Deep/Config/Muse.xcconfig).
#
# Without it everything still builds, with a simulated headband. The SDK has no arm64
# simulator slice, so the simulator always uses the simulated headband anyway.
#
#   ./scripts/setup-muse-sdk.sh [path/to/libmuse_ios_8.0.9.tar.gz]
#   ./scripts/setup-muse-sdk.sh --remove     # back to the simulated headband only
#
# The archive path defaults to $MUSE_SDK_ARCHIVE, then to the copy in ~/Downloads.
# Nothing inside the archive is ever executed: only Muse.framework is extracted.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/Deep/Vendor/Muse"
LOCAL_XCCONFIG="$ROOT/Deep/Config/MuseSDK.local.xcconfig"
VERSION="8.0.9"
# libmuse_ios_8.0.9.tar.gz as downloaded from Interaxon (a checksum, not a secret).
SHA256="61eafbe22677ef72743e435a8789a1688a51f94ca3850f5f970facf3549443a5"
DEFAULT_ARCHIVE="$HOME/Downloads/Muse SDK _ RDK/Muse SDK/Muse SDK $VERSION/libmuse_ios_$VERSION.tar.gz"

die() { printf '✗ %s\n' "$1" >&2; exit 1; }
ok()  { printf '✓ %s\n' "$1"; }

if [ "${1:-}" = "--remove" ]; then
  rm -rf "$VENDOR" "$LOCAL_XCCONFIG"
  ok "Removed the Muse SDK. Builds now use the simulated headband. Clean the build folder (⇧⌘K)."
  exit 0
fi

ARCHIVE="${1:-${MUSE_SDK_ARCHIVE:-$DEFAULT_ARCHIVE}}"
[ -f "$ARCHIVE" ] || die "No SDK archive at: $ARCHIVE (pass its path, or set MUSE_SDK_ARCHIVE)"

actual="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[ "$actual" = "$SHA256" ] || die "Checksum mismatch for $ARCHIVE. Expected LibMuse iOS $VERSION ($SHA256), got $actual."

# The licence forbids publishing the SDK: refuse to write it anywhere git would track.
cd "$ROOT"
git check-ignore -q "Deep/Vendor/Muse/Muse.framework/Muse" \
  || die "Deep/Vendor/Muse/ is not gitignored. Refusing to unpack a confidential SDK into a tracked folder."
git check-ignore -q "Deep/Config/MuseSDK.local.xcconfig" \
  || die "Deep/Config/MuseSDK.local.xcconfig is not gitignored."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tar -xzf "$ARCHIVE" -C "$TMP" "libmuse_ios_$VERSION/Muse.framework"
FRAMEWORK="$TMP/libmuse_ios_$VERSION/Muse.framework"
[ -f "$FRAMEWORK/Muse" ] && [ -f "$FRAMEWORK/Headers/Muse.h" ] || die "The archive has no Muse.framework."
lipo -archs "$FRAMEWORK/Muse" | grep -qw arm64 || die "Muse.framework has no arm64 (device) slice."

# LibMuse ships no module map; this makes `import Muse` work from Swift.
mkdir -p "$FRAMEWORK/Modules"
cat > "$FRAMEWORK/Modules/module.modulemap" <<'MODULEMAP'
framework module Muse {
  umbrella header "Muse.h"
  export *
  module * { export * }
}
MODULEMAP

rm -rf "$VENDOR"
mkdir -p "$VENDOR"
mv "$FRAMEWORK" "$VENDOR/Muse.framework"

cat > "$LOCAL_XCCONFIG" <<'XCCONFIG'
// Written by scripts/setup-muse-sdk.sh — gitignored, never commit (LibMuse is confidential).
// Device builds only: LibMuse has no arm64 simulator slice.
DEEP_MUSE_FRAMEWORK_PATHS[sdk=iphoneos*] = "$(PROJECT_DIR)/Vendor/Muse"
// -ObjC loads LibMuse's Objective-C categories from the static archive; libc++ for its C++ core.
DEEP_MUSE_LDFLAGS[sdk=iphoneos*] = -ObjC -framework Muse -framework CoreBluetooth -framework ExternalAccessory -lc++
DEEP_MUSE_CONDITION[sdk=iphoneos*] = MUSE_SDK
XCCONFIG

ok "LibMuse $VERSION unpacked into Deep/Vendor/Muse (gitignored)."
ok "Wrote Deep/Config/MuseSDK.local.xcconfig: device builds of Dev and TestFlight now link Muse."
printf '  Clean the build folder (⇧⌘K) so Xcode picks up the new module.\n'
