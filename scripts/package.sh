#!/bin/zsh
# Construit MacGuardian en release et l'installe sur ce Mac.
#
# Usage :
#   scripts/package.sh                 construit, installe dans /Applications et lance l'app
#   scripts/package.sh --no-launch     installe sans lancer
#   scripts/package.sh --dest <dossier>  installe ailleurs (par défaut /Applications, sinon ~/Applications)
#   scripts/package.sh --uninstall     quitte l'app et la supprime du dossier d'installation
#
# Signature : ad hoc par défaut, suffisant pour un usage local. Si MACGUARDIAN_SIGN_IDENTITY
# contient le nom d'une identité de signature du trousseau, elle est utilisée à la place :
# macOS conserve alors les autorisations (Bluetooth, Accessibilité) d'une version à l'autre.
set -euo pipefail

cd "$(dirname "$0")/.."

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
launch=true
uninstall=false
dest=""

while (( $# > 0 )); do
    case "$1" in
        --no-launch) launch=false ;;
        --uninstall) uninstall=true ;;
        --dest) dest="${2:?--dest attend un dossier}"; shift ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Option inconnue : $1" >&2; exit 1 ;;
    esac
    shift
done

if [[ -z "$dest" ]]; then
    if [[ -w /Applications ]]; then dest="/Applications"; else dest="$HOME/Applications"; fi
fi
target="$dest/MacGuardian.app"

quit_running_app() {
    if pgrep -f "MacGuardian.app/Contents/MacOS/MacGuardian" > /dev/null; then
        echo "Arrêt de l'instance en cours…"
        osascript -e "tell application id \"$bundle_id\" to quit" > /dev/null 2>&1 || true
        for _ in {1..10}; do
            pgrep -f "MacGuardian.app/Contents/MacOS/MacGuardian" > /dev/null || return 0
            sleep 0.5
        done
        pkill -f "MacGuardian.app/Contents/MacOS/MacGuardian" || true
    fi
}

if $uninstall; then
    quit_running_app
    if [[ -d "$target" ]]; then
        rm -rf "$target"
        echo "MacGuardian supprimé de $dest."
        echo "Si le lancement automatique était activé, retirez-le dans Réglages Système › Général › Ouverture."
    else
        echo "MacGuardian n'est pas installé dans $dest."
    fi
    exit 0
fi

# Prérequis
if ! command -v swift > /dev/null; then
    echo "Swift est introuvable. Installez Xcode ou les Command Line Tools : xcode-select --install" >&2
    exit 1
fi
macos_major="$(sw_vers -productVersion | cut -d. -f1)"
if (( macos_major < 13 )); then
    echo "MacGuardian nécessite macOS 13 ou suivant (version actuelle : $(sw_vers -productVersion))." >&2
    exit 1
fi

echo "Construction de MacGuardian $version…"
# Sortie de compilation affichée uniquement en cas d'échec.
if ! build_log="$(scripts/build-app.sh release 2>&1)"; then
    echo "$build_log" >&2
    echo "Échec de la construction." >&2
    exit 1
fi
app="build/MacGuardian.app"

if [[ -n "${MACGUARDIAN_SIGN_IDENTITY:-}" ]]; then
    echo "Signature avec « $MACGUARDIAN_SIGN_IDENTITY »…"
    codesign --force --options runtime --sign "$MACGUARDIAN_SIGN_IDENTITY" "$app"
fi
codesign --verify --strict "$app"

quit_running_app
mkdir -p "$dest"
rm -rf "$target"
ditto "$app" "$target"
echo "Installé : $target"

if $launch; then
    open "$target"
    echo "MacGuardian est lancé (icône dans la barre de menus)."
fi

if [[ -z "${MACGUARDIAN_SIGN_IDENTITY:-}" ]]; then
    echo "Note : signature ad hoc, macOS peut redemander l'autorisation Bluetooth après chaque réinstallation."
fi
