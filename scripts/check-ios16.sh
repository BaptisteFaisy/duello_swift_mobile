#!/usr/bin/env sh
# Garde-fou iOS 16 — refuse toute API introduite APRÈS iOS 16.
#
# Deux contrôles indépendants des shims :
#   1. la cible de déploiement du projet doit rester en 16.x ;
#   2. aucun fichier de Duello/ ne doit citer une API postérieure.
#
# Pourquoi un garde-fou séparé alors que les shims Linux refusent déjà ces
# API ? Parce qu'un shim est un oracle **écrit à la main** : rien n'empêche
# d'y déclarer par erreur une API iOS 17 — c'est arrivé, `UnevenRoundedRectangle`,
# `topBarTrailing` et `onChange(of:initial:)` y étaient déclarés, et le
# contrôle de types passait donc sans rien voir. Ce script part de la liste des
# API et ne dépend d'aucun shim.
#
# Usage : scripts/check-ios16.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBX="$ROOT/Duello.xcodeproj/project.pbxproj"
SRC="$ROOT/Duello"

# --- 1. Cible de déploiement -------------------------------------------------
[ -f "$PBX" ] || { echo "erreur : $PBX introuvable" >&2; exit 2; }

for t in $(grep -o 'IPHONEOS_DEPLOYMENT_TARGET = [^;]*' "$PBX" | sed 's/.*= //' | sort -u); do
    case "$t" in
        16.*) ;;
        *) echo "erreur : cible de déploiement $t — iOS 16.x attendu" >&2; exit 1 ;;
    esac
done

# --- 2. API postérieures à iOS 16 -------------------------------------------
# Un motif par ligne. `grep -f` les lit en ERE ; une ligne vide matcherait
# tout, d'où l'absence de ligne vide.
API_TROP_RECENTES='UnevenRoundedRectangle
ContentUnavailableView
onGeometryChange
symbolEffect
scrollTargetBehavior
scrollTargetLayout
scrollPosition\(
containerRelativeFrame
PhaseAnimator
KeyframeAnimator
visualEffect\(
scrollTransition
geometryGroup
inspector\(
paletteSelectionEffect
listSectionSpacing
sensoryFeedback
selectionDisabled
buttonRepeatBehavior
springLoadingBehavior
focusEffectDisabled
defaultFocus\(
contentMargins\(
defaultScrollAnchor\(
safeAreaPadding\(
scrollClipDisabled\(
listRowSpacing\(
materialActiveAppearance\(
topBarLeading
topBarTrailing
SectorMark
chartScrollableAxes
chartXSelection
coordinateSpace\(\. 
contentShape\(\. 
@Observable
@Bindable
@Previewable
@Entry
#Preview
onChange\(of:.*, *initial:
onChange\(of:.*\{ *[A-Za-z_][A-Za-z0-9_]* *,
Animation\.spring\(duration:
completionCriteria:
\.smooth\(
\.snappy\(
\.bouncy\(
\.palette\b
\.radioGroup\b
scrollBounceBehavior
presentationBackground
presentationCornerRadius
scrollIndicatorsFlash'

LIST="$(mktemp)"
trap 'rm -f "$LIST"' EXIT
printf '%s\n' "$API_TROP_RECENTES" | sed 's/ *$//' > "$LIST"

# Les commentaires citent volontairement ces noms (pour dire qu'on les évite) :
# ils ne sont pas fautifs.
HITS="$(grep -rnE -f "$LIST" --include='*.swift' "$SRC" \
        | grep -vE ':[0-9]+: *(\*|//|///)' || true)"

if [ -n "$HITS" ]; then
    echo "erreur : API postérieure à iOS 16 :" >&2
    printf '%s\n' "$HITS" >&2
    exit 1
fi

echo "OK — iOS 16 : cible $(grep -o 'IPHONEOS_DEPLOYMENT_TARGET = [^;]*' "$PBX" | sed 's/.*= //' | sort -u | tr '\n' ' '), aucune API postérieure citée."
