#!/bin/bash
# release ビルドして Adderall.app を組み立てる。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Adderall.app"
BUNDLE_ID="cc.mimifuwa.adderall"

cd "$ROOT"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/Adderall"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Adderall"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Adderall</string>
    <key>CFBundleDisplayName</key><string>Adderall</string>
    <key>CFBundleExecutable</key><string>Adderall</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# ローカル実行用の ad-hoc 署名（Gatekeeper の警告を減らす）。
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "ビルド完了: $APP"
echo "起動: open \"$APP\""
echo "※ 実行ファイルを直接叩くとメニューバーに出ないことがあるため、必ず open で起動してください。"
