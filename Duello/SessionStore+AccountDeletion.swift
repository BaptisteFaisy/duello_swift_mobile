//
//  SessionStore+AccountDeletion.swift
//  Duello
//
//  V1 (2026-09-26) — écart U08#2 : suppression définitive du compte.
//
//  Fichier source Expo porté (`App.tsx:2325-2371`, `deleteAccount`) : confirme
//  la suppression côté serveur (`deleteRemoteUserAccount` →
//  `DELETE /auth/account`, `serverSession.ts:231`), puis purge la session
//  locale — session, profil, trousseau — et ramène l'interface à l'accueil
//  (`isSignedIn == false` → `RootView`).
//
//  Découpé de `SessionStore.swift` pour tenir la règle des 10 fonctions par
//  fichier (ratchet Hermes).
//
//  Cible : iOS 16.
//
import Foundation

extension SessionStore {
    /// `deleteAccount` de `App.tsx:2325-2371`.
    ///
    /// Une fois le serveur confirmé, aucune panne locale ne doit laisser
    /// l'interface dans une fausse session connectée : la purge s'exécute sans
    /// condition dès que le serveur a répondu. Un refus du serveur (session
    /// expirée, compte déjà supprimé) est remonté tel quel à l'appelant.
    @MainActor
    func deleteAccount() async throws {
        guard let token else {
            throw DirectoryError(message: "Ta session Duello a expiré.")
        }
        try await DuelloAPI.deleteAccount(token: token)
        session = nil
        isSignedIn = false
        profile = UserProfile()
        Keychain.delete(service: Self.service, account: Self.account)
        UserDefaults.standard.removeObject(forKey: Self.profileKey)
    }
}
