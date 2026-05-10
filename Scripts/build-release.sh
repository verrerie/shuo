#!/usr/bin/env bash
set -euo pipefail

# Regenerates the Xcode project, builds a release archive, and exports a .app
# next to the script. Override CODE_SIGN_IDENTITY to use a real Developer ID.

cd "$(dirname "$0")/.."

xcodegen generate

ARCHIVE_PATH="build/Shuo.xcarchive"
EXPORT_PATH="build/export"

xcodebuild \
  -project Shuo.xcodeproj \
  -scheme Shuo \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive

cat > build/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>mac-application</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
EOF

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath "$EXPORT_PATH"

echo "Built: $EXPORT_PATH/Shuo.app"
