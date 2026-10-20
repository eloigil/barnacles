#!/bin/bash
# Builds build/Barnacles.dmg: the app next to a link to /Applications, so people
# can drag it in. Runs build-app.sh first; pass VERSION=1.2 to set the version.
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/build-app.sh

DMG="build/Barnacles.dmg"
STAGE="build/dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R build/Barnacles.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Barnacles" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Built $DMG"
