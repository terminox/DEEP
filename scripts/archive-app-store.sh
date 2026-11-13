#!/usr/bin/env bash
#
# Builds a signed .ipa of DEEP for the App Store, and optionally uploads it.
#
# The AppStore configuration is Prod — same bundle id, same production API — signed for
# distribution on the client's team. See Deep/Config/AppStore.xcconfig.
#
# The build number is Unix epoch seconds, stamped into that xcconfig so the tree records
# what shipped. Commit the stamp alongside whatever you uploaded.
#
#   ./scripts/archive-app-store.sh                # stamp, archive, export, verify
#   ./scripts/archive-app-store.sh --keep-build   # reuse the committed build number
#   ./scripts/archive-app-store.sh --upload       # …then validate and upload
#
# --upload reads an App Store Connect API key (Admin or App Manager) from the environment:
#   DEEP_ASC_KEY_ID, DEEP_ASC_ISSUER_ID, and the key file at
#   ~/.appstoreconnect/private_keys/AuthKey_<DEEP_ASC_KEY_ID>.p8, where altool looks for it.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$ROOT/Deep/Config"
XCCONFIG="$CONFIG_DIR/AppStore.xcconfig"
PROJECT="$ROOT/Deep/Deep.xcodeproj"
BUILD_DIR="$ROOT/Deep/build"
ARCHIVE="$BUILD_DIR/AppStore.xcarchive"
IPA_DIR="$BUILD_DIR/ipa"
LOG_DIR="$BUILD_DIR/logs"
EXPORT_OPTIONS="$BUILD_DIR/app-store-export-options.plist"

if [ -t 1 ]; then
  bold=$'\033[1m'; dim=$'\033[2m'; green=$'\033[32m'; red=$'\033[31m'; reset=$'\033[0m'
else
  bold=""; dim=""; green=""; red=""; reset=""
fi
step() { printf '\n%s==>%s %s\n' "$bold" "$reset" "$1"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$1"; }
die()  { printf '  %s✗%s %s\n' "$red" "$reset" "$1" >&2; exit 1; }

KEEP_BUILD=0
UPLOAD=0
for arg in "$@"; do
  case "$arg" in
    --keep-build) KEEP_BUILD=1 ;;
    --upload) UPLOAD=1 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

if [ "$UPLOAD" -eq 1 ]; then
  [ -n "${DEEP_ASC_KEY_ID:-}" ] && [ -n "${DEEP_ASC_ISSUER_ID:-}" ] \
    || die "--upload needs DEEP_ASC_KEY_ID and DEEP_ASC_ISSUER_ID"
  [ -f "$HOME/.appstoreconnect/private_keys/AuthKey_$DEEP_ASC_KEY_ID.p8" ] \
    || die "no ~/.appstoreconnect/private_keys/AuthKey_$DEEP_ASC_KEY_ID.p8"
fi

# The identity the archive must carry, read from the build settings rather than restated:
# a value written twice is a value that drifts.
setting() { # name — the AppStore configuration's resolved value
  xcodebuild -project "$PROJECT" -scheme "Deep AppStore" -configuration AppStore \
    -showBuildSettings 2>/dev/null | sed -n "s/^ *$1 = //p" | head -1
}
TEAM_ID="$(setting DEVELOPMENT_TEAM)"
BUNDLE_ID="$(setting PRODUCT_BUNDLE_IDENTIFIER)"
PROFILE="$(setting PROVISIONING_PROFILE_SPECIFIER)"
VERSION="$(setting MARKETING_VERSION)"
[ -n "$TEAM_ID" ] && [ -n "$BUNDLE_ID" ] && [ -n "$PROFILE" ] && [ -n "$VERSION" ] \
  || die "couldn't read the AppStore build settings"

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
ok "$BUNDLE_ID $VERSION ($BUILD_NUMBER), team $TEAM_ID, profile \"$PROFILE\""

# ---- 2. archive ---------------------------------------------------------------
step "Archiving"
rm -rf "$ARCHIVE" "$IPA_DIR"
run_xcodebuild "$LOG_DIR/archive.log" archive \
  -project "$PROJECT" \
  -scheme "Deep AppStore" \
  -configuration AppStore \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE"
grep -q '\*\* ARCHIVE SUCCEEDED \*\*' "$LOG_DIR/archive.log" \
  || die "no ARCHIVE SUCCEEDED in the log"
ok "${ARCHIVE/#$ROOT\//}"

# ---- 3. export ----------------------------------------------------------------
step "Exporting"
cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict><key>$BUNDLE_ID</key><string>$PROFILE</string></dict>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>stripSwiftSymbols</key><true/>
</dict>
</plist>
PLIST
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

value() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null || true; }
expect() { # key expected-value
  local got; got="$(value "$1")"
  [ "$got" = "$2" ] || die "$1 is '${got:-<missing>}', expected '$2'"
  ok "$1 = $got"
}
expect CFBundleIdentifier "$BUNDLE_ID"
expect CFBundleShortVersionString "$VERSION"
expect CFBundleVersion "$BUILD_NUMBER"
expect AppEnvironment "prod"
# Missing at the top level is ITMS-90713 — actool writes it only nested under CFBundleIcons.
expect CFBundleIconName "AppIcon"

# RevenueCat crashes a release build that carries a Test Store key, and an empty key sells
# nothing — only the App Store app's public key belongs here.
RC_KEY="$(value RevenueCatAPIKey)"
[[ "$RC_KEY" == appl_* ]] || die "RevenueCatAPIKey is '${RC_KEY:-<missing>}', expected an appl_ key"
! grep -qaE 'test_[A-Za-z0-9]{20,}' "$PLIST" "$APP/$(value CFBundleExecutable)" \
  || die "a RevenueCat Test Store key is in the build"
ok "RevenueCat App Store key, no Test Store key"

# The local-network permission belongs to Dev's server on a Mac, never to a shipped app.
[ -z "$(value NSLocalNetworkUsageDescription)" ] && [ -z "$(value NSAppTransportSecurity)" ] \
  || die "the Dev-only local-network keys reached the shipping Info.plist"
ok "no local-network permission"

API_URL="$(value APIBaseURL)"
[[ "$API_URL" == https://* ]] || die "APIBaseURL is '$API_URL', expected https"
ok "APIBaseURL = $API_URL"

[ -f "$APP/PrivacyInfo.xcprivacy" ] || die "PrivacyInfo.xcprivacy missing from the bundle"
ok "PrivacyInfo.xcprivacy bundled"
[ ! -e "$APP/Deep.storekit" ] || die "Deep.storekit was bundled into a shipping build"
ok "Deep.storekit not bundled"

EXECUTABLE="$(value CFBundleExecutable)"
ARCHS="$(lipo -archs "$APP/$EXECUTABLE")"
[ "$ARCHS" = "arm64" ] || die "architectures are '$ARCHS', expected arm64"
ok "arm64"

ENTS="$(codesign -d --entitlements :- "$APP" 2>/dev/null)"
grep -q 'beta-reports-active' <<<"$ENTS" || die "not a TestFlight-capable signature"
grep -A1 'get-task-allow' <<<"$ENTS" | grep -q '<false/>' \
  || die "get-task-allow is true — a development signature, not a distribution one"
grep -q "$TEAM_ID" <<<"$ENTS" || die "the signature isn't from team $TEAM_ID"
ok "distribution signature for team $TEAM_ID, TestFlight enabled"
codesign -dvvv "$APP" 2>&1 | sed -n 's/^Authority=/  · /p' | head -1

# ---- 5. upload ----------------------------------------------------------------
if [ "$UPLOAD" -eq 1 ]; then
  step "Validating with App Store Connect"
  xcrun altool --validate-app -f "$IPA" -t ios \
    --apiKey "$DEEP_ASC_KEY_ID" --apiIssuer "$DEEP_ASC_ISSUER_ID" >"$LOG_DIR/validate.log" 2>&1 \
    || { tail -20 "$LOG_DIR/validate.log" >&2; die "validation failed"; }
  ok "validated"

  step "Uploading"
  xcrun altool --upload-app -f "$IPA" -t ios \
    --apiKey "$DEEP_ASC_KEY_ID" --apiIssuer "$DEEP_ASC_ISSUER_ID" >"$LOG_DIR/upload.log" 2>&1 \
    || { tail -20 "$LOG_DIR/upload.log" >&2; die "upload failed"; }
  ok "uploaded $VERSION ($BUILD_NUMBER) — App Store Connect processes it before TestFlight shows it"
else
  step "Ready to upload"
  printf '  %s\n\n' "${IPA/#$ROOT\//}"
  printf '  %sRe-run with --upload (and DEEP_ASC_KEY_ID / DEEP_ASC_ISSUER_ID set) to validate and upload.%s\n' "$dim" "$reset"
fi
if [ "$KEEP_BUILD" -eq 0 ]; then
  printf '  %sCommit the stamped build number in Deep/Config/AppStore.xcconfig.%s\n' "$dim" "$reset"
fi
printf '\n'
