#!/usr/bin/env bash
# Builds the app, zips it for a GitHub Release, and writes the Homebrew cask to build/ai-usage.rb.
# Publish: create release v<VERSION> on umairnawaz333/AIUsage with build/AI-Usage.zip,
# then copy build/ai-usage.rb to Casks/ai-usage.rb in umairnawaz333/homebrew-tap.
set -euo pipefail

cd "$(dirname "$0")/.."

scripts/build-app.sh

VERSION="$(tr -d '[:space:]' < VERSION)"
ZIP="build/AI-Usage.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "build/AI Usage.app" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA/" Resources/ai-usage.rb > build/ai-usage.rb

echo "Built $ZIP (sha256 $SHA)"
echo "Cask written to build/ai-usage.rb"
