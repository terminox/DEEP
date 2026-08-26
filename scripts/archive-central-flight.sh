#!/usr/bin/env bash
#
# Builds a signed .ipa of DEEP for App Store Connect / TestFlight.
#
# Central Flight is a distribution vehicle, not an environment: the build talks to
# production exactly as the Prod configuration does, but wears a reusable client-facing
# App ID (com.kanekohouse.centralflight) so it can reach TestFlight without touching
# Deep's own App Store record. See Deep/Config/CentralFlight.xcconfig.
#
# The build number is Unix epoch seconds, stamped into that xcconfig so the tree records
# what shipped and an Xcode Organizer archive agrees with a CLI one. Commit the stamp
# alongside whatever you distributed.
#
# Uploading is left to you — the script stops at a verified .ipa and prints the validate
# command.
#
#   ./scripts/archive-central-flight.sh               # stamp, archive, export, verify
#   ./scripts/archive-central-flight.sh --keep-build  # reuse the committed build number
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCCONFIG="$ROOT/Deep/Config/CentralFlight.xcconfig"
PROJECT="$ROOT/Deep/Deep.xcodeproj"
EXPORT_OPTIONS="$ROOT/scripts/central-flight-export-options.plist"
BUILD_DIR="$ROOT/Deep/build"
ARCHIVE="$BUILD_DIR/CentralFlight.xcarchive"
IPA_DIR="$BUILD_DIR/ipa"
LOG_DIR="$BUILD_DIR/logs"
BUNDLE_ID="com.kanekohouse.centralflight"

if [ -t 1 ]; then
  bold=$'\033[1m'; dim=$'\033[2m'; green=$'\033[32m'; red=$'\033[31m'; reset=$'\033[0m'
else
  bold=""; dim=""; green=""; red=""; reset=""
fi
step() { printf '\n%s==>%s %s\n' "$bold" "$reset" "$1"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$1"; }
die()  { printf '  %s✗%s %s\n' "$red" "$reset" "$1" >&2; exit 1; }

KEEP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --keep-build) KEEP_BUILD=1 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

# `xcodebuild | tail` exits 0 even when the build failed, so never pipe it: send the log
# to a file, check the real exit code, then insist on the literal success line.
run_xcodebuild() {
  local log="$1"; shift
  local status=0
  xcodebuild "$@" >"$log" 2>&1 || status=$?
  if [ "$status" -ne 0 ]; then
    grep -E '(^| )error:' "$log" | head -20 >&2 || true
    die "xcodebuild exited $status — full log: ${log/#$ROOT\//}"
  fi
}

mkdir -p "$LOG_DIR"

# ---- 1. stamp -----------------------------------------------------------------
step "Stamping the build number"
if [ "$KEEP_BUILD" -eq 1 ]; then
  BUILD_NUMBER="$(sed -n 's/^CURRENT_PROJECT_VERSION = //p' "$XCCONFIG" | tail -1)"
  [ -n "$BUILD_NUMBER" ] || die "no CURRENT_PROJECT_VERSION in ${XCCONFIG/#$ROOT\//}"
  ok "reusing committed build number $BUILD_NUMBER"
else
  BUILD_NUMBER="$(date +%s)"
  # Rewrite in place, then prove it took — a silent no-op here ships a duplicate build
  # number, which App Store Connect only rejects after the upload.
  /usr/bin/sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$XCCONFIG"
  grep -q "^CURRENT_PROJECT_VERSION = $BUILD_NUMBER\$" "$XCCONFIG" \
    || die "failed to stamp CURRENT_PROJECT_VERSION into ${XCCONFIG/#$ROOT\//}"
  ok "CURRENT_PROJECT_VERSION = $BUILD_NUMBER"
fi

# ---- 2. archive ---------------------------------------------------------------
step "Archiving"
rm -rf "$ARCHIVE" "$IPA_DIR"
run_xcodebuild "$LOG_DIR/archive.log" archive \
  -project "$PROJECT" \
  -scheme "Deep CentralFlight" \
  -configuration CentralFlight \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE"
grep -q '\*\* ARCHIVE SUCCEEDED \*\*' "$LOG_DIR/archive.log" \
  || die "no ARCHIVE SUCCEEDED in the log"
ok "${ARCHIVE/#$ROOT\//}"

# ---- 3. export ----------------------------------------------------------------
step "Exporting"
run_xcodebuild "$LOG_DIR/export.log" -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$IPA_DIR"
grep -q '\*\* EXPORT SUCCEEDED \*\*' "$LOG_DIR/export.log" \
  || die "no EXPORT SUCCEEDED in the log"

IPA="$(find "$IPA_DIR" -maxdepth 1 -name '*.ipa' | head -1)"
[ -n "$IPA" ] || die "export produced no .ipa"
ok "${IPA/#$ROOT\//} ($(du -h "$IPA" | cut -f1 | tr -d ' '))"

# ---- 4. verify ----------------------------------------------------------------
# Every check here stands in for a rejection Apple would otherwise report after upload.
step "Verifying the .ipa"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' | head -1)"
[ -n "$APP" ] || die "no .app inside Payload/"
PLIST="$APP/Info.plist"

expect() { # key expected-value
  local got
  got="$(/usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null || true)"
  [ "$got" = "$2" ] || die "$1 is '${got:-<missing>}', expected '$2'"
  ok "$1 = $got"
}
expect CFBundleIdentifier "$BUNDLE_ID"
expect CFBundleShortVersionString "1.0.0"
expect CFBundleVersion "$BUILD_NUMBER"
expect AppEnvironment "prod"
# Missing at the top level is ITMS-90713 — actool writes it only nested under CFBundleIcons.
expect CFBundleIconName "AppIcon"

[ -f "$APP/PrivacyInfo.xcprivacy" ] || die "PrivacyInfo.xcprivacy missing from the bundle"
ok "PrivacyInfo.xcprivacy bundled"
[ ! -e "$APP/Deep.storekit" ] || die "Deep.storekit was bundled into a shipping build"
ok "Deep.storekit not bundled"

EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
ARCHS="$(lipo -archs "$APP/$EXECUTABLE")"
[ "$ARCHS" = "arm64" ] || die "architectures are '$ARCHS', expected arm64"
ok "arm64"

ENTS="$(codesign -d --entitlements :- "$APP" 2>/dev/null)"
grep -q 'beta-reports-active' <<<"$ENTS" || die "not a TestFlight-capable signature"
grep -A1 'get-task-allow' <<<"$ENTS" | grep -q '<false/>' \
  || die "get-task-allow is true — a development signature, not a distribution one"
ok "distribution signature, TestFlight enabled"
codesign -dvvv "$APP" 2>&1 | sed -n 's/^Authority=/  · /p' | head -1

# ---- done ---------------------------------------------------------------------
step "Ready to upload"
printf '  %s\n\n' "${IPA/#$ROOT\//}"
printf '  %sValidate against App Store Connect first:%s\n' "$dim" "$reset"
printf '  xcrun altool --validate-app -f "%s" -t ios \\\n' "$IPA"
printf '    --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>\n\n'
printf '  %sThen upload with Transporter, the Xcode Organizer, or altool --upload-app.%s\n' "$dim" "$reset"
if [ "$KEEP_BUILD" -eq 0 ]; then
  printf '  %sCommit the stamped build number in Deep/Config/CentralFlight.xcconfig.%s\n' "$dim" "$reset"
fi
printf '\n'
