//
//  ConsentPremiumGate.swift
//  Duello
//
//  Garde Premium : vérifie l'abonnement au moment exact où l'élève touche un
//  outil réservé, et ouvre la fenêtre de paiement sinon.
//
//  Fichiers source Expo portés :
//    - `src/hooks/usePremiumToolGate.ts` (`usePremiumToolGate`) ;
//    - `src/utils/premiumToolAccess.ts` (`PremiumTool`, `premiumToolNotice` :
//      déjà porté par `PremPremiumTool`, réutilisé ici) ;
//    - `src/utils/subscription.ts` (`parseSubscription`,
//      `isSubscriptionActive` : déjà porté par `PremCodeSubscription`) ;
//    - `src/components/PremiumToolPaywall.tsx` (`openPremiumToolPaywall` :
//      déjà porté par `openPremPremiumToolPaywall`).
//
//  La source lit l'abonnement dans `AccountStorage` (`ACCOUNT_STORAGE_KEYS
//  .subscription`) ; le portage lit la même entrée que `PremCodeSync` écrit,
//  sous la clé `com.duello.ios.premcode.subscription.<compte>`. Une lecture
//  impossible reste fermée par défaut, comme le contrôle serveur.
//
//  Cible : iOS 16.
//
import Foundation

/// Vérifie l'abonnement au moment où un outil Premium est touché
/// (`usePremiumToolGate`).
enum ConsentPremiumGate {

    /// Préfixe de la clé d'abonnement locale, alignée sur `PremCodeSync`.
    ///
    /// `PremCodeSync.storageKey` est privé : la garde reconstruit la même clé
    /// pour lire le même état, sans le modifier.
    static let storageKeyPrefix = "com.duello.ios.premcode.subscription."

    /// `Date.now()` de la source, en millisecondes (les échéances sont en ms).
    static func currentMilliseconds() -> Double {
        Date().timeIntervalSince1970 * 1000
    }

    /// Identifiant de compte local, comme `PremCodeSync` : l'e-mail normalisé
    /// haché en identifiant public, ou `"local"` sans compte.
    static func accountId(email: String) -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "local" : DuelloAPI.publicProfileId(email: trimmed)
    }

    /// Clé de persistance locale de l'abonnement, suffixée par le compte.
    static func storageKey(accountId: String) -> String {
        storageKeyPrefix + accountId
    }

    /// `isSubscriptionActive(parseSubscription(stored), now)` : vrai tant que la
    /// semaine réglée n'est pas écoulée. Une entrée absente ou illisible vaut
    /// « non abonné » — l'accès n'est jamais supposé.
    static func isSubscribed(accountId: String, now: Double) -> Bool {
        let raw = UserDefaults.standard.string(forKey: storageKey(accountId: accountId))
        let state = PremCodeSubscription.parse(raw)
        return PremCodeSubscription.isActive(state, now: now)
    }

    /// `usePremiumToolGate` : laisse passer l'outil si l'abonnement est actif,
    /// sinon ouvre la fenêtre de paiement et refuse. Renvoie `true` quand
    /// `onAllowed` a pu s'exécuter.
    @MainActor
    static func gate(
        tool: PremPremiumTool,
        accountId: String,
        now: Double = currentMilliseconds(),
        onAllowed: () async -> Void
    ) async -> Bool {
        guard isSubscribed(accountId: accountId, now: now) else {
            openPremPremiumToolPaywall(tool)
            return false
        }
        await onAllowed()
        return true
    }
}
