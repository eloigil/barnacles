#!/bin/bash
# Builds build/Barnacles.app from the Swift package.
# Needs only the Xcode Command Line Tools (no full Xcode).
set -euo pipefail

cd "$(dirname "$0")/.."
# Version: $VERSION if set (the release workflow passes the tag), else the latest
# v* tag, else 1.0.
VERSION="${VERSION:-$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-1.0}"
APP="build/Barnacles.app"
WORK="build/work"

rm -rf "$APP" "$WORK"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$WORK/AppIcon.iconset"

# Universal binary (Apple silicon + Intel). The Command Line Tools can't build
# both architectures in one go, so build each and merge them with lipo.
BINS=()
for arch in arm64 x86_64; do
  swift build -c release --triple "$arch-apple-macosx14.0"
  BINS+=("$(swift build -c release --triple "$arch-apple-macosx14.0" --show-bin-path)/Barnacles")
done
lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/Barnacles"

# App icon, from the 1024px master in Resources/
ICON="Resources/AppIcon.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON" --out "$WORK/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$ICON" --out "$WORK/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Barnacles</string>
  <key>CFBundleDisplayName</key><string>Barnacles</string>
  <key>CFBundleIdentifier</key><string>dev.barnacles.app</string>
  <key>CFBundleExecutable</key><string>Barnacles</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# Ad-hoc signature: enough to run on this Mac. Sharing it with others needs a
# Developer ID signature and notarization.
codesign --force --sign - "$APP"
rm -rf "$WORK"
echo "Built $APP ($VERSION)"
