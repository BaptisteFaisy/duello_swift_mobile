#!/usr/bin/env sh
# Type-check COMPLET du projet Duello sous Linux, via les shims.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIMS="$ROOT/scripts/linux-shims"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
MODS="CoreGraphics Security UIKit Combine GoogleSignIn Photos UniformTypeIdentifiers SwiftUI Charts PhotosUI AVFoundation LocalAuthentication UserNotifications MessageUI AuthenticationServices WebKit PDFKit Speech CryptoKit"
for m in $MODS; do
  files=""
  for f in "$SHIMS/$m.swift" "$SHIMS/$m"+*.swift; do
    [ -f "$f" ] && files="$files $f"
  done
  [ -z "$files" ] && continue
  if ! swiftc -emit-module -module-name "$m" $files -I "$WORK" \
        -emit-module-path "$WORK/$m.swiftmodule" 2>"$WORK/err-$m.txt"; then
    echo "!! module $m : ÉCHEC"; head -15 "$WORK/err-$m.txt"; continue
  fi
done
echo "=== modules construits : $(ls "$WORK"/*.swiftmodule 2>/dev/null | wc -l) ==="
mkdir -p "$WORK/src"
for f in "$ROOT"/Duello/*.swift; do
  b="$(basename "$f")"
  sed 's/^import Foundation$/import Foundation\nimport FoundationNetworking/' "$f" > "$WORK/src/$b"
done
swiftc -typecheck -enable-batch-mode -I "$WORK" "$WORK"/src/*.swift > "$WORK/diag.txt" 2>&1 || true
echo "=== fichiers examinés : $(ls "$WORK"/src/*.swift | wc -l) ==="
echo "=== erreurs par fichier (top 30) ==="
grep -oE "^[^:]+:[0-9]+:[0-9]+: error:" "$WORK/diag.txt" | cut -d: -f1 | xargs -n1 basename | sort | uniq -c | sort -rn | head -30
echo "=== total erreurs : $(grep -c "error:" "$WORK/diag.txt" || true) ==="
echo "=== messages distincts (top 25) ==="
grep -oE "error: .*" "$WORK/diag.txt" | sort | uniq -c | sort -rn | head -25
