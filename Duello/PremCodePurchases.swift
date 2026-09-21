//
//  PremCodePurchases.swift
//  Duello
//
//  Couture d’achat natif — **simulée**, sans aucune dépendance de facturation.
//
//  Fichiers source Expo portés :
//    - `src/utils/purchaserIdentity.ts` (identifiant d’acheteur du compte) ;
//    - la surface d’achat de `src/utils/purchaseService.ts`, réduite au strict
//      nécessaire : disponibilité, identifiant d’acheteur, lancement d’achat.
//
//  ⚠️ **RevenueCat est une dépendance externe interdite** par le brief de
//  portage, et aucun StoreKit n’est embarqué. Ce protocole est la couture
//  prévue pour le jour où la facturation native arrivera : tout appel d’achat
//  passe par ici, jamais directement depuis une vue. L’implémentation fournie
//  (`PremCodeSimulatedPurchases`) ne prélève rien et refuse l’achat.
//
//  Cible : iOS 16.
//
import Foundation

/// Point d’achat natif, isolé derrière un protocole.
protocol PremCodePurchases {
    /// `isPurchaseAvailable()` : la facturation est-elle opérationnelle ?
    var isAvailable: Bool { get }
    /// `member-…` du compte connecté, ou vide hors session.
    var purchaserId: String { get }
    /// Lance l’achat d’une offre ; lève si la facturation est absente.
    func beginPurchase(offerId: String) async throws
}

/// Refus d’achat de la couture simulée.
enum PremCodePurchaseError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "La fenêtre d’abonnement n’est pas encore activée sur cette application."
    }
}

/// Implémentation simulée : rien n’est acheté, aucun montant n’est prélevé.
struct PremCodeSimulatedPurchases: PremCodePurchases {
    var isAvailable: Bool { false }
    var purchaserId: String { PremCodePurchaser.currentId() }
    func beginPurchase(offerId: String) async throws { throw PremCodePurchaseError.unavailable }
}

/// `purchaserIdentity.ts` : adresse du compte connecté retenue pour la
/// facturation native, posée à la racine par la synchronisation d’abonnement.
///
/// L’adresse vit dans un registre partagé (`PremCodePurchaserRegistry`), comme
/// le singleton `PremToolPaywallCenter`, plutôt que dans une variable statique
/// mutable.
enum PremCodePurchaser {
    /// `setCurrentAccountEmail`.
    static func setCurrentAccountEmail(_ email: String) {
        PremCodePurchaserRegistry.shared.email = email
    }

    /// `currentPurchaserId` : `member-…` du compte connecté, ou vide.
    static func currentId() -> String {
        let trimmed = PremCodePurchaserRegistry.shared.email
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : DuelloAPI.publicProfileId(email: trimmed)
    }
}

/// Cellule partagée de l’adresse du compte connecté.
final class PremCodePurchaserRegistry {
    static let shared = PremCodePurchaserRegistry()

    /// Adresse du compte connecté, vide hors session.
    var email = ""

    private init() {}
}
