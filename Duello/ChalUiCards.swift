//
//  ChalUiCards.swift
//  Duello
//
//  Lot 11-A — petites cartes de l'écran Défis : statistiques d'attente.
//
//  Fichiers source Expo portés (libellés et mesures repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx (plage 3136-3143) : `QueueStat`
//      (styles `queueStats`, `queueStat`, `queueStatLabel`, `queueStatValue`).
//
//  Réutilise sans les recréer : les cartes du bilan (`ProductionCard`,
//  `QuestionReviewCard` de la source, plage 3146-3262) sont déjà portées par le
//  lot 11-C — respectivement `ChalRunProductionCard` et
//  `ChalRunQuestionReviewCard` — et ne sont donc pas redéfinies ici.
//
//  L'attente n'est pas une animation : le joueur voit depuis combien de temps son
//  invitation attend une réponse.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Statistique de la file d'attente (`QueueStat`) : un libellé et une valeur.
struct ChalUiQueueStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .tracking(0.7)
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.system(size: 14, weight: .black).monospacedDigit())
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 6)
        .background(Theme.white)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

/// Rangée de statistiques d'attente (`queueStats`) : deux cartes côte à côte,
/// chacune de largeur égale.
struct ChalUiQueueStatsRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 17)
    }
}
