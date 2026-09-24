//
//  PremPurchases.swift
//  Duello
//
//  Contrat des modules natifs RevenueCat, tel que la façade d'achat l'utilise.
//
//  Fichiers source Expo portés (contrat repris mot pour mot) :
//    - src/utils/purchaseModules.types.ts (`NativePurchases`, `NativePurchasesUI`) ;
//    - src/utils/purchaseModules.ts (façade qui réexporte le contrat natif).
//
//  ⚠️ **RevenueCat est une dépendance externe interdite** par le brief de
//  portage, et aucun StoreKit n'est embarqué : la cible ne peut donc pas fournir
//  d'implémentation réelle. Ces protocoles sont la **couture** derrière laquelle
//  une vraie facturation viendra un jour ; tant qu'elle est absente, l'appelant
//  reçoit `nil` (voir `PremPurchasesModules.swift`) ou l'implémentation qui
//  refuse explicitement (voir `PremPurchasesUnavailable.swift`) — jamais un stub
//  muet qui ferait croire à un achat.
//
//  Notes (approché / limite assumée, 24/09/2026) : les méthodes de RevenueCat renvoient `unknown`
//  côté TypeScript. Faute de modèle partagé, elles renvoient ici une `String`
//  (JSON brut) — l'appelant qui en aura besoin le décodera.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// Erreur d'une couture d'achat sans module natif.
enum PremPurchaseModuleError: LocalizedError {
    /// Le module natif est absent de ce build.
    case moduleMissing
    /// La facturation native n'est pas opérationnelle.
    case unavailable

    var errorDescription: String? {
        switch self {
        case .moduleMissing:
            return "Le module natif RevenueCat est absent de ce build."
        case .unavailable:
            return "La facturation native (RevenueCat) n’est pas embarquée dans cette application."
        }
    }
}

/// `NativePurchases` : surface de `react-native-purchases` consommée par l'app.
protocol PremNativePurchases {
    /// `configure({ apiKey, appUserID })`.
    func configure(apiKey: String, appUserID: String?) async throws
    /// `getCustomerInfo()` (JSON brut).
    func customerInfo() async throws -> String
    /// `getOfferings()` (JSON brut).
    func offerings() async throws -> String
    /// `logIn(appUserID)` (JSON brut).
    func logIn(appUserID: String) async throws -> String
    /// `syncObserverModeAmazonPurchase?(...)` : optionnel côté natif.
    func syncObserverModeAmazonPurchase() async throws
}

/// `NativePurchasesUI` : interface RevenueCat (paywall, Customer Center).
protocol PremNativePurchasesUI {
    /// `presentPaywall(options?)` : renvoie l'identifiant de résultat du paywall.
    func presentPaywall(offering: String?) async throws -> String
    /// `presentPaywallIfNeeded({ requiredEntitlementIdentifier, offering? })`.
    func presentPaywallIfNeeded(
        requiredEntitlementIdentifier: String,
        offering: String?
    ) async throws -> String
    /// `presentCustomerCenter()`.
    func presentCustomerCenter() async throws
}
