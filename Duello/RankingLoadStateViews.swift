import Foundation
import SwiftUI

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
/// `RankingWeeklyXp` — mêmes membres, mêmes valeurs par défaut, même corps.
struct RankingStatusCard: View {
    let icon: String
    let title: String
    var message: String? = nil
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
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if let message {
                    Text(message)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let retry {
                Button(action: retry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
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
        .duelloCard()
    }
}
