//
//  RewRemoteAccountData+Session.swift
//  Duello
//
//  Port de src/storage/remoteAccountData.ts et src/utils/serverSession.ts (RN) —
//  session serveur d'un compte : le modèle consommé par le client, la couture
//  `RewRemoteAccountSessionProviding` et son implémentation par défaut
//  (`UserDefaults`, clé RN `@prepapp/server-session-v1`).
//
//  Découpage (24/09/2026) : section extraite de `RewRemoteAccountData.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Session serveur d'un compte

/// Session serveur telle que `remoteAccountData.ts` la consomme
/// (`ServerSession` de `src/utils/serverSession.ts`, réduit au jeton et à son
/// rattachement de compte).
struct RewRemoteAccountSession: Codable, Equatable {
    var token: String
    var expiresAt: String
    var publicId: String
    var email: String
    /// `localAccountId` : `null` pour une session non encore rattachée.
    var localAccountId: String?
}

/// Couture de session : fournit la session du compte demandé, ou `nil`.
protocol RewRemoteAccountSessionProviding {
    /// `serverSessionForAccount` : la session de CE compte, ou `nil`.
    func session(forAccountId accountId: String) -> RewRemoteAccountSession?
}

/// Implémentation par défaut : lit la clé RN `@prepapp/server-session-v1`,
/// valide le jeton comme `validSession` (préfixe `dus_`, non expiré) puis ne
/// renvoie la session que si `localAccountId` correspond **exactement** à
/// l'identifiant demandé.
struct RewUserDefaultsAccountSessionProvider: RewRemoteAccountSessionProviding {
    func session(forAccountId accountId: String) -> RewRemoteAccountSession? {
        let key = DevRegSessions.serverSessionStorageKey
        guard let raw = UserDefaults.standard.string(forKey: key),
              let data = raw.data(using: .utf8),
              let session = try? JSONDecoder().decode(RewRemoteAccountSession.self, from: data)
        else { return nil }
        guard session.token.hasPrefix("dus_"),
              let expires = ISO8601DateFormatter.date(fromISO: session.expiresAt),
              expires > Date()
        else { return nil }
        return session.localAccountId == accountId ? session : nil
    }
}
