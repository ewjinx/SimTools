#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

APP="build/SimTools.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O main.swift -o "$APP/Contents/MacOS/SimTools"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SimTools</string>
    <key>CFBundleIdentifier</key><string>local.simtools</string>
    <key>CFBundleExecutable</key><string>SimTools</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"

mkdir -p ~/Applications
pkill -x SimTools || true
while pgrep -qx SimTools; do sleep 0.1; done
rm -rf ~/Applications/SimTools.app
cp -R "$APP" ~/Applications/
open ~/Applications/SimTools.app
echo "Installed to ~/Applications/SimTools.app"
