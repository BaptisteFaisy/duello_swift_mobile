//
//  ChalIntHomePage.swift
//  Duello
//
//  Lot 18 — intégration de l'onglet « Défis » : page « Défis » de l'accueil.
//
//  Fichier source Expo porté : `src/screens/ChallengesScreen.tsx`
//  (branche `status === 'idle'`, plage 2804-2916 : annonces, carte d'accueil
//  `ChallengeHomeActions` puis file d'attente).
//
//  Réutilise sans les recréer : `ChalHome2HomeNotices` (avis d'exercices
//  jouables, échec de lancement, retour d'invitation), `ChalHomeActions`
//  (blason retournable + boutons Défi-Exercice / Défi-Cours) et
//  `ChalHome2QueuePanel` (bouton d'entrée / carte de recherche / carte
//  d'adversaire trouvé). La barre ELO et les onglets Défis / Événements sont
//  fournis par la surface (`ChalHome2HomeSurface`) : cette page ne les redouble
//  pas.
//
//  Écart assumé : la source ouvre le volet d'invitation d'un ami depuis les
//  boutons Défi-Exercice / Défi-Cours ; ce volet n'est pas porté (voir réponse
//  du lot), les deux boutons retombent donc sur la file aléatoire (`onEnter`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Page « Défis » de l'accueil : annonces, blason + boutons de défi, puis file
/// d'attente. La page « Événements » est déléguée à `EventsView`.
///
/// `@MainActor` : la page lit l'état de `ChalQueueController`, isolé sur
/// l'acteur principal (comme `ChalHome2QueuePanel`).
@MainActor
struct ChalIntHomePage: View {
    @ObservedObject var queue: ChalQueueController
    /// Adresse du blason de ligue ; `nil` ⇒ repli bouclier.
    let badgeURL: URL?
    let leagueLabel: String
    let wins: Int
    let losses: Int
    let playable: ChalHome2PlayableNotice
    let launchError: String?
    /// Faux quand le compte ne peut pas défier (filière, file occupée).
    let disabled: Bool
    var onOpenExercise: () -> Void
    var onOpenCourse: () -> Void
    var onEnter: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ChalHome2HomeNotices(
                    playable: playable,
                    launchError: launchError
                )
                .padding(.horizontal, 20)

                ChalHomeActions(
                    badgeURL: badgeURL,
                    leagueLabel: leagueLabel,
                    wins: wins,
                    losses: losses,
                    disabled: disabled,
                    showKindActions: true,
                    onOpenExercise: onOpenExercise,
                    onOpenCourse: onOpenCourse
                )

                // Le retour d'invitation vient **après** la carte d'accueil,
                // comme la source (`queue.inviteOutcome`).
                if let inviteOutcome = queue.inviteOutcome {
                    ChalHome2InviteOutcomeCard(outcome: inviteOutcome)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
    }
}
