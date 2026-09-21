//
//  PremCodeEvents.swift
//  Duello
//
//  Diffusion locale des changements d’abonnement.
//
//  Fichiers source Expo portés : `src/utils/premiumUnlockEvents.ts` et
//  `src/utils/subscriptionEvents.ts`. Aucun événement ne transporte de
//  donnée : le code utilisé n’est jamais retenu ni diffusé ; l’observateur
//  relit l’état stocké, seule source de vérité affichée.
//
//  ⚠️ Registre en mémoire, non persistant : comme côté Expo, les abonnements
//  ne survivent pas à un redémarrage. Le registre est partagé et protégé par
//  un verrou, comme `PushNotifDeviceTokenRegistry`. Là où la source ignore
//  l’exception d’un observateur défaillant, les fermetures Swift employées ici
//  ne lèvent pas.
//
//  ⚠️ `notifyChanged` / `subscribeToChanges` sont portés tels quels mais sans
//  producteur dans ce lot : côté Expo, l’unique abonné est le hook de quota de
//  corrections (`useCorrectionQuota.ts`), hors périmètre.
//
//  Cible : iOS 16.
//
import Foundation

/// API statique du registre local des événements d’abonnement.
enum PremCodeEvents {
    /// `notifyPremiumUnlocked` : prévient les observateurs d’un paiement
    /// confirmé, pour laisser l’interface féliciter l’élève.
    static func notifyUnlocked(accountId: String) {
        PremCodeEventRegistry.shared.notify(kind: .unlock, accountId: accountId)
    }

    /// `subscribeToPremiumUnlocks` : renvoie la fonction de désabonnement.
    @discardableResult
    static func subscribeToUnlocks(
        accountId: String,
        listener: @escaping () -> Void
    ) -> () -> Void {
        PremCodeEventRegistry.shared.subscribe(
            kind: .unlock, accountId: accountId, listener: listener)
    }

    /// `notifySubscriptionChanged` : signale un droit serveur modifié, sans
    /// transporter ni conserver le code utilisé.
    static func notifyChanged(accountId: String) {
        PremCodeEventRegistry.shared.notify(kind: .change, accountId: accountId)
    }

    /// `subscribeToSubscriptionChanges` : renvoie la fonction de désabonnement.
    @discardableResult
    static func subscribeToChanges(
        accountId: String,
        listener: @escaping () -> Void
    ) -> () -> Void {
        PremCodeEventRegistry.shared.subscribe(
            kind: .change, accountId: accountId, listener: listener)
    }
}

/// Registre partagé, sous verrou, des observateurs par compte.
final class PremCodeEventRegistry {
    static let shared = PremCodeEventRegistry()

    /// Nature d’événement : déblocage Premium ou changement d’abonnement.
    enum Kind: Equatable {
        case unlock
        case change
    }

    private let lock = NSLock()
    private var unlockListeners: [String: [UUID: () -> Void]] = [:]
    private var changeListeners: [String: [UUID: () -> Void]] = [:]

    private init() {}

    /// Préviens tous les observateurs du compte, hors verrou.
    func notify(kind: Kind, accountId: String) {
        lock.lock()
        let store = kind == .unlock ? unlockListeners : changeListeners
        let listeners = Array((store[accountId] ?? [:]).values)
        lock.unlock()
        for listener in listeners { listener() }
    }

    /// Ajoute un observateur ; renvoie sa fonction de désabonnement.
    @discardableResult
    func subscribe(
        kind: Kind,
        accountId: String,
        listener: @escaping () -> Void
    ) -> () -> Void {
        let id = UUID()
        lock.lock()
        if kind == .unlock {
            unlockListeners[accountId, default: [:]][id] = listener
        } else {
            changeListeners[accountId, default: [:]][id] = listener
        }
        lock.unlock()
        return { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            if kind == .unlock {
                self.unlockListeners[accountId]?.removeValue(forKey: id)
                if self.unlockListeners[accountId]?.isEmpty == true {
                    self.unlockListeners[accountId] = nil
                }
            } else {
                self.changeListeners[accountId]?.removeValue(forKey: id)
                if self.changeListeners[accountId]?.isEmpty == true {
                    self.changeListeners[accountId] = nil
                }
            }
            self.lock.unlock()
        }
    }
}
