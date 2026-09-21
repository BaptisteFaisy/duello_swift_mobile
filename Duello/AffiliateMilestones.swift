import Foundation

// MARK: - Paliers de gains
//
// Portage de `src/utils/affiliateMilestones.ts` : les cinq paliers séquentiels,
// le cumul de gains depuis l'ouverture du compte et la progression vers le
// prochain palier.

/// Paliers de gains et cumul du compte affilié.
enum AffiliateMilestones {
    /// `AFFILIATE_EARNING_MILESTONES_MINOR` : 1 €, 5 €, 10 €, 20 € et 50 €,
    /// en centimes.
    static let targetsMinor = [100, 500, 1_000, 2_000, 5_000]

    /// `affiliateLifetimeEarningsMinor` : disponible + en cours + déjà versé.
    /// Un retrait ne remet donc pas les paliers à zéro. La somme sature au lieu
    /// de déborder (la source borne au plus grand entier sûr de JavaScript).
    static func lifetimeEarningsMinor(
        availableMinor: Int,
        reservedMinor: Int,
        paidMinor: Int
    ) -> Int {
        saturatedSum(saturatedSum(availableMinor, reservedMinor), paidMinor)
    }

    /// `buildAffiliateMilestoneSummary` : chaque palier porte sa propre
    /// progression ; les paliers suivants restent verrouillés.
    static func summary(earnedMinor value: Int) -> AffMilestoneSummary {
        let earnedMinor = Swift.max(0, value)
        var previousTargetMinor = 0
        var milestones: [AffMilestone] = []
        for targetMinor in targetsMinor {
            let progress = stageProgress(
                earnedMinor: earnedMinor,
                previousTargetMinor: previousTargetMinor,
                targetMinor: targetMinor
            )
            milestones.append(
                AffMilestone(
                    targetMinor: targetMinor,
                    progress: progress,
                    status: status(earnedMinor: earnedMinor, previousTargetMinor: previousTargetMinor, targetMinor: targetMinor)
                )
            )
            previousTargetMinor = targetMinor
        }
        let nextTargetMinor = milestones.first { $0.status != .reached }?.targetMinor
        return AffMilestoneSummary(
            earnedMinor: earnedMinor,
            milestones: milestones,
            nextTargetMinor: nextTargetMinor,
            remainingMinor: nextTargetMinor.map { $0 - earnedMinor } ?? 0
        )
    }

    /// `milestoneProgress` : part du palier courant déjà couverte.
    private static func stageProgress(
        earnedMinor: Int,
        previousTargetMinor: Int,
        targetMinor: Int
    ) -> Double {
        let stageSize = targetMinor - previousTargetMinor
        guard stageSize > 0 else { return earnedMinor >= targetMinor ? 1 : 0 }
        let stageEarnings = Double(earnedMinor - previousTargetMinor)
        return Swift.min(1, Swift.max(0, stageEarnings / Double(stageSize)))
    }

    /// Statut du palier : atteint, en cours, ou encore verrouillé.
    private static func status(
        earnedMinor: Int,
        previousTargetMinor: Int,
        targetMinor: Int
    ) -> AffMilestoneStatus {
        if earnedMinor >= targetMinor { return .reached }
        return earnedMinor >= previousTargetMinor ? .active : .locked
    }

    /// Somme qui sature au lieu de déborder.
    private static func saturatedSum(_ first: Int, _ second: Int) -> Int {
        let (sum, overflow) = first.addingReportingOverflow(second)
        return overflow ? Int.max : sum
    }
}
