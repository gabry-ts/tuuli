#!/usr/bin/env bash
# Builds the app (if needed) and packages it as build/Tuuli-<version>.dmg, with a link to
# /Applications for drag-and-drop install. Uses create-dmg (brew install create-dmg) for the
# background and icon layout, or falls back to a plain hdiutil image without it. The DMG
# is signed with the same identity as the app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Tuuli.app"
NAME="Tuuli"
SIGN_IDENTITY="${TUULI_SIGN_IDENTITY:-${SIGN_IDENTITY:-Developer ID Application}}"

REBUILD=0
for arg in "$@"; do
    case "$arg" in
        --rebuild) REBUILD=1 ;;
    esac
done

if [[ ! -d "$APP" || "$REBUILD" -eq 1 ]]; then
    "$ROOT/scripts/build.sh"
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
DMG="$ROOT/build/$NAME-$VERSION.dmg"
STAGING="$ROOT/build/dmg-staging"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/$NAME.app"

if command -v create-dmg >/dev/null; then
    # One TIFF with both resolutions, so the background stays sharp on Retina displays.
    BACKGROUND="$ROOT/build/dmg-background.tiff"
    tiffutil -cathidpicheck "$ROOT/Resources/dmg/background.png" "$ROOT/Resources/dmg/background@2x.png" \
        -out "$BACKGROUND" >/dev/null
    create-dmg \
        --volname "$NAME $VERSION" \
        --background "$BACKGROUND" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 128 \
        --icon "$NAME.app" 150 190 \
        --hide-extension "$NAME.app" \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "$DMG" "$STAGING"
    rm -f "$BACKGROUND"
else
    echo "create-dmg not found, building a plain DMG" >&2
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -quiet -volname "$NAME $VERSION" -srcfolder "$STAGING" \
        -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG"
fi
rm -rf "$STAGING"

SIGN=(codesign --force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    SIGN+=(--timestamp)
fi
"${SIGN[@]}" "$DMG"

hdiutil verify -quiet "$DMG"
echo "Built $DMG ($(du -h "$DMG" | cut -f1 | xargs))"
