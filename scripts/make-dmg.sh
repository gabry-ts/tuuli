#!/usr/bin/env bash
# Builds the app (if needed) and packages it as build/Tuuli-<version>.dmg, with a link to
# /Applications for drag-and-drop install. Uses only tools that ship with macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Tuuli.app"
NAME="Tuuli"

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
ln -s /Applications "$STAGING/Applications"

hdiutil create -quiet -volname "$NAME $VERSION" -srcfolder "$STAGING" \
    -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG"
rm -rf "$STAGING"

hdiutil verify -quiet "$DMG"
echo "Built $DMG ($(du -h "$DMG" | cut -f1 | xargs))"
