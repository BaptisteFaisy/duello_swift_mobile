import Foundation

// MARK: - Modèles de l'espace affiliation (lot « Affiliation »)
//
// Portage de `src/utils/affiliate.ts` et `src/utils/affiliateProgram.ts` :
// portefeuille d'affiliation, compte Stripe Connect, historique des retraits et
// paliers de gains. Les montants restent en **centimes** (`*Minor`) comme dans
// la source : aucun flottant ne porte d'argent.
//
// Sources Expo :
//   - `src/utils/affiliate.ts` (`AffiliateWallet`, `AffiliateWithdrawal`,
//     `AffiliateConnection`, `formatAffiliateAmount`…)
//   - `src/utils/affiliateProgram.ts` (`AFFILIATE_PAYMENT_REWARD_MINOR/LABEL`)
//   - `src/features/affiliate/affiliateEarningsViewModel.ts`
//   - `src/features/affiliate/affiliateEarningsStyles.ts` (palette, mesures)

/// `AffiliatePayoutMode` — régime de versement du programme d'affiliation.
enum AffPayoutMode: String, Equatable {
    case off
    case shadow
    case sandbox
    case live
}

/// `AffiliateConnectionStatus` — état du compte Stripe Connect du compte affilié.
enum AffConnectionStatus: String, Equatable {
    case notStarted = "not_started"
    case onboarding
    case ready
    case restricted
}

/// `AffiliateWithdrawalStatus` — cycle de vie d'une demande de virement.
enum AffWithdrawalStatus: String, Equatable {
    case requested
    case transferring
    case uncertain
    case transferCreated = "transfer_created"
    case payoutCreating = "payout_creating"
    case payoutPending = "payout_pending"
    case payoutFailed = "payout_failed"
    case paid
    case failed
    case shadowed
}

/// `AffiliateWalletCompatibilityWarning` — donnée historique non exploitable.
enum AffCompatibilityWarning: String, Equatable {
    case stripeConnection = "stripe-connection"
    case withdrawalHistory = "withdrawal-history"
}

/// `AffiliateConnection` — état du compte Stripe Connect, sans identifiant
/// opaque : le téléphone n'en conserve ni ne journalise aucun.
struct AffConnection: Equatable {
    let status: AffConnectionStatus
    let detailsSubmitted: Bool
    let payoutsEnabled: Bool
    let transfersEnabled: Bool
    let requirementsDue: [String]
    let updatedAt: String?

    /// Repli de la source quand la charge utile Stripe n'est pas comprise :
    /// aucun retrait n'est alors autorisé et l'état est signalé comme restrictif.
    static let restricted = AffConnection(
        status: .restricted,
        detailsSubmitted: false,
        payoutsEnabled: false,
        transfersEnabled: false,
        requirementsDue: [],
        updatedAt: nil
    )
}

/// `AffiliateWithdrawal` — une demande de virement et son statut.
struct AffWithdrawal: Identifiable, Equatable {
    let id: String
    let amountMinor: Int
    let currency: String
    /// `environment` de la source : jamais `off` pour un retrait réel.
    let environment: AffPayoutMode
    let status: AffWithdrawalStatus
    let requestedAt: String
    let updatedAt: String
    let paidAt: String?
    let failureCode: String?
    let failureMessage: String?
}

/// `AffiliateWallet` — solde, seuils, historique et paliers du compte affilié.
struct AffWallet {
    let mode: AffPayoutMode
    let requestedMode: AffPayoutMode
    let enabled: Bool
    let simulated: Bool
    let currency: String
    /// Code public de parrainage (`member-…`), seul identifiant montré à l'élève.
    let publicId: String
    let minWithdrawalMinor: Int
    let maxWithdrawalMinor: Int
    let configurationError: String?
    let registered: Bool
    let availableMinor: Int
    let reservedMinor: Int
    let paidMinor: Int
    let canWithdraw: Bool
    let connection: AffConnection
    let withdrawals: [AffWithdrawal]
    let compatibilityWarnings: [AffCompatibilityWarning]
    let updatedAt: String
}

/// `AffiliateOnboarding` — lien Stripe temporaire à ouvrir dans le navigateur
/// système, jamais dans une vue embarquée.
struct AffOnboarding: Equatable {
    let url: String
    let purpose: String
    let connection: AffConnection

    /// `stripeHttpsUrl` : seul un lien `https://…stripe.com` est accepté.
    static func isSecureStripeLink(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              components.scheme == "https",
              let host = components.host
        else { return false }
        return host == "stripe.com" || host.hasSuffix(".stripe.com")
    }
}

/// `AffiliateAmountLimits` — bornes de retrait, en centimes.
struct AffAmountLimits: Equatable {
    let minimum: Int
    let maximum: Int
}

/// `AffiliateConnectionCopy` — libellé, détail et action d'un état Stripe.
struct AffConnectionCopy: Equatable {
    /// Nom de symbole SF rendu par `Image(systemName:)`.
    let icon: String
    let title: String
    let detail: String
    let actionLabel: String?
}

/// `AffiliateMilestoneStatus` — état d'un palier de gains.
enum AffMilestoneStatus: String, Equatable {
    case reached
    case active
    case locked
}

/// `AffiliateMilestoneProgress` — un palier et sa progression.
struct AffMilestone: Identifiable, Equatable {
    let targetMinor: Int
    let progress: Double
    let status: AffMilestoneStatus

    var id: Int { targetMinor }
}

/// `AffiliateMilestoneSummary` — cumul de gains et paliers calculés.
struct AffMilestoneSummary: Equatable {
    let earnedMinor: Int
    let milestones: [AffMilestone]
    let nextTargetMinor: Int?
    let remainingMinor: Int
}

/// `FinancialAction` — l'action financière exclusive en cours.
enum AffFinancialAction: Equatable {
    case stripe
    case withdrawal
    case retry(String)
}

/// `attemptRef` — la dernière tentative de retrait, conservée pour rejouer la
/// même clé d'idempotence quand l'élève réessaie le même montant.
struct AffWithdrawalAttempt: Equatable {
    let amountMinor: Int
    let idempotencyKey: String
}
