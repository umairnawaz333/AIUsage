#!/usr/bin/env bash
# Builds AI Usage.app into build/.
# The app version comes only from the VERSION file; the build number is the git commit count.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/AI Usage.app"

# -j 2 keeps memory use down on a 16 GB machine.
swift build -c release -j 2

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/AIUsage" "$APP/Contents/MacOS/AIUsage"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"

echo "Built $APP (version $VERSION, build $BUILD)"
