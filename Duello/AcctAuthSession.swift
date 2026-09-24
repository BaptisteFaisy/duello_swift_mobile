//
//  AcctAuthSession.swift
//  Duello
//
//  Port de src/utils/authSession.ts (RN) — effacement de la session locale avant
//  de quitter l'écran connecté, et clés de session/authentification globales.
//
//  Fichiers source Expo portés (clés et message repris mot pour mot) :
//    - src/utils/authSession.ts
//        `LEGACY_PROFILE_STORAGE_KEY`, `LEGACY_SESSION_STORAGE_KEY`,
//        `ACTIVE_ACCOUNT_EMAIL_KEY`, `ACTIVE_NAVIGATION_STORAGE_KEY`,
//        `AUTH_SESSION_STORAGE_KEYS`, `hasPersistedSession`,
//        `clearPersistedAuthSession`.
//
//  Note de parité (24/09/2026) : la persistance Swift est native (trousseau +
//  `UserDefaults`, voir `SessionStore.swift`), sans équivalent des anciennes clés
//  `AsyncStorage` de l'app Expo. Ce module porte donc l'**effacement
//  défensif** : il supprime ces clés héritées, puis **relit** pour confirmer —
//  la relecture protège notamment iOS contre une suppression groupée signalée
//  comme terminée sans avoir retiré toutes les clés. Le compte et ses données
//  cloisonnées ne font pas partie de cette opération.
//
//  Seam honnête : le stockage multi-clés est derrière `AcctAuthSessionStorage`
//  (implémentation par défaut : `UserDefaults`). La source est asynchrone ; la
//  lecture `UserDefaults` étant synchrone, l'API Swift l'est aussi.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Clés de session/authentification, volontairement globales
/// (`src/utils/authSession.ts`).
enum AcctAuthSessionKeys {
    /// `LEGACY_PROFILE_STORAGE_KEY`.
    static let legacyProfile = "@prepapp/profile"
    /// `LEGACY_SESSION_STORAGE_KEY`.
    static let legacySession = "@prepapp/onboarding-complete-v5"
    /// `ACTIVE_ACCOUNT_EMAIL_KEY`.
    static let activeAccountEmail = "@prepapp/active-account-email-v1"
    /// `ACTIVE_NAVIGATION_STORAGE_KEY` : ancienne clé, conservée uniquement pour
    /// être supprimée à la déconnexion.
    static let activeNavigation = "@prepapp/active-navigation-v1"

    /// `AUTH_SESSION_STORAGE_KEYS`.
    static let all: [String] = [
        activeAccountEmail,
        activeNavigation,
        legacyProfile,
        legacySession,
    ]
}

/// Stockage multi-clés minimal (`AuthSessionStorage` de `authSession.ts`).
protocol AcctAuthSessionStorage {
    func multiGet(_ keys: [String]) -> [(key: String, value: String?)]
    func multiRemove(_ keys: [String])
    func removeItem(_ key: String)
}

/// Implémentation par défaut adossée à `UserDefaults`.
struct AcctUserDefaultsAuthSessionStorage: AcctAuthSessionStorage {
    func multiGet(_ keys: [String]) -> [(key: String, value: String?)] {
        keys.map { ($0, UserDefaults.standard.string(forKey: $0)) }
    }

    func multiRemove(_ keys: [String]) {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    func removeItem(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Erreur d'effacement de session, alignée sur le message de la source.
enum AcctAuthSessionError: LocalizedError, Equatable {
    case sessionNotCleared

    var errorDescription: String? {
        "La session locale n’a pas pu être effacée."
    }
}

/// `authSession.ts` : effacement défensif de la session persistée.
enum AcctAuthSession {
    /// `hasPersistedSession` : au moins une clé porte encore une valeur.
    static func hasPersistedSession(_ entries: [(key: String, value: String?)]) -> Bool {
        entries.contains { $0.value != nil }
    }

    /// `clearPersistedAuthSession` : suppression groupée, puis relecture ; en
    /// cas de reste, suppression clé par clé, puis seconde relecture qui lève
    /// l'erreur si des clés subsistent encore.
    static func clearPersistedAuthSession(
        storage: AcctAuthSessionStorage = AcctUserDefaultsAuthSessionStorage()
    ) throws {
        storage.multiRemove(AcctAuthSessionKeys.all)

        let remaining = storage.multiGet(AcctAuthSessionKeys.all)
        if !hasPersistedSession(remaining) { return }

        AcctAuthSessionKeys.all.forEach { storage.removeItem($0) }
        let remainingAfterRetry = storage.multiGet(AcctAuthSessionKeys.all)
        if hasPersistedSession(remainingAfterRetry) {
            throw AcctAuthSessionError.sessionNotCleared
        }
    }
}
