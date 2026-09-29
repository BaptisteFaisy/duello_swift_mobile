//
//  ChalCorrectionQuota.swift
//  Duello
//
//  Quota de corrections du compte connecté.
//
//  Fichier source Expo porté : `src/hooks/useCorrectionQuota.ts`
//  (`useCorrectionQuota`). Les règles pures du quota (évaluation de l'accès,
//  consommation, délai lisible) vivent dans `utils/correctionQuota.ts` (lot
//  TR-05) et les points d'entrée réseau dans `ChalAPI.swift`
//  (`fetchRemoteCorrectionQuota` / `reserveRemoteCorrection`) ; ce fichier ne
//  porte que le **moteur** : identité, garde de génération, relance et
//  réservation.
//
//  Une correction est l'unité facturée du produit : un défi joué, un exercice
//  soumis en entier ou une question isolée en consomment exactement une. Le
//  hook ne contient aucun moyen de paiement — l'abonnement sera acheté par les
//  interfaces natives Apple, puis seulement synchronisé ici.
//
//  Le backend (lecture du quota, réservation, abonnement stocké) est injecté :
//  le moteur reste vérifiable hors réseau et sans stockage, et se raccorde aux
//  appels réels (`fetchRemoteCorrectionQuota` / `reserveRemoteCorrection`,
//  `PremCodeSubscription`) à l'écran hôte.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Combine
import Foundation

/// Valeurs et types du quota de corrections (`utils/correctionQuota.ts`).
enum ChalCorrectionQuota {

    /// `QUOTA_UNAVAILABLE_MESSAGE` : message unique quand le serveur ne peut pas
    /// vérifier le quota.
    static let unavailableMessage = "Le serveur ne peut pas vérifier ton quota de défis "
        + "pour le moment. Vérifie ta connexion, puis réessaie."

    /// `CorrectionQuotaState` : compteur serveur (consommées + dernière date).
    struct State: Equatable {
        var schemaVersion: Int
        var used: Int
        var lastConsumedAt: Double?
    }

    /// `CorrectionAvailability` : accès accordé, paywall, ou serveur indisponible.
    enum Access: Equatable {
        /// Abonnement actif : aucune limite.
        case subscription
        /// Une des dix corrections offertes au premier compte de l'appareil.
        case freeAllowance(remaining: Int)
        /// Correction offerte débloquée par les 48 heures écoulées.
        case freeRefill
        /// Plus rien à consommer : le paywall doit s'afficher.
        case paywall(nextFreeAt: Double, waitMs: Double)
        /// État fermé tant que l'autorité serveur n'a pas répondu.
        case unavailable(message: String)

        /// `allowed` de la source.
        var allowed: Bool {
            switch self {
            case .subscription, .freeAllowance, .freeRefill: return true
            case .paywall, .unavailable: return false
            }
        }

        /// `reason` de la source.
        var reason: String {
            switch self {
            case .subscription: return "subscription"
            case .freeAllowance: return "free-allowance"
            case .freeRefill: return "free-refill"
            case .paywall: return "paywall"
            case .unavailable: return "unavailable"
            }
        }
    }

    /// `AuthoritativeCorrectionQuota` : instantané serveur du quota.
    struct Remote: Equatable {
        var quota: State
        var subscribed: Bool
        var freeTrialEligible: Bool
        var access: Access
        var remainingFree: Int
        var nextFreeAt: Double?
    }

    /// Résultat de `reserveRemoteCorrection` : l'accès et le quota à jour.
    struct ReserveResult: Equatable {
        var access: Access
        var quota: State
    }

    /// `emptyCorrectionQuota` : état technique vide (n'accorde aucun accès).
    static func emptyQuota() -> State {
        State(schemaVersion: 1, used: 0, lastConsumedAt: nil)
    }

    /// `unavailable(message:)` : accès fermé par défaut.
    static func unavailable(message: String = unavailableMessage) -> Access {
        .unavailable(message: message)
    }
}

/// Moteur du quota de corrections (`useCorrectionQuota`).
@MainActor
final class ChalCorrectionQuotaController: ObservableObject {

    /// Dépendances du moteur : lecture du quota, réservation, abonnement stocké.
    struct Backend {
        var fetch: (_ email: String, _ accountId: String) async throws -> ChalCorrectionQuota.Remote
        var reserve: (
            _ email: String, _ operationKey: String, _ accountId: String
        ) async throws -> ChalCorrectionQuota.ReserveResult
        /// Relit la valeur brute de `ACCOUNT_STORAGE_KEYS.subscription`.
        var loadStoredSubscription: (_ accountId: String) -> String?
    }

    @Published private(set) var ready = false
    @Published private(set) var error: String?
    @Published private(set) var quota = ChalCorrectionQuota.emptyQuota()
    @Published private(set) var subscription = PremCodeSubscription.State.empty
    @Published private(set) var subscribed = false
    @Published private(set) var access = ChalCorrectionQuota.unavailable()
    @Published private(set) var freeTrialEligible = true
    @Published private(set) var remainingFree = 0
    @Published private(set) var nextFreeAt: Double?

    private let backend: Backend
    private var accountId: String
    private var email: String
    /// Identité `compte:adresse` : une réponse d'un autre compte est ignorée.
    private var identity: String
    private var remote: ChalCorrectionQuota.Remote?
    /// Une lecture partie pendant une réservation ne doit pas réafficher le
    /// compteur d'avant une fois la réservation terminée.
    private var generation = 0

    init(accountId: String, email: String, backend: Backend) {
        self.backend = backend
        self.accountId = accountId
        self.email = email
        self.identity = "\(accountId):\(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        refreshStoredSubscription()
    }

    /// Change de compte affiché : remet l'état distant à zéro puis relit le quota.
    func updateIdentity(accountId: String, email: String) {
        self.accountId = accountId
        self.email = email
        self.identity = "\(accountId):\(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        remote = nil
        ready = false
        error = nil
        apply(remote: nil)
        refreshStoredSubscription()
        Task { _ = await reload() }
    }

    /// `reload` : relit le quota sans retenir de correction.
    @discardableResult
    func reload() async -> ChalCorrectionQuota.Access {
        let requestedIdentity = identity
        let requestedGeneration = generation
        do {
            let value = try await backend.fetch(email, accountId)
            guard identity == requestedIdentity, generation == requestedGeneration else {
                return ChalCorrectionQuota.unavailable()
            }
            remote = value
            ready = true
            error = nil
            apply(remote: value)
            return value.access
        } catch {
            let message = failureMessage(error)
            if identity == requestedIdentity, generation == requestedGeneration {
                remote = nil
                ready = true
                self.error = message
                apply(remote: nil)
            }
            return ChalCorrectionQuota.unavailable(message: message)
        }
    }

    /// `reserve` : retient une correction pour `operationKey`. Répéter la même
    /// clé ne recompte rien côté serveur.
    @discardableResult
    func reserve(operationKey: String) async -> ChalCorrectionQuota.Access {
        let requestedIdentity = identity
        generation += 1
        let requestedGeneration = generation
        do {
            let result = try await backend.reserve(email, operationKey, accountId)
            guard identity == requestedIdentity, generation == requestedGeneration else {
                return ChalCorrectionQuota.unavailable()
            }
            generation += 1
            let value = ChalCorrectionQuota.Remote(
                quota: result.quota,
                subscribed: remote?.subscribed ?? subscribed,
                freeTrialEligible: remote?.freeTrialEligible ?? freeTrialEligible,
                access: result.access,
                remainingFree: remote?.remainingFree ?? remainingFree,
                nextFreeAt: remote?.nextFreeAt ?? nextFreeAt
            )
            remote = value
            ready = true
            error = nil
            apply(remote: value)
            return result.access
        } catch {
            let message = failureMessage(error)
            if identity == requestedIdentity, generation == requestedGeneration {
                generation += 1
                remote = nil
                ready = true
                self.error = message
                apply(remote: nil)
            }
            return ChalCorrectionQuota.unavailable(message: message)
        }
    }

    /// Relit l'abonnement stocké (`ACCOUNT_STORAGE_KEYS.subscription`).
    func refreshStoredSubscription() {
        let stored = backend.loadStoredSubscription(accountId)
        subscription = PremCodeSubscription.parse(stored)
        apply(remote: remote)
    }

    /// Applique l'instantané courant aux champs exposés : sans réponse serveur,
    /// l'accès retombe sur le seul abonnement stocké.
    private func apply(remote value: ChalCorrectionQuota.Remote?) {
        quota = value?.quota ?? ChalCorrectionQuota.emptyQuota()
        freeTrialEligible = value?.freeTrialEligible ?? true
        remainingFree = value?.remainingFree ?? 0
        nextFreeAt = value?.nextFreeAt
        let now = Date().timeIntervalSince1970 * 1000
        subscribed = value?.subscribed ?? PremCodeSubscription.isActive(subscription, now: now)
        access = value?.access
            ?? ChalCorrectionQuota.unavailable(message: error ?? ChalCorrectionQuota.unavailableMessage)
    }

    /// `failureMessage` : message de l'erreur, sinon le message générique.
    private func failureMessage(_ error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? ChalCorrectionQuota.unavailableMessage : message
    }
}
