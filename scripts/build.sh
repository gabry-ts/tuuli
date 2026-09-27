#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIGN_IDENTITY="${TUULI_SIGN_IDENTITY:-Apple Development: gabrielepartiti@outlook.com (CD2U989KNR)}"
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

if [[ "$(otool -l "$APP/Contents/MacOS/Tuuli")" != *"@executable_path/../Frameworks"* ]]; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Tuuli"
fi

# The helper checks that clients carry the same team ID, so both must share the identity.
codesign --force --options runtime --identifier "$HELPER_LABEL" --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/TuuliHelper"
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
