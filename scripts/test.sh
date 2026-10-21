#!/bin/zsh
# Lance les tests. Avec les seules Command Line Tools, le plugin de macros de Swift Testing
# n'est pas trouvé automatiquement : on indique son emplacement.
set -euo pipefail

cd "$(dirname "$0")/.."
plugins="$(dirname "$(xcrun --find swift)")/../lib/swift/host/plugins/testing"
if [[ -d "$plugins" ]]; then
    swift test -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
else
    swift test "$@"
fi
