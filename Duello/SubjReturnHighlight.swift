//
//  SubjReturnHighlight.swift
//  Duello
//
//  Lot 9-H « lignes de chapitre, étiquettes et barre de progression »
//  (préfixe `Subj`).
//
//  Fichiers source Expo portés :
//    - src/hooks/useReturnHighlightOpacity.ts
//        (`RETURN_HIGHLIGHT_HOLD_MS`, `RETURN_HIGHLIGHT_FADE_MS`,
//         `RETURN_HIGHLIGHT_TOTAL_MS`, `useReturnHighlightOpacity`)
//    - src/screens/SubjectsScreen.tsx : styles `chapterRow`,
//      `chapterReturnHighlight`, `itemReturnHighlight`
//
//  Le fond transitoire est commun aux lignes de chapitre (`ChapterRowContainer`)
//  et aux fiches d'item (`ExerciseItemCard`) : il est donc isolé ici.
//  Cible iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Durées du voile de retour (`useReturnHighlightOpacity`).
enum SubjReturnHighlightTiming {
    /// Le voile tient le temps de retrouver la ligne quittée.
    static let hold: TimeInterval = 1.8
    /// Puis s'efface en fondu (`Easing.out(Easing.cubic)`).
    static let fade: TimeInterval = 1.2
    /// Durée totale du voile (`RETURN_HIGHLIGHT_TOTAL_MS`).
    static var total: TimeInterval { hold + fade }
}

/// Fond transitoire posé sur la ligne de chapitre ou la fiche d'exercice qu'on
/// vient de quitter.
///
/// Comme dans la source, le voile laisse l'élément entièrement interactif
/// (`allowsHitTesting(false)`) : l'appui traverse le fond et atteint la ligne.
struct SubjReturnHighlightBackground: View {
    /// Vrai quand l'élément vient d'être quitté.
    let highlighted: Bool
    /// Rayon du fond : `radii.medium` pour une ligne de chapitre,
    /// `radii.large` pour une fiche d'item.
    var cornerRadius: CGFloat = Theme.radiusMedium

    @State private var opacity: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.surfaceMuted)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { apply(highlighted) }
            .onChange(of: highlighted) { apply($0) }
    }

    /// Reproduit la séquence `Animated.delay(hold)` puis
    /// `Animated.timing(fade, Easing.out(Easing.cubic))` : voile plein, tenue,
    /// puis effacement. Sans mise en évidence, le voile est immédiatement nul.
    private func apply(_ isHighlighted: Bool) {
        guard isHighlighted else {
            opacity = 0
            return
        }
        opacity = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + SubjReturnHighlightTiming.hold) {
            withAnimation(.easeOut(duration: SubjReturnHighlightTiming.fade)) {
                opacity = 0
            }
        }
    }
}
