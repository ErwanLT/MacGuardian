#!/bin/zsh
# Produit les fichiers d'une release dans dist/ : DMG, ZIP et sommes SHA-256.
# Usage : scripts/make-release.sh <version> [numéro de build]   ex. : scripts/make-release.sh 1.2.0
# Une version de pré-release (1.2.0-beta.1) est acceptée ; le bundle porte alors 1.2.0.
set -euo pipefail

cd "$(dirname "$0")/.."
version="${1:?Usage : scripts/make-release.sh <version> [numéro de build]}"
build_number="${2:-1}"

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$' ]]; then
    echo "Version invalide : $version (attendu : X.Y.Z ou X.Y.Z-suffixe)" >&2
    exit 1
fi
# CFBundleShortVersionString n'accepte que des nombres.
bundle_version="${version%%-*}"

MACGUARDIAN_UNIVERSAL=1 MACGUARDIAN_VERSION="$bundle_version" MACGUARDIAN_BUILD="$build_number" \
    scripts/build-app.sh release
app="build/MacGuardian.app"
codesign --verify --strict "$app"

rm -rf dist
mkdir -p dist
name="MacGuardian-$version"

ditto -c -k --keepParent "$app" "dist/$name.zip"

# DMG avec un raccourci vers /Applications pour l'installation par glisser-déposer.
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/MacGuardian.app"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname "MacGuardian $version" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "dist/$name.dmg"

(cd dist && shasum -a 256 "$name.dmg" "$name.zip" > SHA256SUMS.txt)
echo "Release prête dans dist/ :"
ls -lh dist
