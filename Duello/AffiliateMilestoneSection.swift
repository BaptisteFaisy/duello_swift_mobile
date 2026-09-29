import SwiftUI

// MARK: - Paliers de gains
//
// Port de `src/features/affiliate/AffiliateMilestoneProgress.tsx` et de
// `src/utils/affiliateMilestones.ts` (calcul) — `AffiliateMilestones`.
//
// La source anime la barre sur 700 ms (`Easing.out(Easing.cubic)`), puis fait
// « popper » la pastille de célébration via `Animated.spring(friction: 4,
// tension: 120)` décalé de `order * 90 ms` (échelonné). Ici la barre est animée
// en sortie douce et la pastille apparaît par
// `interpolatingSpring(stiffness: 120, damping: 4)` décalée de `order * 0.09 s`.
//
// Écarts assumés :
// - `useReducedMotion` (Reanimated) n'est pas répliqué : la célébration reste
//   purement décorative.
// - RN ne démarre le pop qu'à la fin du remplissage (700 ms), le décalage
//   `order * 90 ms` s'y ajoutant ; ici le pop est lancé à l'apparition, décalé
//   du seul `order * 0.09 s` (cf. brief ANIM-04).

/// `AffiliateMilestoneProgress` : cumul de gains et cinq paliers séquentiels.
struct AffiliateMilestoneSection: View {
    let wallet: AffWallet

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PALIERS DE GAINS")
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(0.8)
                        .foregroundStyle(Theme.inkSoft)
                    Text("\(AffiliateFormatting.amount(summary.earnedMinor)) cumulés")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "trophy")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }

            Text(remainingCopy)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(summary.milestones.enumerated()), id: \.element.id) { order, milestone in
                    AffiliateMilestoneRow(milestone: milestone, order: order)
                }
            }
            .padding(.top, 17)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// `buildAffiliateMilestoneSummary(affiliateLifetimeEarningsMinor(wallet))`.
    private var summary: AffMilestoneSummary {
        AffiliateMilestones.summary(
            earnedMinor: AffiliateMilestones.lifetimeEarningsMinor(
                availableMinor: wallet.availableMinor,
                reservedMinor: wallet.reservedMinor,
                paidMinor: wallet.paidMinor
            )
        )
    }

    private var remainingCopy: String {
        guard summary.nextTargetMinor != nil else {
            return "Tous les paliers sont atteints."
        }
        return "\(AffiliateFormatting.amount(summary.remainingMinor)) avant le prochain palier"
    }
}

/// `AffiliateMilestoneRow` : un palier, sa progression et sa pastille atteinte.
struct AffiliateMilestoneRow: View {
    let milestone: AffMilestone
    /// Position dans la liste, source du décalage `order * 90 ms` du pop.
    let order: Int

    @State private var badgeScale: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(AffiliateFormatting.amount(milestone.targetMinor))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(milestone.status == .locked ? Theme.inkFaint : Theme.ink)
                Spacer(minLength: 0)
                trailing
            }
            .frame(minHeight: 21)

            DuelloProgressTrack(fraction: milestone.progress, height: 8)
                .animation(.easeOut(duration: 0.7), value: milestone.progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(percentText)
    }

    /// Pourcentage arrondi, comme `Math.round(progress * 100)`.
    private var percent: Int { Int((milestone.progress * 100).rounded()) }

    private var percentText: String { "\(percent) %" }

    @ViewBuilder
    private var trailing: some View {
        if milestone.status == .reached {
            ZStack {
                Circle()
                    .fill(Theme.progressLight)
                    .frame(width: 21, height: 21)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.progress)
            }
            .scaleEffect(badgeScale)
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 120, damping: 4)
                    .delay(Double(order) * 0.09)) {
                    badgeScale = 1
                }
            }
        } else {
            Text(percentText)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// `Palier 10,00 €, atteint` ou `Palier 10,00 €, 40 %`.
    private var accessibilityLabel: String {
        let target = AffiliateFormatting.amount(milestone.targetMinor)
        let state = milestone.status == .reached ? "atteint" : percentText
        return "Palier \(target), \(state)"
    }
}
