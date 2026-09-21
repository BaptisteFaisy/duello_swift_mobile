import Foundation

// MARK: - Textes de l'espace affiliation
//
// Portage de `src/features/affiliate/affiliateEarningsViewModel.ts` :
// `affiliateConnectionCopy`, `affiliateWithdrawalHint`,
// `affiliateCompatibilityMessage`, `affiliateAmountError`,
// `affiliateErrorMessage`, plus `affiliateWithdrawalLabel` et
// `canRetryAffiliateWithdrawal` de `src/utils/affiliate.ts` et
// `AFFILIATE_PAYMENT_REWARD_LABEL` de `src/utils/affiliateProgram.ts`.
//
// Les libellés sont repris mot pour mot de la source.

/// Textes et règles de décision de l'espace affiliation.
enum AffiliateCopy {
    /// `AFFILIATE_PAYMENT_REWARD_LABEL` — récompense par paiement Premium validé.
    static let paymentRewardLabel = "3 €"

    /// `affiliateConnectionCopy` : état du compte Stripe Connect.
    static func connectionCopy(_ wallet: AffWallet) -> AffConnectionCopy {
        if wallet.simulated {
            return AffConnectionCopy(
                icon: "flask",
                title: "Retraits en simulation",
                detail: "Aucun argent réel ne sera envoyé dans ce mode.",
                actionLabel: nil
            )
        }
        switch wallet.connection.status {
        case .ready:
            return AffConnectionCopy(
                icon: "checkmark.circle",
                title: "Compte Stripe connecté",
                detail: "Connecte-toi à Stripe pour gérer ton compte bancaire et suivre tes versements.",
                actionLabel: "Se connecter à Stripe"
            )
        case .restricted:
            return AffConnectionCopy(
                icon: "exclamationmark.circle",
                title: "Informations Stripe à compléter",
                detail: "Stripe demande encore des informations avant le prochain retrait.",
                actionLabel: "Mettre à jour sur Stripe"
            )
        case .onboarding:
            return AffConnectionCopy(
                icon: "clock",
                title: "Configuration Stripe en cours",
                detail: "Reprends le formulaire sécurisé pour terminer la vérification.",
                actionLabel: "Continuer sur Stripe"
            )
        case .notStarted:
            return AffConnectionCopy(
                icon: "creditcard",
                title: "Compte Stripe à créer",
                detail: "Stripe recueille et vérifie tes coordonnées de versement.",
                actionLabel: "Créer mon compte Stripe"
            )
        }
    }

    /// `affiliateWithdrawalHint` : raison du blocage du retrait, `nil` quand
    /// tout est réuni.
    static func withdrawalHint(_ wallet: AffWallet) -> String? {
        if !wallet.registered { return "Un compte Duello inscrit est nécessaire." }
        if !wallet.enabled && !wallet.simulated { return "Les retraits ne sont pas encore ouverts." }
        if wallet.enabled && wallet.connection.status != .ready {
            return "Termine la vérification Stripe avant de demander un retrait."
        }
        if wallet.availableMinor < wallet.minWithdrawalMinor {
            return "Le minimum de retrait est de \(AffiliateFormatting.amount(wallet.minWithdrawalMinor))."
        }
        return nil
    }

    /// `affiliateCompatibilityMessage` : avertissement d'une donnée historique
    /// illisible, sans jamais masquer le solde.
    static func compatibilityMessage(_ wallet: AffWallet) -> String? {
        let connection = wallet.compatibilityWarnings.contains(.stripeConnection)
        let history = wallet.compatibilityWarnings.contains(.withdrawalHistory)
        if connection && history {
            return "Certaines informations Stripe et une partie de l’historique ne peuvent pas être affichées. Les retraits sont bloqués par sécurité."
        }
        if connection {
            return "Certaines informations Stripe ne peuvent pas être affichées. Les retraits sont bloqués par sécurité."
        }
        if history {
            return "Une ancienne ligne de l’historique ne peut pas être affichée. Ton solde reste consultable."
        }
        return nil
    }

    /// `affiliateAmountError` : borne de retrait ou solde insuffisant.
    static func amountError(
        input: String,
        amountMinor: Int?,
        wallet: AffWallet?,
        limits: AffAmountLimits?
    ) -> String? {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let amountMinor, let wallet, let limits
        else { return nil }
        if amountMinor < limits.minimum {
            return "Minimum : \(AffiliateFormatting.amount(limits.minimum))"
        }
        if amountMinor > limits.maximum {
            return "Maximum : \(AffiliateFormatting.amount(limits.maximum))"
        }
        return amountMinor > wallet.availableMinor ? "Solde insuffisant." : nil
    }

    /// `affiliateErrorMessage` : message porté par l'erreur, sinon repli.
    static func message(_ error: Error, fallback: String) -> String {
        guard let localized = (error as? LocalizedError)?.errorDescription else { return fallback }
        let trimmed = localized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// `affiliateWithdrawalLabel` : libellé français du statut d'un retrait.
    static func withdrawalLabel(_ status: AffWithdrawalStatus) -> String {
        switch status {
        case .paid: return "Versé"
        case .failed: return "Échec — solde recrédité"
        case .payoutFailed: return "Virement bancaire à relancer"
        case .uncertain: return "Vérification en cours"
        case .shadowed: return "Simulation"
        case .requested, .transferring, .transferCreated, .payoutCreating, .payoutPending:
            return "En cours"
        }
    }

    /// `canRetryAffiliateWithdrawal` : seuls ces deux statuts sont relançables.
    static func canRetry(_ status: AffWithdrawalStatus) -> Bool {
        status == .uncertain || status == .payoutFailed
    }
}
