#!/usr/bin/env sh
# Pré-contrôle Swift sous Linux — COMPLÈTE Xcode, ne le remplace pas.
#
#   1. Shims      : modules factices (Security, UIKit, Combine, GoogleSignIn,
#                   SwiftUI), frameworks Apple absents sous Linux. Jamais
#                   livrés : ils vivent dans scripts/linux-shims/, hors de la
#                   cible Xcode.
#   2. -parse     : syntaxe de TOUS les fichiers (SwiftUI inclus : le parsing
#                   ne résout pas les imports).
#   3. -typecheck : TYPES des fichiers « portables » (n'important que
#                   Foundation / UIKit / Security / Combine / GoogleSignIn /
#                   SwiftUI). Charts, PhotosUI, PDFKit… n'existent pas sous
#                   Linux : leurs fichiers ne sont PAS vérifiés en types ici.
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

echo "1/4  Shims Linux (19 modules factices, hors cible Xcode)…"
# Ordre de dépendance : CoreGraphics/UIKit/Combine d'abord, SwiftUI ensuite
# (il les importe), UniformTypeIdentifiers avant SwiftUI (`fileImporter`).
MODS="CoreGraphics Security UIKit Combine GoogleSignIn Photos \
UniformTypeIdentifiers SwiftUI Charts PhotosUI AVFoundation LocalAuthentication \
UserNotifications MessageUI AuthenticationServices WebKit PDFKit Speech CryptoKit"
for m in $MODS; do
    files=""
    for f in "$SHIMS/$m.swift" "$SHIMS/$m"+*.swift; do
        [ -f "$f" ] && files="$files $f"
    done
    [ -z "$files" ] && continue
    # shellcheck disable=SC2086
    if ! swiftc -emit-module -module-name "$m" $files -I "$WORK" \
            -emit-module-path "$WORK/$m.swiftmodule" 2>"$WORK/shim-$m.txt"; then
        echo "erreur : le shim $m ne compile pas" >&2
        head -20 "$WORK/shim-$m.txt" >&2
        exit 1
    fi
done

echo "2/4  Syntaxe — tous les fichiers .swift…"
swiftc -parse "$DUELO"/*.swift

echo "3/4  Types — lot portable (Foundation/UIKit/Security/Combine/GoogleSignIn/SwiftUI)…"
mkdir -p "$WORK/src"
python3 "$SCOPE" list > "$WORK/portable.txt"
while IFS= read -r f; do
    sed 's/^import Foundation$/import Foundation\nimport FoundationNetworking/' \
        "$DUELO/$f" > "$WORK/src/$f"
done < "$WORK/portable.txt"

echo "4/4  Tri des échecs…"
# `-enable-batch-mode` : sans lui, `swiftc` s'arrête au PREMIER fichier en
# erreur et masque toutes les suivantes. Avec, chaque fichier du lot est
# contrôlé et l'ensemble des diagnostics remonte.
# `swiftc` échoue sur les faux positifs du lot : seul le tri fait foi.
if ! swiftc -typecheck -enable-batch-mode -I "$WORK" "$WORK"/src/*.swift 2>&1 | python3 "$SCOPE" triage; then
    exit 1
fi

echo "OK — syntaxe : tous les fichiers ; types : $(wc -l < "$WORK/portable.txt" | tr -d ' ') fichiers portables."
