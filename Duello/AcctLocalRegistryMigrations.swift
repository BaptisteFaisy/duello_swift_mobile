//
//  AcctLocalRegistryMigrations.swift
//  Duello
//
//  Port de src/utils/auth.ts (RN) — détecteurs de migration du registre local
//  utilisateur. Chaque détecteur répond à la même question : le registre
//  persisté doit-il être **réécrit** pour adopter la forme courante ?
//
//  Fichiers source Expo portés :
//    - src/utils/auth.ts
//        `needsUserCreatedAtMigration`, `needsUserEmailDedupeMigration`,
//        `needsUserPublicProfileMigration`, et la condition de réécriture de
//        `loadAccounts`.
//    - src/utils/recoveryCodePolicy.ts (`needsUserRecoveryCodeRemoval`, déjà
//        porté dans `AcctSecRecoveryCodePolicy.swift`, réutilisé tel quel).
//
//  Aucune dépendance nouvelle : ces fonctions ne lisent que la chaîne JSON
//  brute, comme la source, afin de détecter un ancien format même quand la
//  normalisation l'aurait déjà accepté.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Détecteurs de migration du registre utilisateur (`src/utils/auth.ts`).
enum AcctLocalRegistryMigrations {
    /// `needsUserCreatedAtMigration` : un compte non admin sans `createdAt`
    /// exploitable doit recevoir une origine.
    static func needsUserCreatedAtMigration(_ raw: String?) -> Bool {
        guard let entries = AcctLocalRegistryJSON.array(raw) else { return false }
        return entries.contains { entry in
            if entry["role"] as? String == AcctSecAccountRole.admin.rawValue { return false }
            let createdAt = AcctLocalRegistryJSON.double(entry["createdAt"])
            return !(createdAt.map { $0.isFinite && $0 > 0 } ?? false)
        }
    }

    /// `needsUserPublicProfileMigration` : un profil utilisateur pas encore
    /// explicitement public doit être réécrit.
    static func needsUserPublicProfileMigration(_ raw: String?) -> Bool {
        guard let entries = AcctLocalRegistryJSON.array(raw) else { return false }
        return entries.contains { entry in
            if entry["role"] as? String == AcctSecAccountRole.admin.rawValue { return false }
            let profile = entry["profile"] as? [String: Any]
            return AcctLocalRegistryJSON.bool(profile?["isPublic"]) != true
        }
    }

    /// `needsUserEmailDedupeMigration` : deux comptes utilisateur partagent une
    /// même adresse normalisée — un doublon hérité d'anciennes versions.
    static func needsUserEmailDedupeMigration(_ raw: String?) -> Bool {
        guard raw != nil else { return false }
        let users = AcctLocalRegistry.parseAccountArray(raw).filter { $0.isUser }
        let emails = Set(users.map { AcctLocalRegistry.normalizeEmail($0.email) })
        return emails.count != users.count
    }

    /// Condition de réécriture de `loadAccounts` :
    /// `!usersRaw ||` les quatre détecteurs (création, profil public, retrait du
    /// code de secours, e-mail dupliqué).
    static func needsRewrite(usersRaw: String?) -> Bool {
        usersRaw == nil
            || needsUserCreatedAtMigration(usersRaw)
            || needsUserPublicProfileMigration(usersRaw)
            || AcctSecRecoveryCodePolicy.needsUserRecoveryCodeRemoval(rawRegistry: usersRaw)
            || needsUserEmailDedupeMigration(usersRaw)
    }
}
