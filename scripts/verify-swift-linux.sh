#!/usr/bin/env sh
# Contrôle Swift sous Linux — COMPLÈTE Xcode, ne le remplace pas.
#
#   1. Shims      : 19 modules factices (SwiftUI, Charts, PhotosUI, …) qui
#                   reproduisent la surface Apple utilisée par Duello. Ils
#                   vivent dans scripts/linux-shims/, hors de la cible Xcode,
#                   et ne sont JAMAIS livrés.
#   2. -parse     : syntaxe de TOUS les fichiers.
#   3. -typecheck : TYPES de TOUS les fichiers (649), en mode « batch ».
#
# Historique : ce script ne contrôlait les types que d'un « lot portable » de
# 303 fichiers — ceux qui n'importaient que Foundation/UIKit/Security/Combine.
# Les 344 autres, dont les 326 qui importent SwiftUI, n'étaient vus qu'en
# syntaxe : le cœur de l'app n'avait jamais passé un contrôle de types. Depuis
# que SwiftUI et les autres frameworks sont shimés, le lot entier est typé.
#
# ⚠️ `-enable-batch-mode` est INDISPENSABLE : sans lui, `swiftc` s'arrête au
# premier fichier fautif et masque toutes les erreurs suivantes. La différence
# est spectaculaire — 2 erreurs visibles au lieu de 82.
#
# `import FoundationNetworking` est ajouté aux fichiers qui importent
# Foundation : sous Linux, `URLSession` y vit, alors qu'il est dans Foundation
# sur Apple. L'app reste Apple-pure : aucun fichier de Duello/ n'est modifié.
#
# Usage : scripts/verify-swift-linux.sh
# Requiert : swiftc (toolchain Swift pour Linux, https://swift.org).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUELO="$ROOT/Duello"
SHIMS="$ROOT/scripts/linux-shims"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if ! command -v swiftc >/dev/null 2>&1; then
    echo "erreur : swiftc introuvable. Installez la toolchain Swift pour Linux." >&2
    exit 2
fi

echo "1/3  Shims Linux — 19 modules factices (hors cible Xcode)…"
# Ordre de dépendance : CoreGraphics/UIKit/Combine d'abord, puis les modules
# feuilles, puis SwiftUI (qui importe Photos, PhotosUI, UIKit, Combine,
# UniformTypeIdentifiers), puis Charts (qui importe SwiftUI).
MODS="CoreGraphics Security UIKit Combine GoogleSignIn Photos PhotosUI \
UniformTypeIdentifiers SwiftUI Charts AVFoundation LocalAuthentication \
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
        grep "error:" "$WORK/shim-$m.txt" | head -20 >&2
        exit 1
    fi
done

echo "2/3  Syntaxe — tous les fichiers .swift…"
swiftc -parse "$DUELO"/*.swift

echo "3/3  Types — les 649 fichiers, en lot…"
mkdir -p "$WORK/src"
for f in "$DUELO"/*.swift; do
    sed 's/^import Foundation$/import Foundation\nimport FoundationNetworking/' \
        "$f" > "$WORK/src/$(basename "$f")"
done

DIAG="$WORK/diag.txt"
if ! swiftc -typecheck -enable-batch-mode -I "$WORK" "$WORK"/src/*.swift > "$DIAG" 2>&1; then
    echo "erreurs de type :" >&2
    grep "error:" "$DIAG" | sed "s|$WORK/src/||" >&2
    echo "--- $(grep -c 'error:' "$DIAG") erreur(s)." >&2
    exit 1
fi

echo "OK — syntaxe et types : les $(ls "$DUELO"/*.swift | wc -l | tr -d ' ') fichiers."
