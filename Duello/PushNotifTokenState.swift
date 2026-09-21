import Foundation

// Journal des jetons de notification poussée.
//
// Source Expo portée : `src/utils/pushNotificationTokenState.ts` (version 2 du
// journal : jeton courant + jetons suivis).
//
// Pur et portable : la persistance passe par `UserDefaults`, pas par le
// trousseau — un jeton d'appareil n'est pas un secret de session. La lecture
// tolère le format historique (un jeton nu stocké sans enveloppe).

// MARK: - Modèle

/// État journalisé des jetons (`PushNotificationTokenState`).
struct PushNotifTokenState: Equatable {
    var currentToken: String?
    var trackedTokens: [String]

    /// Journal vide, état de repli quand rien n'est lisible.
    static let empty = PushNotifTokenState(currentToken: nil, trackedTokens: [])
}

// MARK: - Journal

/// Normalisation et (dé)sérialisation du journal, version 2.
enum PushNotifTokenJournal {

    /// Version du format persisté, alignée sur `PUSH_TOKEN_JOURNAL_VERSION`.
    static let version = 2

    /// Un jeton exploitable : jeton APNs hexadécimal (≥ 32 caractères) ou jeton
    /// Expo historique (`ExpoPushToken[...]` / `ExponentPushToken[...]`).
    static func isValidToken(_ value: String?) -> Bool {
        guard let value, !value.isEmpty else { return false }
        if value.hasPrefix("ExpoPushToken[") || value.hasPrefix("ExponentPushToken[") {
            return value.hasSuffix("]")
        }
        return value.count >= 32 && value.allSatisfy { $0.isHexDigit }
    }

    /// Jetons uniques et valides, dans l'ordre d'apparition.
    static func uniqueTokens(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where isValidToken(value) {
            if seen.insert(value).inserted { result.append(value) }
        }
        return result
    }

    /// Lit un état persisté, avec repli sur le format historique (jeton nu).
    static func parse(_ stored: String?) -> PushNotifTokenState {
        guard let stored, !stored.isEmpty else { return .empty }
        if isValidToken(stored) {
            return PushNotifTokenState(currentToken: stored, trackedTokens: [stored])
        }
        guard
            let data = stored.data(using: .utf8),
            let persisted = try? JSONDecoder().decode(Persisted.self, from: data),
            persisted.version == version
        else {
            return .empty
        }
        let current = isValidToken(persisted.currentToken) ? persisted.currentToken : nil
        var tracked = uniqueTokens(persisted.trackedTokens)
        if let current, !tracked.contains(current) { tracked.append(current) }
        return PushNotifTokenState(currentToken: current, trackedTokens: tracked)
    }

    /// Sérialise un état, ou `nil` s'il n'y a rien à retenir.
    static func encode(_ state: PushNotifTokenState) -> String? {
        let persisted = Persisted(
            version: version,
            currentToken: state.currentToken,
            trackedTokens: uniqueTokens(state.trackedTokens)
        )
        guard let data = try? JSONEncoder().encode(persisted) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Forme persistée du journal (`PersistedPushNotificationTokenState`).
    private struct Persisted: Codable {
        var version: Int
        var currentToken: String?
        var trackedTokens: [String]
    }
}

// MARK: - Store

/// Store du journal des jetons, persisté dans `UserDefaults`.
final class PushNotifTokenStore {

    /// Clé de stockage, alignée sur le préfixe `com.duello.ios.*` du projet.
    private static let storageKey = "com.duello.ios.push-token"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Journal courant, relu à chaque accès.
    var state: PushNotifTokenState {
        PushNotifTokenJournal.parse(defaults.string(forKey: Self.storageKey))
    }

    /// Ajoute un jeton au journal **avant** tout usage distant : une rotation
    /// interrompue connaît ainsi l'ancien et le nouveau jeton.
    @discardableResult
    func stage(token: String) -> PushNotifTokenState {
        let previous = state
        var tracked = previous.trackedTokens
        if !tracked.contains(token) { tracked.append(token) }
        let next = PushNotifTokenState(currentToken: token, trackedTokens: tracked)
        persist(next)
        return next
    }

    /// Confirme le remplacement : seul le jeton courant reste suivi.
    func confirm(token: String) {
        persist(PushNotifTokenState(currentToken: token, trackedTokens: [token]))
    }

    /// Oublie tous les jetons (déconnexion réussie).
    func forget() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Écrit le journal s'il a changé, pour éviter les écritures inutiles.
    private func persist(_ state: PushNotifTokenState) {
        guard let encoded = PushNotifTokenJournal.encode(state) else { return }
        if defaults.string(forKey: Self.storageKey) != encoded {
            defaults.set(encoded, forKey: Self.storageKey)
        }
    }
}
