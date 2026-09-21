//
//  ExGExerciseWorkspace.swift
//  Duello
//
//  Espace de travail d'un exercice (`ChallengeExerciseWorkspace.tsx`) : les
//  trois blocs — introduction, énoncé, réponse — empilés dans un défilement.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ChallengeExerciseWorkspace.tsx    (espace de travail)
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - §1 — Espace de travail d'exercice

/// Espace de travail d'un exercice (`ChallengeExerciseWorkspace.tsx`).
///
/// Version téléphone : les trois blocs — introduction, énoncé, réponse —
/// s'empilent dans un seul défilement, aux mêmes marges que la source
/// (`paddingHorizontal 20`, `paddingTop 8`, `paddingBottom 34`).
/// La disposition « bureau installé » (deux volets + séparateur déplaçable) est
/// **hors périmètre** : elle appartient à l'app de bureau, pas au mobile.
struct ExGExerciseWorkspace<Intro: View, Statement: View, Response: View>: View {
    private let intro: Intro
    private let statement: Statement
    private let response: Response

    init(@ViewBuilder intro: () -> Intro,
         @ViewBuilder statement: () -> Statement,
         @ViewBuilder response: () -> Response) {
        self.intro = intro()
        self.statement = statement()
        self.response = response()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                intro
                statement
                response
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 34)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
    }
}
