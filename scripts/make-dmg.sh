#!/usr/bin/env bash
# Builds the app, then packs it into build/AI-Usage-<version>.dmg with an Applications shortcut.
set -euo pipefail

cd "$(dirname "$0")/.."

scripts/build-app.sh

VERSION="$(tr -d '[:space:]' < VERSION)"
DMG="build/AI-Usage-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "build/AI Usage.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "AI Usage" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

echo "Built $DMG"
