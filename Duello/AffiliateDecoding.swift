import Foundation

// MARK: - Décodage des réponses d'affiliation
//
// Portage de `src/utils/affiliate.ts` : `parseAffiliateWalletResponse`,
// `parseAffiliateOnboardingResponse`, `parseAffiliateWithdrawalResponse` et
// `parseAffiliateWithdrawal`.
//
// Règle de la source conservée : une connexion Stripe ou une ligne d'historique
// illisible n'efface jamais le solde. Elle est remplacée par un état restrictif
// et signalée par un avertissement de compatibilité, et les retraits restent
// bloqués par sécurité.
//
// Assouplissement documenté : la source rejette la charge utile entière quand un
// texte facultatif est présent mais vide ou mal typé ; ici la valeur est ignorée
// (`AffRaw.text`). Aucun champ monétaire, de statut ou d'horodatage n'est
// concerné — tous restent stricts.

/// Réponse serveur non conforme au contrat du portefeuille affilié.
enum AffiliateDecodeError: Error {
    case unreadable
}

/// Champs obligatoires du portefeuille, validés d'un seul bloc.
struct AffWalletCore {
    let mode: AffPayoutMode
    let requestedMode: AffPayoutMode
    let enabled: Bool
    let simulated: Bool
    let publicId: String
    let minWithdrawalMinor: Int
    let maxWithdrawalMinor: Int
    let configurationError: String?
    let registered: Bool
    let availableMinor: Int
    let reservedMinor: Int
    let paidMinor: Int
    let canWithdraw: Bool
    let updatedAt: String
}

/// Décodage strict des réponses du programme d'affiliation.
enum AffiliateDecoding {
    /// `parseAffiliateWalletResponse` — enveloppe `{ "wallet": { … } }`.
    static func wallet(from data: Data) throws -> AffWallet {
        guard let root = AffRaw.record(try? JSONSerialization.jsonObject(with: data)),
              let body = AffRaw.record(root["wallet"])
        else { throw AffiliateDecodeError.unreadable }

        let core = try core(body)
        let parsedConnection = connection(body["connection"])
        let history = history(body["withdrawals"])

        var warnings: [AffCompatibilityWarning] = []
        if parsedConnection == nil { warnings.append(.stripeConnection) }
        if history.hasWarning { warnings.append(.withdrawalHistory) }

        return AffWallet(
            mode: core.mode,
            requestedMode: core.requestedMode,
            enabled: core.enabled,
            simulated: core.simulated,
            currency: "eur",
            publicId: core.publicId,
            minWithdrawalMinor: core.minWithdrawalMinor,
            maxWithdrawalMinor: core.maxWithdrawalMinor,
            configurationError: core.configurationError,
            registered: core.registered,
            availableMinor: core.availableMinor,
            reservedMinor: core.reservedMinor,
            paidMinor: core.paidMinor,
            canWithdraw: core.canWithdraw && parsedConnection != nil,
            connection: parsedConnection ?? .restricted,
            withdrawals: history.withdrawals,
            compatibilityWarnings: warnings,
            updatedAt: core.updatedAt
        )
    }

    /// Champs obligatoires du portefeuille : tout écart rend la réponse illisible.
    private static func core(_ body: [String: Any]) throws -> AffWalletCore {
        guard let mode = AffRaw.mode(body["mode"]),
              let requestedMode = AffRaw.mode(body["requestedMode"]),
              let enabled = body["enabled"] as? Bool,
              let simulated = body["simulated"] as? Bool,
              (body["currency"] as? String) == "eur",
              let publicId = body["publicId"] as? String, AffRaw.isPublicId(publicId),
              let minWithdrawalMinor = AffRaw.minor(body["minWithdrawalMinor"]),
              minWithdrawalMinor > 0,
              let maxWithdrawalMinor = AffRaw.minor(body["maxWithdrawalMinor"]),
              maxWithdrawalMinor >= minWithdrawalMinor,
              let registered = body["registered"] as? Bool,
              let availableMinor = AffRaw.minor(body["availableMinor"]),
              let reservedMinor = AffRaw.minor(body["reservedMinor"]),
              let paidMinor = AffRaw.minor(body["paidMinor"]),
              let canWithdraw = body["canWithdraw"] as? Bool,
              let updatedAt = AffRaw.iso(body["updatedAt"])
        else { throw AffiliateDecodeError.unreadable }

        return AffWalletCore(
            mode: mode,
            requestedMode: requestedMode,
            enabled: enabled,
            simulated: simulated,
            publicId: publicId,
            minWithdrawalMinor: minWithdrawalMinor,
            maxWithdrawalMinor: maxWithdrawalMinor,
            configurationError: AffRaw.text(body["configurationError"]),
            registered: registered,
            availableMinor: availableMinor,
            reservedMinor: reservedMinor,
            paidMinor: paidMinor,
            canWithdraw: canWithdraw,
            updatedAt: updatedAt
        )
    }

    /// Historique tolérant : les lignes illisibles sont écartées, puis signalées.
    private static func history(_ value: Any?) -> (withdrawals: [AffWithdrawal], hasWarning: Bool) {
        guard let raw = value as? [Any] else { return ([], true) }
        let withdrawals = raw.compactMap(withdrawal)
        return (withdrawals, withdrawals.count != raw.count)
    }

    /// `parseAffiliateConnection` — `nil` quand l'état Stripe n'est pas compris.
    static func connection(_ value: Any?) -> AffConnection? {
        guard let body = AffRaw.record(value),
              let rawStatus = body["status"] as? String,
              let status = AffConnectionStatus(rawValue: rawStatus),
              let detailsSubmitted = body["detailsSubmitted"] as? Bool,
              let payoutsEnabled = body["payoutsEnabled"] as? Bool,
              let transfersEnabled = body["transfersEnabled"] as? Bool,
              let requirementsDue = body["requirementsDue"] as? [String]
        else { return nil }

        // `updatedAt` absent donne `nil` ; présent, il doit porter une date. Une
        // valeur nulle est refusée, comme la source : une connexion Stripe que
        // le client ne comprend pas entièrement bloque les retraits.
        let rawUpdatedAt = body["updatedAt"]
        var updatedAt: String?
        if rawUpdatedAt != nil {
            guard let parsed = AffRaw.iso(rawUpdatedAt) else { return nil }
            updatedAt = parsed
        }

        return AffConnection(
            status: status,
            detailsSubmitted: detailsSubmitted,
            payoutsEnabled: payoutsEnabled,
            transfersEnabled: transfersEnabled,
            requirementsDue: requirementsDue,
            updatedAt: updatedAt
        )
    }

    /// `parseAffiliateWithdrawal` — `nil` quand la ligne n'est pas exploitable.
    static func withdrawal(_ value: Any?) -> AffWithdrawal? {
        guard let body = AffRaw.record(value),
              let id = body["id"] as? String, AffRaw.isWithdrawalId(id),
              let amountMinor = AffRaw.minor(body["amountMinor"]), amountMinor > 0,
              (body["currency"] as? String) == "eur",
              let environment = AffRaw.payoutEnvironment(body["environment"]),
              let rawStatus = body["status"] as? String,
              let status = AffWithdrawalStatus(rawValue: rawStatus),
              let requestedAt = AffRaw.iso(body["requestedAt"]),
              let updatedAt = AffRaw.iso(body["updatedAt"])
        else { return nil }

        // `paidAt` est obligatoire dans la source : absente, la ligne entière
        // est écartée ; nulle, le virement n'est pas encore versé.
        guard let rawPaidAt = body["paidAt"] else { return nil }
        var paidAt: String?
        if !(rawPaidAt is NSNull) {
            guard let parsed = AffRaw.iso(rawPaidAt) else { return nil }
            paidAt = parsed
        }

        return AffWithdrawal(
            id: id,
            amountMinor: amountMinor,
            currency: "eur",
            environment: environment,
            status: status,
            requestedAt: requestedAt,
            updatedAt: updatedAt,
            paidAt: paidAt,
            failureCode: AffRaw.text(body["failureCode"]),
            failureMessage: AffRaw.text(body["failureMessage"])
        )
    }

    /// `parseAffiliateOnboardingResponse` — enveloppe `{ "onboarding": { … } }`.
    static func onboarding(from data: Data) throws -> AffOnboarding {
        guard let root = AffRaw.record(try? JSONSerialization.jsonObject(with: data)),
              let body = AffRaw.record(root["onboarding"]),
              let url = body["url"] as? String, AffOnboarding.isSecureStripeLink(url),
              let purpose = body["purpose"] as? String,
              purpose == "onboarding" || purpose == "dashboard",
              let connection = connection(body["connection"])
        else { throw AffiliateDecodeError.unreadable }
        return AffOnboarding(url: url, purpose: purpose, connection: connection)
    }

    /// `parseAffiliateWithdrawalResponse` — `{ "idempotent": …, "withdrawal": … }`.
    static func withdrawalResult(from data: Data) throws -> AffWithdrawal {
        guard let root = AffRaw.record(try? JSONSerialization.jsonObject(with: data)),
              root["idempotent"] is Bool,
              let withdrawal = withdrawal(root["withdrawal"])
        else { throw AffiliateDecodeError.unreadable }
        return withdrawal
    }

    /// Réponse de `POST /affiliate/withdrawals/{id}/retry` : `{ "withdrawal": … }`.
    static func retryWithdrawal(from data: Data) throws -> AffWithdrawal {
        guard let root = AffRaw.record(try? JSONSerialization.jsonObject(with: data)),
              let withdrawal = withdrawal(root["withdrawal"])
        else { throw AffiliateDecodeError.unreadable }
        return withdrawal
    }
}
