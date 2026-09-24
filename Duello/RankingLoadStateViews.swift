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
/// `RankingWeeklyXp`.
///
/// Rendue sur le `stateCard` RN (`RankingsScreen.tsx:825-834` =
/// `WeeklyXpRankingScreen.tsx:500-509`) : `padding 15`, rayon
/// `radii.large` (18), `cardShadow`, `minHeight 88`, fond `surface`,
/// **sans bord**. `duelloCard()` ne peut pas rendre ce cas (il ajoute
/// toujours un bord, `Theme.swift:127-130`) → carte dessinée en jetons du
/// thème, même motif que `RankingWeeklyXp.loadingCard/errorCard`.
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
            if showsProgress {
                // RN (chargement) : l'`ActivityIndicator` est posé directement
                // dans la carte, **sans** cadre d'icône (`RankingsScreen.tsx:505`).
                ProgressView().tint(Theme.ink)
            } else {
                // `stateIcon` : carré `surfaceMuted` 34×34, rayon 12, glyphe 20 `ink`.
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surfaceMuted)
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Theme.ink)
                }
            }

            // `stateCopy` : pas d'espacement uniforme, marges explicites
            // (`stateText` marginTop 5, `localEloNotice` marginTop 6).
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                if let message {
                    Text(message)
                        .font(.system(size: 10, weight: .semibold))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                }
                if let notice {
                    Text(notice)
                        .font(.system(size: 10, weight: .heavy))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let retry {
                Button(action: retry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .regular))
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
        // `stateCard` RN : `...cardShadow`, `minHeight 88`, `padding 15`,
        // `borderRadius radii.large` (18), fond `surface`, **sans `borderWidth`**
        // (`RankingsScreen.tsx:825-834`). `duelloCard()` ajoute toujours un bord
        // (`Theme.swift:127-130`) → carte dessinée en jetons du thème.
        // `marginTop 18` (RN) est posé par les appelants (`.padding(.top, 18)`).
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .duelloShadow()
    }
}
