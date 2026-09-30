#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# codesign resolves "Developer ID Application" by prefix. Use "-" for a local ad hoc build.
SIGN_IDENTITY="${TUULI_SIGN_IDENTITY:-${SIGN_IDENTITY:-Developer ID Application}}"
APP="$ROOT/build/Tuuli.app"
HELPER_LABEL="com.gabrielepartiti.tuuli.helper"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/Tuuli" "$APP/Contents/MacOS/Tuuli"
cp "$BIN_DIR/TuuliHelper" "$APP/Contents/MacOS/TuuliHelper"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/$HELPER_LABEL.plist" "$APP/Contents/Resources/$HELPER_LABEL.plist"
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
# Partiti UI's built-in strings. It looks for its bundle in Contents/Resources; the bundle
# holds no code and is sealed by the app's own signature.
ditto "$BIN_DIR/PartitiUI_PartitiUI.bundle" "$APP/Contents/Resources/PartitiUI_PartitiUI.bundle"

if [[ "$(otool -l "$APP/Contents/MacOS/Tuuli")" != *"@executable_path/../Frameworks"* ]]; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Tuuli"
fi

# Ad hoc code has no team ID, so the hardened runtime's library validation would refuse
# to load Sparkle. Ad hoc builds are for local testing only and skip it.
SIGN=(codesign --force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    SIGN+=(--options runtime --timestamp)
fi

# Inside out, without --deep: Sparkle's helpers first, in the order its docs give.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
"${SIGN[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
"${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
"${SIGN[@]}" "$SPARKLE/Versions/B/Autoupdate"
"${SIGN[@]}" "$SPARKLE/Versions/B/Updater.app"
"${SIGN[@]}" "$SPARKLE"

# The helper checks that clients carry the same team ID, so both must share the identity.
"${SIGN[@]}" --identifier "$HELPER_LABEL" "$APP/Contents/MacOS/TuuliHelper"
"${SIGN[@]}" "$APP"

codesign --verify --strict "$APP"

echo "Built $APP"
