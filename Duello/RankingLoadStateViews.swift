import Foundation
import SwiftUI

//  V1 (2026-09-29) — écart P2 : la carte d'état porte l'ombre de carte
//  (`stateCard` : `...cardShadow`, `RankingsScreen.tsx:825-835`). L'ombre des
//  deux docks (`currentUserDock`, `RankingSubjectLeaderboard.swift` et
//  `RankingWeeklyXp.swift`) reste hors lot (cf. « À raccorder »).

// MARK: - État de chargement

/// Étapes du chargement d'un classement (voir `LoadState` de
/// `RankingsScreen.tsx`). Nommée pour ne pas entrer en conflit avec le
/// `LoadState` partagé de `ChallengesView.swift`.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car partagé par `RankingSubjectLeaderboard` et
/// `RankingWeeklyXp` — nom, cas et corps inchangés.
enum RankingLoadPhase {
    case loading
    case ready
    case error
}

// MARK: - Carte d'état

/// Carte d'état d'un classement : attente, panne et bouton de réessai.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car instancié depuis `RankingSubjectLeaderboard` et
/// `RankingWeeklyXp` — mêmes membres, mêmes valeurs par défaut. Les icônes
/// sont les glyphes Ionicons de la source (`cloud-offline-outline`, `refresh`).
struct RankingStatusCard: View {
    let icon: String
    let title: String
    var message: String? = nil
    /// Notice locale affichée sous le message d'erreur (`localEloNotice`,
    /// `localNotice`) : rappelle que la cote ou les XP locaux restent pris en
    /// compte malgré la panne du classement.
    var notice: String? = nil
    var showsProgress: Bool = false
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.surfaceMuted)
                    .frame(width: 34, height: 34)
                if showsProgress {
                    ProgressView().tint(Theme.ink)
                } else {
                    IonIcon(name: icon, size: 20, color: Theme.ink)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if let message {
                    Text(message)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let notice {
                    Text(notice)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let retry {
                Button(action: retry) {
                    IonIcon(name: "refresh", size: 17, color: Theme.ink)
                        .frame(width: 36, height: 36)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Réessayer de charger le classement")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .frame(minHeight: 88)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        // `stateCard` : `...cardShadow` (`theme.ts`) — même ombre que les cartes
        // de ligne (`RankingRowViews.swift`).
        .duelloShadow()
    }
}
