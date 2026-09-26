import SwiftUI

// MARK: - Paliers de gains
//
// Portage de `src/features/affiliate/AffiliateMilestoneProgress.tsx` et de
// `src/utils/affiliateMilestones.ts` (calcul) — `AffiliateMilestones`.
//
// La source anime la barre sur 700 ms, puis fait apparaître une pastille de
// célébration par un ressort décalé. Ici la barre est animée en fondu sortant et
// la pastille apparaît dès que le palier est atteint : `useReducedMotion` n'a
// pas d'équivalent direct, et la célébration reste purement décorative.

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
                ForEach(summary.milestones) { milestone in
                    AffiliateMilestoneRow(milestone: milestone)
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
