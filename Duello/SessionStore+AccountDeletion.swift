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
//  Indépendance de lot : l'appel réseau est défini ici (`deleteRemoteAccount`)
//  tant que `DuelloAPI.deleteAccount` (lot R1, `DuelloAPIAccount.swift`) n'est
//  pas posé sur `main` — la suppression ne dépend d'aucun autre lot.
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
        try await Self.deleteRemoteAccount(token: token)
        purgeLocalAccount()
    }

    /// `DELETE /auth/account` (`deleteRemoteUserAccount` de
    /// `src/utils/serverSession.ts:231`) : supprime définitivement le compte
    /// serveur. Un refus est remonté avec le message du serveur ; sans corps
    /// d'erreur exploitable, le repli est « La suppression du compte est
    /// indisponible. » (V1 2026-09-26 — écart U08#2).
    ///
    /// Défini dans ce lot (R5) plutôt que dans `DuelloAPIAccount.swift` (lot
    /// R1) pour rester autonome ; le socle `DuelloAPI.request` remplace un
    /// corps d'erreur absent par « Service indisponible (status). », texte
    /// générique qui cède ici la place au libellé de la source.
    private static func deleteRemoteAccount(token: String) async throws {
        do {
            _ = try await DuelloAPI.request("auth/account", method: "DELETE", token: token)
        } catch let error as DirectoryError {
            throw DirectoryError(
                message: error.message.hasPrefix("Service indisponible (")
                    ? "La suppression du compte est indisponible."
                    : error.message,
                status: error.status
            )
        }
    }

    /// Purge locale d'un compte supprimé : la session, le profil et leurs
    /// traces persistées (trousseau, préférences) quittent l'appareil, ainsi
    /// que les données cloisonnées par compte.
    ///
    /// `removeLocalAccountData` (`App.tsx:2353`, `storage/AccountStorage.tsx:208`)
    /// efface **toutes** les clés physiques préfixées par
    /// `RewStorageScope.accountStoragePrefix(accountId:)` (notes, Elo, XP,
    /// planning…). Sans cette purge, les données scopées survivaient à la
    /// suppression et restaient lisibles par une reconnexion du même compte.
    @MainActor
    private func purgeLocalAccount() {
        // L'adresse est relevée avant la remise à zéro du profil.
        let email = profile.email.isEmpty ? (session?.email ?? "") : profile.email
        session = nil
        isSignedIn = false
        profile = UserProfile()
        Keychain.delete(service: Self.service, account: Self.account)
        UserDefaults.standard.removeObject(forKey: Self.profileKey)
        if !email.isEmpty {
            _ = RewLocalAccountData.removeLocalAccountData(
                accountId: Self.localAccountId(for: email)
            )
        }
    }
}
