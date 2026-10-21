#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="HakuMac"
BUNDLE_ID="com.jacklee.haku.mac"
CONFIGURATION="${HAKU_BUILD_CONFIGURATION:-debug}"
APP_BUNDLE="$ROOT_DIR/dist/Haku Mac.app"
case "$MODE" in run|--verify|--debug|--logs|--telemetry|--package|--build) ;; *) echo "Usage: $0 [--verify|--debug|--logs|--telemetry|--package|--build]" >&2; exit 2;; esac
if [[ "$MODE" != "--build" && "$MODE" != "--package" ]]; then pkill -x "$APP_NAME" >/dev/null 2>&1 || true; fi
swift build -c "$CONFIGURATION"
BUILD_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
# The UI resolves the packaged resource bundle here, with a SwiftPM fallback for development.
cp -R "$BUILD_DIR/HakuMac_HakuMac.bundle" "$APP_BUNDLE/Contents/Resources/HakuMac_HakuMac.bundle"
ICONSET="$ROOT_DIR/.build/Haku.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" Sources/HakuMac/Resources/haku-chestnut.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" Sources/HakuMac/Resources/haku-chestnut.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/Haku.icns"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>HakuMac</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>Haku Mac</string>
<key>CFBundleDisplayName</key><string>Haku Mac</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>Haku</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
case "$MODE" in
  --build) echo "$APP_BUNDLE" ;;
  --package)
    cp "$BUILD_DIR/haku-mac-probe" "$ROOT_DIR/dist/haku-mac-probe"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ROOT_DIR/dist/Haku-Mac-0.1.0-$(uname -m).zip"
    shasum -a 256 "$ROOT_DIR/dist/Haku-Mac-0.1.0-$(uname -m).zip"
    ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "HakuMac"' ;;
  --telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.jacklee.haku.mac"' ;;
  --verify) open -n "$APP_BUNDLE"; sleep 2; pgrep -x "$APP_NAME" >/dev/null; echo 'Haku Mac launched.' ;;
  run) open -n "$APP_BUNDLE" ;;
esac
