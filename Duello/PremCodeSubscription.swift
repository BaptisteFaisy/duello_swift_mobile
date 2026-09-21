//
//  PremCodeSubscription.swift
//  Duello
//
//  État local d’un abonnement Duello vérifié par le serveur.
//
//  Fichiers source Expo portés :
//    - `src/utils/subscription.ts` (état, sérialisation, activité, jours
//      restants, réconciliation, ouverture de période) ;
//    - `src/utils/subscriptionSync.ts` (`isPremiumActivation`).
//
//  L’application n’ouvre jamais un accès de sa propre autorité : elle ne fait
//  que recopier ce que le serveur a enregistré.
//
//  Cible : iOS 16.
//
import Foundation

/// État d’abonnement et réconciliation avec le droit serveur.
enum PremCodeSubscription {
    /// Une journée, en millisecondes (les échéances serveur sont en ms).
    static let dayMilliseconds: Double = 24 * 60 * 60 * 1000

    /// `SUBSCRIPTION_PERIOD_MS` : une semaine.
    static let periodMilliseconds: Double = 7 * dayMilliseconds

    /// `SubscriptionStatus`.
    enum Status: String {
        case none
        case active
        case cancelled
    }

    /// `SubscriptionState`.
    struct State: Equatable {
        var schemaVersion: Int = 1
        var status: Status = .none
        /// Début de l’accès connu.
        var startedAt: Double? = nil
        /// Fin de la semaine payée : la résiliation coupe le renouvellement,
        /// pas l’accès déjà réglé.
        var renewsAt: Double? = nil
        /// Première période payée connue du serveur.
        var firstPaidAt: Double? = nil

        /// `emptySubscription`.
        static let empty = State()
    }

    /// `parseSubscription` : tolérant, tout champ illisible retombe sur vide.
    static func parse(_ raw: String?) -> State {
        guard let raw, let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty
        }
        let status = Status(rawValue: (object["status"] as? String) ?? "") ?? .none
        return State(
            status: status,
            startedAt: timestampFromJSON(object["startedAt"]),
            renewsAt: timestampFromJSON(object["renewsAt"]),
            firstPaidAt: timestampFromJSON(object["firstPaidAt"]))
    }

    /// `serializeSubscription`.
    static func serialize(_ state: State) -> String {
        var object: [String: Any] = ["schemaVersion": 1, "status": state.status.rawValue]
        if let startedAt = state.startedAt { object["startedAt"] = startedAt }
        if let renewsAt = state.renewsAt { object["renewsAt"] = renewsAt }
        if let firstPaidAt = state.firstPaidAt { object["firstPaidAt"] = firstPaidAt }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    /// `isSubscriptionActive` : ouvert tant que la semaine réglée n’est pas
    /// écoulée, reconduite ou déjà résiliée.
    static func isActive(_ state: State, now: Double) -> Bool {
        if state.status == .none { return false }
        guard let renewsAt = state.renewsAt else { return state.status == .active }
        return renewsAt > now
    }

    /// `remainingSubscriptionDays` : journées d’accès encore entamées.
    static func remainingDays(_ state: State, now: Double) -> Int? {
        guard isActive(state, now: now), let renewsAt = state.renewsAt else { return nil }
        return Int(ceil((renewsAt - now) / dayMilliseconds))
    }

    /// `reconcileSubscription` : aligne l’accès du téléphone sur le droit
    /// serveur. Seule une échéance plus lointaine vaut nouveau paiement ; une
    /// résiliation garde son statut ; un serveur sans droit ne referme pas une
    /// semaine ouverte, sauf cutoff de reset explicite.
    static func reconcile(
        _ state: State,
        remote: PremCodeAPI.RemoteSubscription,
        now: Double
    ) -> State {
        let resetAt = timestamp(remote.resetAt)
        let resetApplies = remote.authoritative && resetAt != nil
            && (state.startedAt == nil || (state.startedAt ?? 0) < (resetAt ?? 0))
        if resetApplies {
            if !remote.paid || remote.renewsAt == nil || (remote.renewsAt ?? 0) <= now {
                if state.status == .none && state.startedAt == nil
                    && state.renewsAt == nil && state.firstPaidAt == nil {
                    return state
                }
                return .empty
            }
            return State(
                status: .active,
                startedAt: timestamp(remote.trialStartsAt) ?? resetAt,
                renewsAt: (remote.renewsAt ?? 0).rounded(.down),
                firstPaidAt: timestamp(remote.firstPaidAt))
        }
        guard remote.paid, let renewsAt = remote.renewsAt, renewsAt > now else { return state }
        if let current = state.renewsAt, renewsAt <= current {
            if let firstPaid = remote.firstPaidAt, state.firstPaidAt != firstPaid.rounded(.down) {
                var next = state
                next.firstPaidAt = firstPaid.rounded(.down)
                return next
            }
            return state
        }
        return activate(state, now: now, until: renewsAt, firstPaidAt: remote.firstPaidAt)
    }

    /// `isPremiumActivation` : un accès qui s’ouvre ou une semaine qui se
    /// prolonge, portés par une première période payée datée par le serveur,
    /// valent célébration. Une lecture sans changement, une résiliation ou un
    /// accès offert sans paiement connu ne déclenchent jamais l’animation.
    static func isPremiumActivation(previous: State, next: State) -> Bool {
        guard next.firstPaidAt != nil, let nextRenews = next.renewsAt else { return false }
        guard previous.firstPaidAt != nil, let previousRenews = previous.renewsAt else { return true }
        return nextRenews > previousRenews
    }

    /// `activateSubscription` : ouvre une période annoncée par le serveur.
    private static func activate(
        _ state: State,
        now: Double,
        until: Double?,
        firstPaidAt: Double?
    ) -> State {
        let first: Double? = firstPaidAt.map { $0.rounded(.down) } ?? state.firstPaidAt
        let renews = until.map { $0 > 0 ? $0.rounded(.down) : now + periodMilliseconds }
            ?? (now + periodMilliseconds)
        return State(
            status: .active,
            startedAt: state.startedAt ?? now,
            renewsAt: renews,
            firstPaidAt: first ?? now)
    }

    /// `timestamp` : nombre fini strictement positif, ramené à l’entier.
    /// Variante `Any?` pour les champs issus de `JSONSerialization`.
    private static func timestampFromJSON(_ value: Any?) -> Double? {
        guard let number = value as? Double, number.isFinite, number > 0 else { return nil }
        return number.rounded(.down)
    }

    /// Variante typée pour les champs déjà numériques de `RemoteSubscription`.
    private static func timestamp(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value.rounded(.down)
    }
}
