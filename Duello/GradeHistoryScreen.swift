//
//  GradeHistoryScreen.swift
//  Duello
//
//  Page dédiée à l'historique complet des notes (vague I7, parité RN dev).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/GradeHistoryScreen.tsx (`GradeHistoryScreen`)
//
//  Réutilise `AcctGradeHistoryCard` (`GradeHistoryCard`, `showTitle: false`) et
//  `IonIcon` (`chevron-back`). La page ne répète pas le titre : seul le chevron
//  retour l'identifie. Cible iOS 16.
//
import SwiftUI

/// `GradeHistoryScreen` de `src/screens/GradeHistoryScreen.tsx` : un chevron
/// retour seul en haut, sans titre, puis toutes les lignes.
struct GradeHistoryScreen: View {
    /// Toutes les notes du compte, de la plus récente à la plus ancienne,
    /// rattachées au programme du spectateur (`resolveHistoryRow`).
    let rows: [ResolvedGradeHistoryRow]
    /// Ferme la page et revient au profil.
    let onBack: () -> Void
    /// Rouvre le sujet d'une ligne lorsque le spectateur y a accès
    /// (`onOpenItem`, `GradeHistoryScreen.tsx:14`).
    var onOpenItem: ((ChalRunTrainingTarget) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                AcctGradeHistoryCard(rows: rows, onOpenItem: onOpenItem, showTitle: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.white)
    }

    /// `styles.header` : le chevron retour seul, à gauche.
    private var header: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                IonIcon(name: "chevron-back", size: 20, color: Theme.ink)
                    .frame(minWidth: 40, minHeight: 40, alignment: .center)
                    // `styles.icon` : le chevron est rentré de 4 points.
                    .offset(x: -4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retour au profil")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
