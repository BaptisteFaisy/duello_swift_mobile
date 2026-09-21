#!/usr/bin/env sh
# Pré-contrôle Swift sous Linux — COMPLÈTE Xcode, ne le remplace pas.
#
#   1. Shims      : modules factices (Security, UIKit, Combine, GoogleSignIn),
#                   frameworks Apple absents sous Linux. Jamais livrés : ils
#                   vivent dans scripts/linux-shims/, hors de la cible Xcode.
#   2. -parse     : syntaxe de TOUS les fichiers (SwiftUI inclus : le parsing
#                   ne résout pas les imports).
#   3. -typecheck : TYPES des fichiers « portables » (n'important que
#                   Foundation / UIKit / Security / Combine / GoogleSignIn).
#                   SwiftUI, Charts, PhotosUI, PDFKit… n'existent pas sous
#                   Linux : les vues ne sont donc PAS vérifiées ici.
#
# Les échecs du lot portable sont triés par scripts/swift_linux_scope.py : ceux
# qui viennent d'un type déclaré dans un fichier non portable (le lot ne peut
# pas le voir) sont rapportés « hors couverture » et n'échouent pas ; tout le
# reste est un vrai défaut — symbole inexistant, import manquant, erreur de
# type. C'est ce tri qui a attrapé `NSUserCancelledErrorCode` (symbole inventé,
# absent du SDK) et six `@Published` sans `import Combine`.
#
# Les fichiers portables sont copiés dans un dossier temporaire, où l'on ajoute
# `import FoundationNetworking` (URLSession/URLRequest y vivent sous Linux).
# L'app reste ainsi Apple-pure : aucun fichier de Duello/ n'est modifié.
#
# Usage : scripts/verify-swift-linux.sh
# Requiert : swiftc (toolchain Swift pour Linux, https://swift.org).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUELO="$ROOT/Duello"
SHIMS="$ROOT/scripts/linux-shims"
SCOPE="$ROOT/scripts/swift_linux_scope.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if ! command -v swiftc >/dev/null 2>&1; then
    echo "erreur : swiftc introuvable. Installez la toolchain Swift pour Linux." >&2
    exit 2
fi

echo "1/4  Shims Linux (Security, UIKit, Combine, GoogleSignIn)…"
swiftc -emit-module -module-name Security "$SHIMS/Security.swift" \
    -emit-module-path "$WORK/Security.swiftmodule"
swiftc -emit-module -module-name UIKit "$SHIMS/UIKit.swift" \
    -emit-module-path "$WORK/UIKit.swiftmodule"
swiftc -emit-module -module-name Combine "$SHIMS/Combine.swift" \
    -emit-module-path "$WORK/Combine.swiftmodule"
swiftc -emit-module -module-name GoogleSignIn "$SHIMS/GoogleSignIn.swift" \
    -I "$WORK" -emit-module-path "$WORK/GoogleSignIn.swiftmodule"

echo "2/4  Syntaxe — tous les fichiers .swift…"
swiftc -parse "$DUELO"/*.swift

echo "3/4  Types — lot portable (Foundation/UIKit/Security/Combine/GoogleSignIn)…"
mkdir -p "$WORK/src"
python3 "$SCOPE" list > "$WORK/portable.txt"
while IFS= read -r f; do
    sed 's/^import Foundation$/import Foundation\nimport FoundationNetworking/' \
        "$DUELO/$f" > "$WORK/src/$f"
done < "$WORK/portable.txt"

echo "4/4  Tri des échecs…"
# `swiftc` échoue sur les faux positifs du lot : seul le tri fait foi.
if ! swiftc -typecheck -I "$WORK" "$WORK"/src/*.swift 2>&1 | python3 "$SCOPE" triage; then
    exit 1
fi

echo "OK — syntaxe : tous les fichiers ; types : $(wc -l < "$WORK/portable.txt" | tr -d ' ') fichiers portables."
