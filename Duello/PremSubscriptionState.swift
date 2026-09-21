import Foundation

// MARK: - État d'abonnement du portage

/// Achat Premium — simulé, sans aucune dépendance de facturation.
///
/// ⚠️ **Aucun paiement réel.** La cible n'embarque ni StoreKit ni RevenueCat
/// (dépendance externe interdite par le brief de portage). `isAvailable` reste
/// donc `false` : le bouton « Accéder à Premium » garde son état désactivé
/// d'origine et son libellé d'accessibilité « …, bientôt disponible », et la
/// fenêtre affiche la mention d'indisponibilité. Le message ci-dessous est
/// celui de `src/hooks/usePremiumPurchase.ts`, repris mot pour mot.
///
/// absent : `PURCHASE_FAILURE_MESSAGE` (« Le paiement n’a pas abouti. Vérifie
/// ta connexion puis réessaie — aucun montant n’a été prélevé. ») — sans flux
/// d'achat, aucun échec de paiement n'est possible ici.
/// absent : la restauration d'abonnement et le centre de gestion
/// (`presentCustomerCenter`, `hasActiveEntitlement`, `logInPurchases`,
/// `presentPaywallIfNeeded` de `purchaseService.ts`) — sans facturation
/// native, il n'y a rien à restaurer ni à gérer.
/// absent : les alertes du flux d'achat de `usePremiumPurchase.ts` —
/// « Connexion requise », « Connecte-toi à ton compte avant de t’abonner. »,
/// « Achat indisponible », « Paiement impossible », « Bienvenue en Premium »,
/// « Abonnement restauré » : aucun flux d'achat ne les déclenche.
enum PremPurchaseService {
    /// `isPurchaseAvailable()` : la facturation native est-elle opérationnelle ?
    /// Jamais dans ce portage — voir l'avertissement ci-dessus.
    static let isAvailable = false

    /// `PAYWALL_UNAVAILABLE_MESSAGE` : la fenêtre d'abonnement n'est pas
    /// activée sur cette application.
    static let paywallUnavailableMessage =
        "La fenêtre d’abonnement n’est pas encore activée sur cette application."
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
