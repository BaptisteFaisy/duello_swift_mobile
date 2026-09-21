import Foundation

// Port de `src/utils/serverSessionRegistry.ts` (registre mono-écrivain du cache
// de session) et `src/utils/serverSessionToken.ts` (lecture du seul jeton
// nécessaire aux appels IA). Clé de stockage et validation du jeton sont
// reprises de la source.

/// Session persistée réduite au jeton et à son expiration
/// (`{ token, expiresAt }` de `serverSessionToken.ts`).
struct DevRegSessionTokenPayload: Decodable {
    var token: String?
    var expiresAt: String?
}

/// Session minimale manipulée par le registre (`TokenizedServerSession`).
protocol DevRegTokenized: Codable {
    var token: String { get }
}

/// Stockage clé/valeur du registre (`ServerSessionRegistryStorage`).
protocol DevRegSessionStoring {
    func getItem(_ key: String) -> String?
    func setItem(_ key: String, _ value: String)
    func removeItem(_ key: String)
}

/// Stockage `UserDefaults`, équivalent iOS d'`AsyncStorage`.
struct DevRegUserDefaultsStorage: DevRegSessionStoring {
    func getItem(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    func setItem(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    func removeItem(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// La session serveur existante (`SessionStore.swift`) satisfait le contrat.
extension ServerSession: DevRegTokenized {}

/// Session serveur et registre mono-écrivain.
enum DevRegSessions {
    /// `SERVER_SESSION_STORAGE_KEY` de la source.
    static let serverSessionStorageKey = "@prepapp/server-session-v1"

    /// Lit uniquement le jeton nécessaire aux appels IA
    /// (`currentServerSessionToken`) : renvoie `""` si absent, non préfixé
    /// `dus_`, ou expiré.
    static func currentServerSessionToken(
        in storage: DevRegSessionStoring = DevRegUserDefaultsStorage()
    ) -> String {
        guard let raw = storage.getItem(serverSessionStorageKey),
              let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(DevRegSessionTokenPayload.self, from: data),
              let token = payload.token, token.hasPrefix("dus_"),
              let expiresAt = payload.expiresAt,
              let expires = ISO8601DateFormatter.date(fromISO: expiresAt),
              expires > Date()
        else { return "" }
        return token
    }

    /// Fabrique un registre mono-écrivain (`createServerSessionRegistry`).
    static func makeRegistry<Session: DevRegTokenized>(
        storage: DevRegSessionStoring,
        storageKey: String,
        parse: @escaping (String?) -> Session?
    ) -> DevRegSessionRegistry<Session> {
        DevRegSessionRegistry(storage: storage, storageKey: storageKey, parse: parse)
    }

    /// Registre adossé à `UserDefaults` et à la clé de session serveur.
    static func userDefaultsRegistry<Session: DevRegTokenized>(
        parse: @escaping (String?) -> Session?
    ) -> DevRegSessionRegistry<Session> {
        makeRegistry(
            storage: DevRegUserDefaultsStorage(),
            storageKey: serverSessionStorageKey,
            parse: parse
        )
    }
}
