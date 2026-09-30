//
//  PremStoreKitPurchases.swift
//  Duello
//
//  Couture d’achat native adossée à **StoreKit** (iOS 16) — implémentation du
//  protocole `PremCodePurchases`.
//
//  Fichier source Expo porté : `src/utils/purchaseService.ts`
//  (`isPurchaseAvailable`, `ensurePurchasesConfigured`, `presentRevenueCatPaywall`,
//  `Product.products` / `purchase` de StoreKit). Côté Expo, les offres viennent
//  de l’_Offering_ RevenueCat (`yearly`, `monthly`) ; **RevenueCat est une
//  dépendance externe interdite** par le brief, la couture s’adosse donc à
//  StoreKit seul.
//
//  Doctrine « seam honnête » : le catalogue de produits App Store n’est pas
//  configuré dans ce portage (`productIds` vide), donc `beginPurchase` refuse
//  **clairement** (`PremCodePurchaseError.unavailable`) au lieu de simuler un
//  achat. Aucun stub silencieux. La couture est néanmoins **posée** : le jour où
//  les identifiants de produits sont renseignés, l’achat part réellement.
//
//  ⚠️ `isAvailable` vaut `true` : le bouton « Accéder à Premium » reste
//  **actionnable** et répond à l’élève (alerte explicite) plutôt que de rester
//  mort. Divergence assumée avec Expo, où le bouton est désactivé sans
//  RevenueCat : un bouton inerte est précisément le « stub silencieux » que la
//  doctrine proscrit.
//
//  Cible : iOS 16.
//
import Foundation

#if canImport(StoreKit)
import StoreKit
#endif

/// Couture d’achat native adossée à StoreKit.
struct PremStoreKitPurchases: PremCodePurchases {

    /// Identifiants de produits App Store, par offre payante.
    ///
    /// **Vide dans ce portage** : aucun produit n’est configuré (côté Expo, les
    /// offres sont gérées dans le tableau de bord RevenueCat). Renseigner cette
    /// table suffit à rendre l’achat réel, sans toucher au reste du flux.
    static let productIds: [PremOfferId: String] = [:]

    /// `isPurchaseAvailable()` : la couture est posée sur iOS. Le refus éventuel
    /// (produit non configuré) se dit au lancement, jamais par un bouton mort.
    var isAvailable: Bool { true }

    /// `currentPurchaserId()` : `member-…` du compte connecté, ou vide.
    var purchaserId: String { PremCodePurchaser.currentId() }

    /// `ensurePurchasesConfigured(appUserID)` : StoreKit ne demande aucune
    /// configuration préalable — la couture est prête dès que l’appareil peut
    /// payer. Le refus éventuel (produit non configuré) est porté par
    /// `beginPurchase`, pas ici.
    func ensurePurchasesConfigured() async -> Bool { true }

    /// `beginPurchase(offerId:)` : charge le produit StoreKit de l’offre et
    /// lance l’achat ; refuse clairement si aucun produit n’est configuré.
    func beginPurchase(offerId: String) async throws {
        guard let premId = PremOfferId(rawValue: offerId),
              let productId = Self.productIds[premId] else {
            throw PremCodePurchaseError.unavailable
        }
        #if canImport(StoreKit)
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            throw PremCodePurchaseError.unavailable
        }
        let result = try await product.purchase()
        switch result {
        case .success:
            return
        case .userCancelled, .pending:
            return
        @unknown default:
            throw PremCodePurchaseError.unavailable
        }
        #else
        throw PremCodePurchaseError.unavailable
        #endif
    }
}
