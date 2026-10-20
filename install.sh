#!/bin/bash
# Installs the latest Barnacles.app into /Applications (or ~/Applications if
# /Applications isn't writable) and opens it.
#
#   curl -fsSL https://raw.githubusercontent.com/eloigil/barnacles/main/install.sh | bash
#
# Files downloaded with curl aren't quarantined, so macOS opens the app without
# the "unidentified developer" prompt that a browser-downloaded copy gets.
set -euo pipefail

URL="https://github.com/eloigil/barnacles/releases/latest/download/Barnacles.dmg"

[ "$(uname -s)" = "Darwin" ] || { echo "Barnacles runs on macOS only." >&2; exit 1; }

DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

TMP="$(mktemp -d)"
MOUNT="$TMP/mount"
cleanup() {
  hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading Barnacles…"
curl -fL --progress-bar "$URL" -o "$TMP/Barnacles.dmg"

mkdir -p "$MOUNT"
hdiutil attach "$TMP/Barnacles.dmg" -nobrowse -readonly -quiet -mountpoint "$MOUNT"

if pgrep -xq Barnacles; then
  echo "Quitting the running Barnacles…"
  osascript -e 'quit app "Barnacles"' || true
  sleep 1
fi

rm -rf "$DEST/Barnacles.app"
ditto "$MOUNT/Barnacles.app" "$DEST/Barnacles.app"
xattr -dr com.apple.quarantine "$DEST/Barnacles.app" 2>/dev/null || true

echo "Installed $DEST/Barnacles.app"
open "$DEST/Barnacles.app"
