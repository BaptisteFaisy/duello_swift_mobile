//
//  ProfSheetHeight.swift
//  Duello
//
//  Port de `src/utils/profSheetHeight.ts` (RN) — bottom-sheet du prof IA :
//  hauteur réglable au doigt sur la poignée. Les ratios se rapportent à la
//  hauteur de la fenêtre.
//
//  Fonctions pures, sans SwiftUI : mêmes butées, mêmes paliers d'aimantation et
//  même seuil de fermeture que la source (cf. `profSheetHeight.test.ts`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import CoreGraphics

/// Hauteur d'ouverture : le corrigé reste visible derrière le panneau.
let PROF_SHEET_DEFAULT_RATIO: CGFloat = 0.78
/// Butées pendant le glisser : le panneau ne couvre ni tout l'écran ni rien.
let PROF_SHEET_MIN_RATIO: CGFloat = 0.34
let PROF_SHEET_MAX_RATIO: CGFloat = 0.94
/// Relâché sous ce seuil, le panneau se referme au lieu de s'aimanter.
let PROF_SHEET_CLOSE_RATIO: CGFloat = 0.26

/// Paliers d'aimantation au relâcher : bas, milieu, ouverture, presque plein.
let PROF_SHEET_SNAP_RATIOS: [CGFloat] = [0.38, 0.6, 0.78, 0.92]

/// `clampProfSheetRatio` : borne un ratio glissé entre les butées du panneau.
func clampProfSheetRatio(_ ratio: CGFloat) -> CGFloat {
    guard ratio.isFinite else { return PROF_SHEET_DEFAULT_RATIO }
    return min(PROF_SHEET_MAX_RATIO, max(PROF_SHEET_MIN_RATIO, ratio))
}

/// `snapProfSheetRatio` : aimante le ratio relâché sur le palier le plus proche.
func snapProfSheetRatio(_ ratio: CGFloat) -> CGFloat {
    guard ratio.isFinite, let first = PROF_SHEET_SNAP_RATIOS.first else {
        return PROF_SHEET_DEFAULT_RATIO
    }
    var best = first
    for snap in PROF_SHEET_SNAP_RATIOS where abs(snap - ratio) < abs(best - ratio) {
        best = snap
    }
    return best
}

/// `shouldCloseProfSheetOnRelease` : vrai quand le relâcher referme le panneau.
func shouldCloseProfSheetOnRelease(_ ratio: CGFloat) -> Bool {
    ratio.isFinite && ratio < PROF_SHEET_CLOSE_RATIO
}
