//
//  ChalHomeOverview.swift
//  Duello
//
//  Lot « Extras de défi » — accueil des défis : bandeau ELO + classement, blason
//  retournable et boutons Défi-Exercice / Défi-Cours.
//
//  Fichier source Expo porté (libellés et mesures repris mot pour mot) :
//    - src/components/ChallengeHomeOverview.tsx
//      (`ChallengeHomeHeader`, `ChallengeHomeActions`, `ChallengeKindButton`,
//       `PERFORMANCE_OVERVIEW_BAR_HEIGHT`)
//
//  Le blason retournable et son revers vivent dans `ChalHomeBadge.swift`. La
//  démonstration d'ouverture réutilise `LeagueBadgeFlipHint` (lot ligue) et son
//  libellé « Démonstration du blason retournable ». Le bandeau partage le
//  gabarit de l'en-tête Entraînement (`ChartPerformanceOverview.barHeight`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Accueil des défis (`ChallengeHomeHeader` + `ChallengeHomeActions`).
struct ChalHomeOverview: View {
    var elo: String
    /// Adresse du blason de ligue ; `nil` ⇒ repli bouclier.
    var badgeURL: URL?
    var leagueLabel: String
    var wins: Int
    var losses: Int
    /// Faux quand le compte ne peut pas encore défier (quota, session expirée).
    var disabled: Bool = false
    var showKindActions: Bool = true
    /// Onglets Défis / Événements, superposés au centre exact de la barre.
    var centered: AnyView? = nil
    var onOpenLeaderboard: () -> Void = {}
    var onOpenExercise: () -> Void = {}
    var onOpenCourse: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ChalHomeHeader(
                elo: elo,
                centered: centered,
                onOpenLeaderboard: onOpenLeaderboard
            )
            ChalHomeActions(
                badgeURL: badgeURL,
                leagueLabel: leagueLabel,
                wins: wins,
                losses: losses,
                disabled: disabled,
                showKindActions: showKindActions,
                onOpenExercise: onOpenExercise,
                onOpenCourse: onOpenCourse
            )
        }
    }
}

/// Bandeau de l'accueil des défis (`ChallengeHomeHeader`).
struct ChalHomeHeader: View {
    var elo: String
    var centered: AnyView?
    var onOpenLeaderboard: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(elo)
                            .font(.system(size: 14, weight: .black))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("ELO")
                            .font(.system(size: 8, weight: .black))
                            .tracking(0.6)
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(elo) Elo")
                    Spacer(minLength: 8)
                    Button(action: onOpenLeaderboard) {
                        Image(systemName: "trophy")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 40, height: 40)
                            .background(Theme.surfaceMuted, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ouvrir le classement Elo")
                }
                if let centered {
                    centered
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 48)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: ChartPerformanceOverview.barHeight)
        .background(Theme.background)
    }
}

/// Blason et boutons de défi (`ChallengeHomeActions`).
struct ChalHomeActions: View {
    var badgeURL: URL?
    var leagueLabel: String
    var wins: Int
    var losses: Int
    var disabled: Bool
    var showKindActions: Bool
    var onOpenExercise: () -> Void
    var onOpenCourse: () -> Void

    @State private var hintVisible = true

    /// Hauteur minimale de la zone de défi.
    ///
    /// `ChallengeHomeOverview.tsx` empile trois conteneurs flexibles
    /// (`challengeHomeAction` : `flex: 1, minHeight: 330` → `actions` :
    /// `flex: 1` → `actionsFull` : `flex: 1, justifyContent: 'center'`) : la
    /// zone **remplit la fenêtre**, le blason et les boutons y sont centrés, et
    /// l'encart — hors flux (`hintCard`, `position: 'absolute', top: 0`) — s'y
    /// ancre en haut sans les recouvrir. `ScrollView` ne distribue pas de
    /// hauteur résiduelle : on fige donc la hauteur minimale à celle qui laisse
    /// le contenu centré **sous** l'encart (blason 176 + boutons 136 = 312 ;
    /// encart 54 + 7 + 7 + 12 = 80 ⇒ 312 + 2 × 80 ≈ 472, arrondi à 480).
    private static let zoneMinHeight: CGFloat = 480

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ChalFlippableBadge(
                    badgeURL: badgeURL,
                    leagueLabel: leagueLabel,
                    wins: wins,
                    losses: losses
                )
                if showKindActions {
                    kindActions
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Self.zoneMinHeight)

            if hintVisible {
                LeagueBadgeFlipHint(
                    accessibilityLabel: "Démonstration du blason retournable",
                    badgeURL: badgeURL,
                    dismissAccessibilityLabel: "Masquer l’explication du blason",
                    onDismiss: { hintVisible = false }
                ) {
                    ChalBadgeBack(
                        badgeURL: badgeURL,
                        wins: wins,
                        losses: losses,
                        compact: true,
                        size: 54
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        // `challengeHomeAction` : paddingTop 6, paddingBottom 20.
        .padding(.top, 6)
        .padding(.bottom, 20)
    }

    /// Défi-Exercice puis Défi-Cours, compacts, hauts et noir sur blanc.
    private var kindActions: some View {
        VStack(spacing: 10) {
            ChalKindButton(
                disabled: disabled,
                icon: "pencil",
                label: "Défi-Exercice",
                action: onOpenExercise
            )
            ChalKindButton(
                disabled: disabled,
                icon: "book",
                label: "Défi-Cours",
                action: onOpenCourse
            )
        }
        .frame(width: 220)
        .padding(.top, 26)
    }
}

/// Bouton de mode de défi (`ChallengeKindButton`).
struct ChalKindButton: View {
    var disabled: Bool
    var icon: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .black))
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.ink, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel("Ouvrir un \(label)")
    }
}
