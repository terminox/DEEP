#!/usr/bin/env bash
#
# Builds the release-signed DEEP Android APK, and the App Bundle Play will want,
# then checks both against what a store would reject after upload. The Android
# twin of archive-central-flight.sh.
#
# The APK is what the client installs directly while there is no Play listing.
# The .aab is kept beside it for the day there is one.
#
# Signing needs two things this repository never holds (it is public):
#   android/keystore.properties   storeFile=<path to the .jks>, keyAlias=deep
#   a Keychain item               service deep-android-release, account deep,
#                                 holding the keystore's password
# Without them Gradle would quietly sign with the debug key. This script
# refuses, because a debug-signed build can't be updated by a store build.
#
# The version is android/app/build.gradle.kts's `deepVersion`, and the
# versionCode is derived from it there. Nothing is stamped, so a rebuild of the
# same commit produces the same version.
#
#   ./scripts/build-android-release.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID="$ROOT/android"
GRADLE_FILE="$ANDROID/app/build.gradle.kts"
KEYSTORE_PROPS="$ANDROID/keystore.properties"
LOG_DIR="$ANDROID/build/release-logs"
DIST="$ANDROID/dist"
PACKAGE="io.appbeyond.freelance.deep"
API_HOST="deep-api-696592457470.asia-southeast1.run.app"
MIN_SDK=26
# Play's floor for new apps and updates.
MIN_TARGET_SDK=35
KEYCHAIN_SERVICE="deep-android-release"
KEYCHAIN_ACCOUNT="deep"

if [ -t 1 ]; then
  bold=$'\033[1m'; dim=$'\033[2m'; green=$'\033[32m'; red=$'\033[31m'; reset=$'\033[0m'
else
  bold=""; dim=""; green=""; red=""; reset=""
fi
step() { printf '\n%s==>%s %s\n' "$bold" "$reset" "$1"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$1"; }
die()  { printf '  %s✗%s %s\n' "$red" "$reset" "$1" >&2; exit 1; }
# Any other command that fails under `set -e` says where, rather than ending
# the script in silence.
trap 'printf "  %s✗%s stopped at line %s\n" "$red" "$reset" "$LINENO" >&2' ERR

[ "$#" -eq 0 ] || die "this script takes no arguments"

# ---- 1. preflight -------------------------------------------------------------
step "Preflight"

# The SDK, from the same local.properties Gradle reads, else the environment.
SDK="$(sed -n 's/^sdk\.dir=//p' "$ANDROID/local.properties" 2>/dev/null | tail -1 || true)"
SDK="${SDK:-${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}}"
[ -n "$SDK" ] && [ -d "$SDK" ] || die "no Android SDK: set sdk.dir in android/local.properties or ANDROID_HOME"
BUILD_TOOLS="$(find "$SDK/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
[ -n "$BUILD_TOOLS" ] || die "no build-tools under $SDK"
AAPT2="$BUILD_TOOLS/aapt2"; APKSIGNER="$BUILD_TOOLS/apksigner"; ZIPALIGN="$BUILD_TOOLS/zipalign"
for tool in "$AAPT2" "$APKSIGNER" "$ZIPALIGN"; do
  [ -x "$tool" ] || die "missing $tool"
done
ok "build-tools $(basename "$BUILD_TOOLS")"

command -v bundletool >/dev/null || die "bundletool not found (brew install bundletool)"

# JDK 21.0.2's C2 compiler crashes the Gradle daemon on this build ("Field too
# big for insn"), so pin the newest installed 21 rather than whatever is first
# on the PATH.
JAVA_HOME="$(/usr/libexec/java_home -v 21)"
export JAVA_HOME
KEYTOOL="$JAVA_HOME/bin/keytool"
ok "JDK $("$JAVA_HOME/bin/java" -version 2>&1 | head -1 | sed 's/.*"\(.*\)".*/\1/')"

[ -f "$KEYSTORE_PROPS" ] || die "no android/keystore.properties — see the header of this script"
STORE_FILE="$(sed -n 's/^storeFile=//p' "$KEYSTORE_PROPS" | tail -1)"
KEY_ALIAS="$(sed -n 's/^keyAlias=//p' "$KEYSTORE_PROPS" | tail -1)"
[ -n "$STORE_FILE" ] && [ -n "$KEY_ALIAS" ] || die "keystore.properties needs storeFile and keyAlias"
case "$STORE_FILE" in /*) ;; *) STORE_FILE="$ANDROID/$STORE_FILE" ;; esac
[ -f "$STORE_FILE" ] || die "keystore not found at $STORE_FILE"

DEEP_ANDROID_KEYSTORE_PASSWORD="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null)" \
  || die "no Keychain item $KEYCHAIN_SERVICE/$KEYCHAIN_ACCOUNT holding the keystore password"
export DEEP_ANDROID_KEYSTORE_PASSWORD

# The release certificate's SHA-256, the one every artifact must carry.
cert_sha256() { # keytool args...
  "$KEYTOOL" "$@" 2>/dev/null | sed -n 's/^.*SHA256: //p' | head -1 | tr -d ':' | tr 'A-F' 'a-f'
}
RELEASE_SHA="$(cert_sha256 -list -v -keystore "$STORE_FILE" -alias "$KEY_ALIAS" -storepass:env DEEP_ANDROID_KEYSTORE_PASSWORD)"
[ -n "$RELEASE_SHA" ] || die "could not open the keystore with the Keychain password"
DEBUG_SHA=""
if [ -f "$HOME/.android/debug.keystore" ]; then
  DEBUG_SHA="$(cert_sha256 -list -v -keystore "$HOME/.android/debug.keystore" -alias androiddebugkey -storepass android)"
fi
[ "$RELEASE_SHA" != "$DEBUG_SHA" ] || die "keystore.properties points at the debug key"
ok "release key ${RELEASE_SHA:0:16}…"

VERSION_NAME="$(sed -n 's/^val deepVersion = "\(.*\)"$/\1/p' "$GRADLE_FILE")"
[[ "$VERSION_NAME" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "no deepVersion in ${GRADLE_FILE/#$ROOT\//}"
VERSION_CODE=$(( BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3] ))
ok "version $VERSION_NAME ($VERSION_CODE)"

# ---- 2. build -----------------------------------------------------------------
# Never pipe Gradle: the pipe would report its last command's status, not
# Gradle's. Log to a file, check the real exit code, then insist on the line.
# No configuration cache, so the keystore password is never written into it.
step "Testing, linting and building"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/gradle.log"
status=0
(cd "$ANDROID" && ./gradlew --console=plain --no-configuration-cache \
  :core:model:test :app:lintVitalProdRelease :app:assembleProdRelease :app:bundleProdRelease) \
  >"$LOG" 2>&1 || status=$?
if [ "$status" -ne 0 ]; then
  grep -E '^(e: |FAILURE|\* What went wrong)' -A3 "$LOG" | head -30 >&2 || true
  die "gradle exited $status — full log: ${LOG/#$ROOT\//}"
fi
grep -q '^BUILD SUCCESSFUL' "$LOG" || die "no BUILD SUCCESSFUL in the log"
ok "tests, lintVital, assemble and bundle"

APK="$ANDROID/app/build/outputs/apk/prod/release/app-prod-release.apk"
AAB="$ANDROID/app/build/outputs/bundle/prodRelease/app-prod-release.aab"
MAPPING="$ANDROID/app/build/outputs/mapping/prodRelease/mapping.txt"
[ -f "$APK" ] || die "no APK at ${APK/#$ROOT\//}"
[ -f "$AAB" ] || die "no AAB at ${AAB/#$ROOT\//}"

# ---- 3. verify the APK ---------------------------------------------------------
# Every check stands in for something a store, or the install itself, would
# reject.
step "Verifying the APK"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BADGING="$("$AAPT2" dump badging "$APK")"
badge() { # regex — prints the first capture
  sed -n "$1" <<<"$BADGING" | head -1
}
expect() { # label got want
  [ "$2" = "$3" ] || die "$1 is '${2:-<missing>}', expected '$3'"
  ok "$1 = $2"
}
expect "package"     "$(badge "s/^package: name='\([^']*\)'.*/\1/p")" "$PACKAGE"
expect "versionCode" "$(badge "s/^package: .*versionCode='\([^']*\)'.*/\1/p")" "$VERSION_CODE"
expect "versionName" "$(badge "s/^package: .*versionName='\([^']*\)'.*/\1/p")" "$VERSION_NAME"
expect "minSdk"      "$(badge "s/^minSdkVersion:'\([^']*\)'.*/\1/p")" "$MIN_SDK"
expect "label"       "$(badge "s/^application-label:'\([^']*\)'.*/\1/p")" "DEEP"
TARGET_SDK="$(badge "s/^targetSdkVersion:'\([^']*\)'.*/\1/p")"
[ "${TARGET_SDK:-0}" -ge "$MIN_TARGET_SDK" ] || die "targetSdk $TARGET_SDK is below Play's $MIN_TARGET_SDK"
ok "targetSdk = $TARGET_SDK"
! grep -q "^application-debuggable" <<<"$BADGING" || die "the APK is debuggable"
ok "not debuggable"

SIGNERS="$("$APKSIGNER" verify --verbose --print-certs "$APK" 2>&1)" || die "apksigner rejected the APK"
grep -q 'Verified using v2 scheme (APK Signature Scheme v2): true' <<<"$SIGNERS" \
  || die "no v2 signature (Android 11+ refuses v1-only installs of targetSdk 30+ apps)"
APK_SHA="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$SIGNERS" | head -1)"
[ "$APK_SHA" = "$RELEASE_SHA" ] || die "signed with ${APK_SHA:-<unknown>}, not the release key"
ok "signed with the release key (v2)"

"$ZIPALIGN" -c -P 16 4 "$APK" >/dev/null || die "zip entries are not 16 KB page-aligned"
ok "zip aligned for 16 KB pages"

# Only what the checks read. R8 shortens resource names until two differ only
# by case (res/bB.xml, res/bb.xml), which a whole-APK unzip can't write side by
# side on macOS's case-insensitive disk. Exit 11 means a pattern matched
# nothing, as for an APK with no native code.
unzip -qo "$APK" 'lib/*' 'assets/*' 'classes*.dex' -d "$WORK/apk" || [ "$?" -eq 11 ] \
  || die "could not unpack the APK"
# Play requires 64-bit native code to load on 16 KB-page devices: every LOAD
# segment of an arm64-v8a or x86_64 library aligned to at least 16 KB.
python3 -I - "$WORK/apk/lib" <<'PY' || die "a 64-bit native library is not 16 KB aligned"
import os, struct, sys
root, bad, seen = sys.argv[1], [], 0
for abi in ("arm64-v8a", "x86_64"):
    d = os.path.join(root, abi)
    if not os.path.isdir(d):
        continue
    for name in sorted(os.listdir(d)):
        if not name.endswith(".so"):
            continue
        seen += 1
        data = open(os.path.join(d, name), "rb").read()
        if data[:4] != b"\x7fELF" or data[4] != 2:
            bad.append(f"{abi}/{name}: not a 64-bit ELF"); continue
        phoff, = struct.unpack_from("<Q", data, 0x20)
        phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
        for i in range(phnum):
            off = phoff + i * phentsize
            p_type, = struct.unpack_from("<I", data, off)
            p_align, = struct.unpack_from("<Q", data, off + 0x30)
            if p_type == 1 and p_align < 16384:
                bad.append(f"{abi}/{name}: LOAD align {p_align}")
for b in bad:
    print("    " + b, file=sys.stderr)
print(f"  checked {seen} libraries")
sys.exit(1 if bad else 0)
PY
ok "64-bit native libraries aligned for 16 KB pages"

MANIFEST="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK")"
! grep -q 'networkSecurityConfig' <<<"$MANIFEST" || die "a shipping build carries a networkSecurityConfig"
! grep -q 'usesCleartextTraffic.*=true' <<<"$MANIFEST" || die "cleartext traffic is allowed"
ok "no cleartext, no network security override"
grep -q 'dataExtractionRules' <<<"$MANIFEST" || die "no dataExtractionRules (Android 12+ device transfer)"
ok "data extraction rules present"
# targetSdk 31+ refuses to install a component with an intent filter and no
# explicit android:exported.
printf '%s\n' "$MANIFEST" >"$WORK/manifest.txt"
python3 -I - "$WORK/manifest.txt" <<'PY' || die "a component with an intent filter has no android:exported"
import re, sys
text, missing = open(sys.argv[1]).read(), []
blocks = re.split(r"\n(?=\s+E: (?:activity|activity-alias|service|receiver|provider) )", text)
for b in blocks[1:]:
    head = b.split("\n", 1)[0].strip()
    name = re.search(r'android:name\(0x[0-9a-f]+\)="([^"]+)"', b)
    if "intent-filter" in b and "android:exported" not in b.split("E: intent-filter")[0]:
        missing.append(name.group(1) if name else head)
for m in missing:
    print("    " + m, file=sys.stderr)
sys.exit(1 if missing else 0)
PY
ok "every exported component is explicit"
if grep -q 'foregroundServiceType' <<<"$MANIFEST"; then
  grep -q 'FOREGROUND_SERVICE_MEDIA_PLAYBACK' <<<"$MANIFEST" \
    || die "a mediaPlayback foreground service without FOREGROUND_SERVICE_MEDIA_PLAYBACK"
  ok "foreground service types have their permissions"
fi

cat "$WORK"/apk/classes*.dex >"$WORK/dex"
grep -qa "https://$API_HOST" "$WORK/dex" || die "the production API host is not in the code"
# The Dev flavor's host, as build.gradle.kts resolves it, must not have leaked
# into the production flavor.
DEV_HOST="$(sed -n 's/^deep\.devApiHost=//p' "$ANDROID/local.properties" 2>/dev/null | tail -1 || true)"
for host in "${DEV_HOST:-}" "10.0.2.2:8080"; do
  [ -z "$host" ] || ! grep -qaF "http://$host" "$WORK/dex" || die "the dev API host $host is in the code"
done
ok "talks to https://$API_HOST"

for asset in earth_surface.frag earth_fullscreen.vert earth_bloom_threshold.frag earth_bloom_blur.frag \
  earth_composite.frag earth_tonemap.glsl earth_tuning.glsl earth_specular_2048.jpg; do
  [ -s "$WORK/apk/assets/earth/$asset" ] || die "assets/earth/$asset missing — the globe would fall back to 2D"
done
ok "globe shaders and texture bundled"

[ -s "$MAPPING" ] || die "no R8 mapping.txt — crashes from this build could never be read"
ok "R8 mapping present"

# ---- 4. verify the bundle -------------------------------------------------------
step "Verifying the App Bundle"
bundletool validate --bundle="$AAB" >"$WORK/validate.log" 2>&1 || { cat "$WORK/validate.log" >&2; die "bundletool rejected the .aab"; }
ok "bundletool validate"
AAB_SHA="$("$KEYTOOL" -printcert -jarfile "$AAB" 2>/dev/null | sed -n 's/^.*SHA256: //p' | head -1 | tr -d ':' | tr 'A-F' 'a-f')"
[ "$AAB_SHA" = "$RELEASE_SHA" ] || die "the .aab is signed with ${AAB_SHA:-<nothing>}, not the release key"
ok "signed with the release key"

# ---- 5. hand off -----------------------------------------------------------------
step "Collecting"
mkdir -p "$DIST"
NAME="deep-android-v$VERSION_NAME"
cp "$APK" "$DIST/$NAME.apk"
cp "$AAB" "$DIST/$NAME.aab"
cp "$MAPPING" "$DIST/$NAME-mapping.txt"
(cd "$DIST" && shasum -a 256 "$NAME.apk" "$NAME.aab" >"$NAME.sha256")
ok "${DIST/#$ROOT\//}/$NAME.apk ($(du -h "$DIST/$NAME.apk" | cut -f1 | tr -d ' '))"
ok "${DIST/#$ROOT\//}/$NAME.aab"
ok "${DIST/#$ROOT\//}/$NAME-mapping.txt — keep it; it is the only way to read this build's crashes"

printf '\n  %sInstall on a connected phone:%s\n' "$dim" "$reset"
printf '  adb install -r "%s"\n\n' "$DIST/$NAME.apk"
