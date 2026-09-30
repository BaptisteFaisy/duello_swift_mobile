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
//  Écart corrigé (V1 L5, 2026-09-26, U07 partA#1 + partB#1) : la source ouvre
//  le volet d'invitation d'un ami depuis les boutons Défi-Exercice /
//  Défi-Cours — désormais câblé par `ChalIntChallengesTab` (`.sheet` sur
//  `SocialChallengeInviteModal`) ; `onEnter` ne sert plus que le panneau de
//  file.
//
//  S01 (2026-09-30, producteurs de chrome) : ajoute l'entrée « Défie ta
//  classe » (`classChallengeButton`, tsx:2879-2900), masquée dans la source,
//  pour rendre atteignable le volet « défi de classe » (`ChalIntChallengesTab`
//  → `ChalClassInviteSheet` → `ChalScheduledRoom.join`). Fichier hors liste du
//  lot, non revendiqué par un autre lot de la vague 6 (cf. rapport S01b).
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
    /// Ouvre le volet « défi de classe » (`setClassInviteModalOpen(true)`,
    /// `ChallengesScreen.tsx:2884-2887`). Absent ⇒ pas de bouton.
    var onOpenClassChallenge: (() -> Void)? = nil
    var onEnter: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    ChalHome2HomeNotices(
                        playable: playable,
                        launchError: launchError
                    )

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

                    // « Défie ta classe » (`challengeActionButton` +
                    // `classChallengeButton`, tsx:2879-2900). La source masque
                    // temporairement ce bouton ; le volet est néanmoins câblé
                    // (`ChalIntChallengesTab`), on le rétablit pour le rendre
                    // atteignable.
                    if let onOpenClassChallenge {
                        Button(action: onOpenClassChallenge) {
                            HStack(spacing: 6) {
                                IonIcon(name: "people-outline", size: 18, color: Theme.primary)
                                Text("Défie ta classe")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(Theme.primary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 16)
                            .frame(width: 260)
                            .frame(minHeight: 46)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.primary, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Défie ta classe")
                        .padding(.top, 10)
                    }

                    // Le retour d'invitation vient **après** la carte d'accueil,
                    // comme la source (`queue.inviteOutcome`).
                    if let inviteOutcome = queue.inviteOutcome {
                        ChalHome2InviteOutcomeCard(outcome: inviteOutcome)
                    }
                }
                // `scrollContent` (20 / 8 / 34) et `challengeHomeContent`
                // (`flexGrow: 1`) : le contenu remplit la fenêtre pour que la
                // zone de défi (`challengeHomeAction`, `flex: 1`) s'y étende.
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
    }
}
