//
//  ChalHomeBadge.swift
//  Duello
//
//  Lot « Extras de défi » — blason retournable de l'accueil des défis : avers
//  (blason de ligue) et revers (VICTOIRES / DÉFAITES).
//
//  Fichier source Expo porté (libellés et mesures repris mot pour mot) :
//    - src/components/ChallengeHomeOverview.tsx
//      (`BADGE_SIZE`, `resultLabel`, `useBadgeFlip`, `LeagueBadgeVisual`,
//       `ChallengeBadgeBack`, `FlippableChallengeBadge`)
//
//  Mesures pixel des 22 PNG de blasons : le dessin n'occupe que 64,5–68,8 % du
//  carré ; à 176 il fait ~114–121 px et la rangée VICTOIRES / DÉFAITES (58 % du
//  carré, top 27 %) tient dans les contours, centrée sur le corps du blason.
//  Les PNG n'étant pas embarqués, le blason est chargé à distance
//  (`LeagueBadgeOutline`) ; `backfaceVisibility: hidden` est reproduit en
//  n'affichant que la face tournée vers l'écran.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Libellé « n victoires » / « n défaites » (`resultLabel`).
private func chalResultLabel(_ value: Int, _ singular: String, _ plural: String) -> String {
    "\(value) \(value > 1 ? plural : singular)"
}

/// Blason retournable (`FlippableChallengeBadge`).
struct ChalFlippableBadge: View {
    var badgeURL: URL?
    var leagueLabel: String
    var wins: Int
    var losses: Int

    /// Taille du blason, identique sur mobile et web (`BADGE_SIZE`).
    static let size: CGFloat = 176

    @State private var showingBack = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.42)) { showingBack.toggle() }
        } label: {
            ZStack {
                ChalBadgeVisual(badgeURL: badgeURL, size: Self.size)
                    .opacity(showingBack ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(showingBack ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                ChalBadgeBack(badgeURL: badgeURL, wins: wins, losses: losses)
                    .opacity(showingBack ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(showingBack ? 360 : 180),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
            }
            .frame(width: Self.size, height: Self.size)
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Étiquette du bouton, mot pour mot de la source.
    private var accessibilityLabel: String {
        if showingBack {
            return "Afficher le recto du blason \(leagueLabel)"
        }
        let winsLabel = chalResultLabel(wins, "victoire", "victoires")
        let lossesLabel = chalResultLabel(losses, "défaite", "défaites")
        return "Afficher le verso du blason : \(winsLabel), \(lossesLabel)"
    }
}

/// Avers du blason : le PNG de ligue, ou le repli bouclier (`LeagueBadgeVisual`).
struct ChalBadgeVisual: View {
    var badgeURL: URL?
    var size: CGFloat

    var body: some View {
        Group {
            if let badgeURL {
                CachedRemoteImage(url: badgeURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
            } else {
                Image(systemName: "shield")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Revers du blason : rangée VICTOIRES / DÉFAITES dans les contours
/// (`ChallengeBadgeBack`).
struct ChalBadgeBack: View {
    var badgeURL: URL?
    var wins: Int
    var losses: Int
    /// Version compacte de la démonstration (`compact`).
    var compact: Bool = false
    var size: CGFloat = ChalFlippableBadge.size

    var body: some View {
        ZStack {
            LeagueBadgeOutline(badgeURL: badgeURL, size: size)
            HStack(spacing: 0) {
                stat(value: wins, label: compact ? "V" : "VICTOIRES")
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 1, height: compact ? 21 : 53)
                stat(value: losses, label: compact ? "D" : "DÉFAITES")
            }
            .frame(width: size * (compact ? 0.50 : 0.58))
            .padding(.top, size * (compact ? 0.26 : 0.27))
            .frame(width: size, height: size, alignment: .top)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Une colonne de statistique : valeur puis libellé, ajustés automatiquement.
    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: compact ? 0 : 3) {
            Text("\(value)")
                .font(.system(size: compact ? 10 : 25, weight: .black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: compact ? 5 : 7, weight: .black))
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}
