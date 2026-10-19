#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/toolchain.sh"
RADIO_OUTPUT_DIR="${1:-$RADIO_SOURCE_DIR/dist}"
# Keep the original executable and preference identifier for compatibility.
RADIO_APP="$RADIO_OUTPUT_DIR/Catecho.app"
mkdir -p "$RADIO_APP/Contents/MacOS" "$RADIO_APP/Contents/Resources"
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library -O -whole-module-optimization "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR"/Sources/App/*.swift -o "$RADIO_APP/Contents/MacOS/LittleRadio" -framework AppKit -framework SwiftUI -framework ServiceManagement -Xlinker -weak_framework -Xlinker Translation
cp "$RADIO_SOURCE_DIR/Resources/Catecho.icns" "$RADIO_APP/Contents/Resources/Catecho.icns"
cp "$RADIO_SOURCE_DIR/Vendor/Zstd/LICENSE" "$RADIO_APP/Contents/Resources/Zstandard-LICENSE.txt"
cat > "$RADIO_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LittleRadio</string>
<key>CFBundleIdentifier</key><string>local.littleradio.desktop</string>
<key>CFBundleName</key><string>Catecho</string>
<key>CFBundleDisplayName</key><string>Catecho</string>
<key>CFBundleIconFile</key><string>Catecho.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.6.0</string>
<key>CFBundleVersion</key><string>17</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string><string>zh-Hant</string></array>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Catecho prototype</string>
</dict></plist>
PLIST
codesign --force --sign - "$RADIO_APP"
printf 'Built %s\n' "$RADIO_APP"
