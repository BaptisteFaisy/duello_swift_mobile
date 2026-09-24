//
//  SessionStore+RemoteAccountSession.swift
//  Duello
//
//  Port de src/utils/serverSession.ts (RN) — rattachement de la session
//  installée à un compte local.
//
//  `RewRemoteAccountData` lit `localAccountId` dans l'objet persisté sous
//  `@prepapp/server-session-v1` avant tout appel `/account-data` ; sans cette
//  écriture, la session n'appartient à aucun compte et aucune donnée ne part
//  vers l'API.
//
//  Découpé de `SessionStore.swift` pour la limite Hermes (10 fonctions/fichier).
//
//  Cible : iOS 16, SwiftUI + Combine + Foundation ; aucune dépendance externe.
//
import Foundation

extension SessionStore {
    /// Aligne la session de compte distante (`@prepapp/server-session-v1`,
    /// `serverSession.ts`) sur la session installée : `RewRemoteAccountData` y
    /// lit le rattachement de compte (`localAccountId`) avant tout appel
    /// `/account-data`. Sans cette écriture, la session n'appartient à aucun
    /// compte et aucune donnée ne part vers l'API.
    func persistRemoteAccountSession(_ session: ServerSession) {
        let stored = RewRemoteAccountSession(
            token: session.token,
            expiresAt: session.expiresAt,
            publicId: session.publicId,
            email: session.email,
            localAccountId: Self.localAccountId(for: session.email)
        )
        guard let data = try? JSONEncoder().encode(stored),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: DevRegSessions.serverSessionStorageKey)
    }

    /// Identifiant du compte local propriétaire de la session (`localAccountId`
    /// de `serverSession.ts`) : la valeur persistée du registre prime (elle
    /// survit à un changement d'adresse), sinon l'identifiant dérivé de
    /// l'adresse — celui que `AcctLocalRegistry` attribue à un compte qui n'en
    /// porte pas encore.
    static func localAccountId(for email: String) -> String {
        let accounts = AcctLocalRegistry.loadAccounts()
        if let account = AcctLocalRegistry.findAccountByEmail(accounts, email: email) {
            return account.id
        }
        return RewStorageScope.userStorageId(email)
    }
}
