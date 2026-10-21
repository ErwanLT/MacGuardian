#!/bin/zsh
# Assemble build/MacGuardian.app à partir du package SwiftPM et le signe en ad hoc.
# Usage : scripts/build-app.sh [debug|release]   (release par défaut)
set -euo pipefail

cd "$(dirname "$0")/.."
configuration="${1:-release}"
app="build/MacGuardian.app"

swift build -c "$configuration" --product MacGuardian
binary="$(swift build -c "$configuration" --show-bin-path)/MacGuardian"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/MacGuardian"
cp Resources/Info.plist "$app/Contents/Info.plist"

# Signature ad hoc : suffisante en local. La distribution nécessitera Developer ID + notarisation.
codesign --force --sign - "$app"

echo "Application assemblée : $app"
echo "Lancement : open $app"
