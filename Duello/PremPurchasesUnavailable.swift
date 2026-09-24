//
//  PremPurchasesUnavailable.swift
//  Duello
//
//  Implémentation « seam honnête » des modules natifs RevenueCat : chaque appel
//  refuse clairement, jamais un stub muet.
//
//  Fichier source Expo porté (intention reprise) :
//    - src/utils/purchaseModules.native.ts (absence de module → achat
//      impossible) et `src/utils/purchaseService.ts` (surface d'achat).
//
//  ⚠️ **Aucun paiement réel.** Cette implémentation ne prélève rien et **lève**
//  sur chaque appel : elle existe pour que la couture soit explicite là où un
//  `nil` ne suffirait pas (par exemple un objet non optionnel attendu par un
//  appelant). La vraie facturation (StoreKit/RevenueCat) la remplacera le jour
//  où la dépendance externe sera autorisée.
//
//  Limite assumée (24/09/2026) : aucun paiement réel ; chaque appel lève
//  explicitement, jamais un stub muet.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// Modules RevenueCat absents : toute opération lève `unavailable`.
struct PremRevenueCatUnavailable: PremNativePurchases, PremNativePurchasesUI {
    /// `configure({ apiKey, appUserID })`.
    func configure(apiKey: String, appUserID: String?) async throws {
        throw PremPurchaseModuleError.unavailable
    }

    /// `getCustomerInfo()`.
    func customerInfo() async throws -> String {
        throw PremPurchaseModuleError.unavailable
    }

    /// `getOfferings()`.
    func offerings() async throws -> String {
        throw PremPurchaseModuleError.unavailable
    }

    /// `logIn(appUserID)`.
    func logIn(appUserID: String) async throws -> String {
        throw PremPurchaseModuleError.unavailable
    }

    /// `syncObserverModeAmazonPurchase?(...)`.
    func syncObserverModeAmazonPurchase() async throws {
        throw PremPurchaseModuleError.unavailable
    }

    /// `presentPaywall(options?)`.
    func presentPaywall(offering: String?) async throws -> String {
        throw PremPurchaseModuleError.unavailable
    }

    /// `presentPaywallIfNeeded({ requiredEntitlementIdentifier, offering? })`.
    func presentPaywallIfNeeded(
        requiredEntitlementIdentifier: String,
        offering: String?
    ) async throws -> String {
        throw PremPurchaseModuleError.unavailable
    }

    /// `presentCustomerCenter()`.
    func presentCustomerCenter() async throws {
        throw PremPurchaseModuleError.unavailable
    }
}
