#!/bin/zsh
# Assemble build/MacGuardian.app à partir du package SwiftPM et le signe en ad hoc.
# Usage : scripts/build-app.sh [debug|release]   (release par défaut)
# MACGUARDIAN_VERSION et MACGUARDIAN_BUILD remplacent la version et le numéro de build du bundle.
# MACGUARDIAN_UNIVERSAL=1 produit un binaire universel (Apple Silicon + Intel), utilisé pour les releases.
set -euo pipefail

cd "$(dirname "$0")/.."
configuration="${1:-release}"
app="build/MacGuardian.app"

build_args=(-c "$configuration")
if [[ "${MACGUARDIAN_UNIVERSAL:-0}" == 1 ]]; then
    build_args+=(--arch arm64 --arch x86_64)
fi

swift build "${build_args[@]}" --product MacGuardian
binary="$(swift build "${build_args[@]}" --show-bin-path)/MacGuardian"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/MacGuardian"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [[ -n "${MACGUARDIAN_VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MACGUARDIAN_VERSION" "$app/Contents/Info.plist"
fi
if [[ -n "${MACGUARDIAN_BUILD:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $MACGUARDIAN_BUILD" "$app/Contents/Info.plist"
fi
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

# Signature ad hoc : suffisante en local. La distribution nécessitera Developer ID + notarisation.
codesign --force --sign - "$app"

echo "Application assemblée : $app"
echo "Lancement : open $app"
