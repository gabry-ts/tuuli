#!/usr/bin/env bash
# Builds, signs, notarizes and staples build/Tuuli-<version>.dmg, then writes
# build/appcast.xml for Sparkle. Used by the release workflow, and runnable locally.
#
# Needs:
#   ASC_API_KEY_PATH, ASC_API_KEY_ID, ASC_API_ISSUER_ID  App Store Connect API key for notarytool
#   SPARKLE_ED_KEY_FILE                                  Sparkle's private EdDSA key, exported to a file
#   SPARKLE_BIN (optional)                               Sparkle's bin folder with generate_appcast;
#                                                        defaults to the one SwiftPM downloaded
#   TUULI_SIGN_IDENTITY (optional)                       defaults to "Developer ID Application"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="Tuuli"
REPO="gabry-ts/tuuli"

: "${ASC_API_KEY_PATH:?set ASC_API_KEY_PATH to the .p8 file}"
: "${ASC_API_KEY_ID:?set ASC_API_KEY_ID}"
: "${ASC_API_ISSUER_ID:?set ASC_API_ISSUER_ID}"
: "${SPARKLE_ED_KEY_FILE:?set SPARKLE_ED_KEY_FILE to the private EdDSA key file}"
SPARKLE_BIN="${SPARKLE_BIN:-$ROOT/.build/artifacts/sparkle/Sparkle/bin}"

"$ROOT/scripts/make-dmg.sh" --rebuild

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Resources/Info.plist")"
DMG="$ROOT/build/$NAME-$VERSION.dmg"

xcrun notarytool submit "$DMG" \
    --key "$ASC_API_KEY_PATH" \
    --key-id "$ASC_API_KEY_ID" \
    --issuer "$ASC_API_ISSUER_ID" \
    --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

# Only this release goes into the appcast; the feed URL always points at the latest one.
ARCHIVES="$ROOT/build/appcast"
rm -rf "$ARCHIVES"
mkdir -p "$ARCHIVES"
cp "$DMG" "$ARCHIVES/"
for ext in html md; do
    NOTES="$ROOT/docs/release-notes/$VERSION.$ext"
    if [[ -f "$NOTES" ]]; then
        cp "$NOTES" "$ARCHIVES/$NAME-$VERSION.$ext"
        break
    fi
done

"$SPARKLE_BIN/generate_appcast" \
    --ed-key-file "$SPARKLE_ED_KEY_FILE" \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --embed-release-notes \
    "$ARCHIVES"
cp "$ARCHIVES/appcast.xml" "$ROOT/build/appcast.xml"

echo "Released $DMG and build/appcast.xml"
