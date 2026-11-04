#!/bin/zsh
# Usage: ./build.sh        build, install to ~/Applications and launch
#        ./build.sh dmg    build build/SimTools-<version>.dmg for release
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.0.0"
APP="build/SimTools.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macos13" main.swift -o "build/SimTools-$arch"
done
lipo -create build/SimTools-arm64 build/SimTools-x86_64 -output "$APP/Contents/MacOS/SimTools"
cp assets/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SimTools</string>
    <key>CFBundleIdentifier</key><string>local.simtools</string>
    <key>CFBundleExecutable</key><string>SimTools</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"

if [[ "${1:-}" == "dmg" ]]; then
    DMG="build/SimTools-$VERSION.dmg"
    mkdir build/dmg
    cp -R "$APP" build/dmg/
    ln -s /Applications build/dmg/Applications
    hdiutil create -volname "SimTools" -srcfolder build/dmg -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
    echo "Created $DMG"
    exit 0
fi

mkdir -p ~/Applications
pkill -x SimTools || true
while pgrep -qx SimTools; do sleep 0.1; done
rm -rf ~/Applications/SimTools.app
cp -R "$APP" ~/Applications/
open ~/Applications/SimTools.app
echo "Installed to ~/Applications/SimTools.app"
