#!/usr/bin/env sh
# Contrôle Swift sous macOS (variante du script Linux) — COMPLÈTE Xcode, ne le remplace pas.
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
# Requiert : swiftc (Xcode CLT macOS).
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

echo "1/4  Cible iOS 16 — garde-fou indépendant des shims…"
sh "$ROOT/scripts/check-ios16.sh"

echo "2/4  Shims Linux — 19 modules factices (hors cible Xcode)…"
# Ordre de dépendance : CoreGraphics/UIKit/Combine d'abord, puis les modules
# feuilles, puis SwiftUI (qui importe Photos, PhotosUI, UIKit, Combine,
# UniformTypeIdentifiers), puis Charts (qui importe SwiftUI).
FORCE_SHIM="SwiftUI Charts UIKit GoogleSignIn"
MODS="CoreGraphics Security UIKit Combine GoogleSignIn Photos PhotosUI \
UniformTypeIdentifiers SwiftUI Charts AVFoundation LocalAuthentication \
UserNotifications MessageUI AuthenticationServices WebKit PDFKit Speech CryptoKit"
for m in $MODS; do
    # macOS : si le module existe en natif (SDK), on garde le natif et on
    # ignore le shim (sinon : circular dependency Foundation/Security, etc).
    # EXCEPTION : SwiftUI/Charts/UIKit/GoogleSignIn sont TOUJOURS shimés :
    # le SwiftUI natif macOS n'a pas les API iOS (keyboardType, UIKeyboardType…)
    # que le code utilise ; les shims reproduisent la surface iOS.
    case " $FORCE_SHIM " in
        *" $m "*) ;;
        *)
            if echo "import $m" | swiftc -typecheck - >/dev/null 2>&1; then
                echo "  (natif : $m — shim ignoré)"
                continue
            fi
            ;;
    esac
    files=""
    mkdir -p "$WORK/shimsrc"
    for f in "$SHIMS/$m.swift" "$SHIMS/$m"+*.swift; do
        [ -f "$f" ] || continue
        # macOS : les shims n'importent que Foundation (suffisant sous Linux
        # avec le shim CoreGraphics) ; en natif il faut l'import explicite.
        dest="$WORK/shimsrc/$(basename "$f")"
        cp "$f" "$dest"
        if grep -qE 'CGRect|CGFloat|CGPoint|CGSize|CGVector|CGImage|CGColor|CGContext' "$dest" \
            && ! grep -q '^import CoreGraphics' "$dest"; then
            { echo 'import CoreGraphics'; cat "$dest"; } > "$dest.tmp" && mv "$dest.tmp" "$dest"
        fi
        # macOS : FoundationNetworking n'existe pas (c'est dans Foundation).
        if grep -q 'import FoundationNetworking' "$dest"; then
            sed -e '/^import FoundationNetworking$/d' -e '/^@_exported import FoundationNetworking$/d' "$dest" > "$dest.tmp" && mv "$dest.tmp" "$dest"
        fi
        files="$files $dest"
    done
    [ -z "$files" ] && continue
    # shellcheck disable=SC2086
    # `-D DUELLO_SHIM_NATIVE_SDK` SANS valeur : en Swift, `-D X=1` ne rend pas
    # le define vrai (`#if X` reste faux, `#if !X` reste vrai) — vérifié.
    # Le flag sert à ne PAS redéclarer ce que le SDK natif fournit déjà
    # (`Never: View`, `AttributeScopes.SwiftUIAttributes`). Le test se fait par
    # ce flag et NON par `canImport(FoundationNetworking)`, qui devient VRAI
    # dès qu'un .swiftmodule est présent dans le -I — donc ici systématiquement.
    if [ "$m" = "SwiftUI" ]; then
        # swift-frontend plante (signal 6, SILDeserializer) quand le module
        # local s'appelle `SwiftUI` et masque le module SwiftUI du SDK, dès
        # qu'un autre .swiftmodule est présent dans le -I. Le code de Duello
        # fait `import SwiftUI` : on compile donc le shim sous un nom interne,
        # puis un module `SwiftUI` d'une ligne qui le réexporte.
        if ! swiftc -emit-module -module-name DuelloSwiftUIShim $files \
                -D DUELLO_SHIM_NATIVE_SDK -I "$WORK" \
                -emit-module-path "$WORK/DuelloSwiftUIShim.swiftmodule" \
                2>"$WORK/shim-$m.txt"; then
            echo "erreur : le shim $m ne compile pas" >&2
            grep "error:" "$WORK/shim-$m.txt" | head -20 >&2
            exit 1
        fi
        printf '@_exported import DuelloSwiftUIShim\n' > "$WORK/$m-wrapper.swift"
        if ! swiftc -emit-module -module-name "$m" "$WORK/$m-wrapper.swift" -I "$WORK" \
                -emit-module-path "$WORK/$m.swiftmodule" 2>>"$WORK/shim-$m.txt"; then
            echo "erreur : le module $m ne compile pas" >&2
            grep "error:" "$WORK/shim-$m.txt" | head -20 >&2
            exit 1
        fi
        continue
    fi
    if ! swiftc -emit-module -module-name "$m" $files -D DUELLO_SHIM_NATIVE_SDK -I "$WORK" \
            -emit-module-path "$WORK/$m.swiftmodule" 2>"$WORK/shim-$m.txt"; then
        echo "erreur : le shim $m ne compile pas" >&2
        grep "error:" "$WORK/shim-$m.txt" | head -20 >&2
        exit 1
    fi
done

echo "3/4  Syntaxe — tous les fichiers .swift…"
swiftc -parse "$DUELO"/*.swift

echo "4/4  Types — les 649 fichiers, en lot…"
mkdir -p "$WORK/src"
# macOS : URLSession vit dans Foundation ; on RETIRE l'import Linux-only.
for f in "$DUELO"/*.swift; do
    sed '/^import FoundationNetworking$/d' \
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
