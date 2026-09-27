import Foundation

// MARK: - État d'abonnement du portage

/// Point d'entrée de la facturation native.
///
/// V1 (26/09/2026, écart 19#1) : `isAvailable` n'est plus figé à `false`. La
/// disponibilité vient de la couture `PremStoreKitPurchases` — le bouton
/// « Accéder à Premium » est câblé à `PremPurchaseFlow` et répond à l'élève. Un
/// achat impossible refuse **clairement** par alerte, jamais en silence.
///
/// ⚠️ **RevenueCat n'est pas embarqué** (dépendance externe interdite) : le
/// catalogue de produits StoreKit est vide, donc `beginPurchase` refuse pour
/// l'instant. Le jour où les identifiants de produits sont renseignés
/// (`PremStoreKitPurchases.productIds`), l'achat part réellement, sans toucher
/// au reste du flux.
///
/// absent : la restauration d'abonnement et le centre de gestion
/// (`presentCustomerCenter`, `hasActiveEntitlement`, `logInPurchases`,
/// `presentPaywallIfNeeded` de `purchaseService.ts`) — sans RevenueCat, il n'y a
/// rien à restaurer ni à gérer.
enum PremPurchaseService {
    /// `isPurchaseAvailable()` : la facturation native est-elle opérationnelle ?
    static var isAvailable: Bool { PremStoreKitPurchases().isAvailable }

    /// `PAYWALL_UNAVAILABLE_MESSAGE` : la fenêtre d'abonnement n'est pas
    /// activée sur cette application (message unique, porté par le flux).
    static let paywallUnavailableMessage = PremPurchaseFlow.paywallUnavailableMessage
}

// MARK: - Quota de corrections

/// Instantané du quota de corrections tel que le serveur le compte
/// (`AuthoritativeCorrectionQuota` de `src/utils/correctionQuota.ts`), réduit
/// aux trois champs que la fenêtre de paiement affiche.
struct PremQuotaSnapshot: Equatable {
    /// `FREE_CORRECTION_ALLOWANCE` : les dix corrections du premier compte.
    static let allowance = 10

    /// Abonnement actif : plus aucune limite.
    var subscribed: Bool
    /// Les dix corrections initiales appartiennent au premier compte de l'appareil.
    var freeTrialEligible: Bool
    var remainingFree: Int

    /// `remainingLabel` de `PaywallContent.tsx`.
    var remainingLabel: String {
        freeTrialEligible
            ? "\(remainingFree)/\(Self.allowance) défis gratuits"
            : "Essai gratuit déjà utilisé sur cet appareil"
    }
}

/// Relit le quota durable (`fetchRemoteCorrectionQuota`) :
/// `GET /correction-quota?userId=member-…`.
///
/// absent : le reste du moteur de quota de `correctionQuota.ts` —
/// `formatCorrectionWait`, `evaluateCorrectionAccess`, `consumeCorrection`,
/// `nextFreeCorrectionAt` et la persistance locale (`parseCorrectionQuota`) :
/// la fenêtre de paiement n'affiche qu'une ligne de quota, elle ne consomme ni
/// ne réserve aucune correction — cela appartient aux écrans d'exercice.
/// absent : `lastConsumedAt`, lu par la source pour juger la forme de la
/// réponse ; il ne change aucun des trois champs affichés ici.
enum PremQuotaService {
    /// Enveloppe de la réponse : `{ "quota": { … } }`.
    struct Envelope: Decodable {
        let quota: Payload?
    }

    /// Les champs lus par `parseAuthoritativeCorrectionQuota`. Tous optionnels :
    /// une réponse partielle est traitée comme douteuse, jamais comme un accord.
    struct Payload: Decodable {
        let used: Int?
        let allowed: Bool?
        let reason: String?
        let subscribed: Bool?
        let freeTrialEligible: Bool?
        let nextFreeAt: Double?
    }

    /// Charge l'instantané, ou `nil` si la réponse n'est pas exploitable : la
    /// source ferme l'accès sur une réponse douteuse plutôt que d'inventer un
    /// état — ici, la fenêtre n'affiche simplement pas de ligne de quota.
    static func load(token: String?, userId: String) async throws -> PremQuotaSnapshot? {
        let data = try await DuelloAPI.request(
            "correction-quota",
            token: token,
            query: [URLQueryItem(name: "userId", value: userId)]
        )
        guard let envelope = try? DuelloAPI.decoder.decode(Envelope.self, from: data),
              let payload = envelope.quota,
              let used = payload.used, used >= 0,
              let allowed = payload.allowed,
              let reason = payload.reason,
              let subscribed = payload.subscribed else {
            return nil
        }
        let freeTrialEligible = payload.freeTrialEligible ?? true
        let remainingFree = freeTrialEligible
            ? max(0, PremQuotaSnapshot.allowance - used)
            : 0
        guard isCoherent(
            allowed: allowed,
            reason: reason,
            subscribed: subscribed,
            freeTrialEligible: freeTrialEligible,
            remainingFree: remainingFree,
            nextFreeAt: payload.nextFreeAt
        ) else {
            return nil
        }
        return PremQuotaSnapshot(
            subscribed: subscribed,
            freeTrialEligible: freeTrialEligible,
            remainingFree: remainingFree
        )
    }

    /// Les couples `allowed` / `reason` que la source accepte, **avec leurs
    /// conditions croisées** : un abonnement annoncé sans `subscribed`, une
    /// allocation d'essai hors essai éligible ou déjà épuisée, une barrière
    /// sans échéance valide — autant de réponses douteuses, donc refusées.
    private static func isCoherent(
        allowed: Bool,
        reason: String,
        subscribed: Bool,
        freeTrialEligible: Bool,
        remainingFree: Int,
        nextFreeAt: Double?
    ) -> Bool {
        if allowed, reason == "subscription" {
            return subscribed
        }
        if allowed, reason == "free-allowance" {
            return !subscribed && freeTrialEligible && remainingFree > 0
        }
        if allowed, reason == "free-refill" {
            return !subscribed
        }
        if !allowed, reason == "paywall" {
            return !subscribed && (nextFreeAt ?? 0) > 0
        }
        return false
    }
}
