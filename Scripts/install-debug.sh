#!/usr/bin/env bash
set -euo pipefail

# Builds Shuo (Debug) and copies it to /Applications/Shuo.app, replacing any
# existing copy. Use this when iterating on the implementation so the install
# path stays constant — that way macOS Privacy permissions (Microphone,
# Accessibility, Input Monitoring) survive across rebuilds.
#
# Note: ad-hoc-signed apps (CODE_SIGN_IDENTITY: "-") have TCC entries keyed
# by install path. The first install at /Applications/Shuo.app will need
# fresh permission grants; subsequent rebuilds inherit them.

cd "$(dirname "$0")/.."

xcodegen generate

xcodebuild \
  -project Shuo.xcodeproj \
  -scheme Shuo \
  -configuration Debug \
  -destination 'platform=macOS' \
  build

DERIVED=$(xcodebuild -project Shuo.xcodeproj -scheme Shuo -showBuildSettings -configuration Debug 2>/dev/null \
  | awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR /{print $2; exit}')
SRC="$DERIVED/Shuo.app"

if [[ ! -d "$SRC" ]]; then
  echo "Built bundle not found at $SRC" >&2
  exit 1
fi

# Stop any running instance before overwriting.
pkill -f "Shuo.app/Contents/MacOS/Shuo" || true
sleep 0.5

rm -rf /Applications/Shuo.app
cp -R "$SRC" /Applications/Shuo.app

echo "Installed: /Applications/Shuo.app"
echo "Launch with: open /Applications/Shuo.app"
