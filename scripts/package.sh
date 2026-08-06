#!/usr/bin/env bash
# Assembles dist/Vaudeville.app — a drop-in-/Applications, Spotlight-launchable
# bundle around the release binary, with a generated .icns.
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=.build/release/vaudeville
APP=dist/Vaudeville.app

test -x "$BIN" || { echo "error: $BIN missing — run 'devbox run build' first" >&2; exit 1; }

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/vaudeville"

# LSUIElement keeps it out of the Dock and stops it stealing focus, so the
# frontmost window at launch is still the one the user was just looking at.
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>vaudeville</string>
	<key>CFBundleIdentifier</key><string>uk.co.mutualism.vaudeville</string>
	<key>CFBundleName</key><string>Vaudeville</string>
	<key>CFBundleDisplayName</key><string>Vaudeville</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>CFBundleIconFile</key><string>Vaudeville</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

"$BIN" --render-icon dist/icon-1024.png
ICONSET=dist/Vaudeville.iconset
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" dist/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" dist/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Vaudeville.icns"
rm -rf "$ICONSET" dist/icon-1024.png

# Ad-hoc signature keeps Gatekeeper/TCC happy and the Accessibility grant stable.
codesign --force --deep --sign - "$APP" 2>/dev/null \
  || echo "warning: ad-hoc codesign failed; the app may still run" >&2

echo "Packaged $APP"
echo "Install:  cp -R $APP /Applications/"
echo "Then: ⌘Space → \"Vaudeville\" → return. Grant Accessibility on first run."
