//
//  PremRevenueCatService.swift
//  Duello
//
//  Service d'abonnement RevenueCat.
//
//  Fichier source Expo porté (commentaires repris mot pour mot) :
//    - src/utils/purchaseService.ts (`isRevenueCatPaywallAvailable`,
//      `hasActiveEntitlement`, `logInPurchases`, `presentCustomerCenter`,
//      `ensurePurchasesConfigured`).
//
//  Le module natif `react-native-purchases` n'est disponible que dans les builds
//  mobiles où il a été installé ; il est chargé à la demande et sa présence est
//  sondée avant toute commande. Sans module ni clé configurée, l'achat est
//  déclaré indisponible et la fenêtre l'affiche plutôt que de promettre un
//  paiement impossible.
//
//  ⚠️ **RevenueCat est une dépendance externe interdite** par le brief de
//  portage : la sonde `PremPurchasesModules.nativePurchasesModule()` renvoie
//  `nil` dans ce build, donc chaque prédicat ci-dessous est faux et chaque
//  commande refuse **clairement** — jamais un stub muet. La couture est
//  néanmoins **posée** : le jour où le module natif est embarqué, tout part
//  réellement, sans toucher au reste du flux.
//
//  L'application n'ouvre jamais l'accès elle-même : après un achat réussi, le
//  webhook RevenueCat annonce la période au serveur, et `PremCodeSync` la
//  recopie sur le compte, comme pour tout autre paiement.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// `CustomerCenterResult` de `purchaseService.ts`.
enum PremCustomerCenterResult: String {
    /// Le Customer Center a été présenté.
    case shown
    /// SDK, interface ou clé absents : rien n'a pu être ouvert.
    case unavailable
}

/// `src/utils/purchaseService.ts` : surface RevenueCat consommée par l'app.
enum PremRevenueCatService {
    /// `isRevenueCatPaywallAvailable()` : SDK + interface RevenueCat + clé.
    static var isRevenueCatPaywallAvailable: Bool {
        purchaseAvailable && PremPurchasesModules.nativePurchasesUIModule() != nil
    }

    /// `ensurePurchasesConfigured(appUserID)` : configure RevenueCat une seule
    /// fois par session, sous l'identifiant du compte.
    static func ensurePurchasesConfigured(appUserID: String) async -> Bool {
        if let pending = PremRevenueCatConfigureStore.shared.task {
            return await pending.value
        }
        let task = Task { await configureOnce(appUserID: appUserID) }
        PremRevenueCatConfigureStore.shared.task = task
        return await task.value
    }

    /// `hasActiveEntitlement()` : le compte courant a-t-il déjà un abonnement
    /// actif côté RevenueCat ?
    static func hasActiveEntitlement() async -> Bool {
        guard let purchases = PremPurchasesModules.nativePurchasesModule() else {
            return false
        }
        do {
            return entitlementActive(try await purchases.customerInfo())
        } catch {
            return false
        }
    }

    /// `logInPurchases(appUserID)` : associe le compte Duello (`member-…`) à
    /// l'acheteur du store.
    static func logInPurchases(appUserID: String) async {
        guard let purchases = PremPurchasesModules.nativePurchasesModule() else { return }
        do {
            _ = try await purchases.logIn(appUserID: appUserID)
        } catch {
            // La configuration peut avoir été faite avant l'authentification :
            // le webhook porte l'identifiant, la session rattrapera.
        }
    }

    /// `presentCustomerCenter()` : ouvre le Customer Center RevenueCat (gestion
    /// de l'abonnement, remboursement via le store, offres de rétention).
    /// Indisponible sans SDK ni clé.
    static func presentCustomerCenter() async -> PremCustomerCenterResult {
        guard let ui = PremPurchasesModules.nativePurchasesUIModule(),
              purchaseAvailable else { return .unavailable }
        guard await ensurePurchasesConfigured(appUserID: PremCodePurchaser.currentId()) else {
            return .unavailable
        }
        do {
            try await ui.presentCustomerCenter()
            return .shown
        } catch {
            return .unavailable
        }
    }

    /// `isPurchaseAvailable()` : le paiement in-app est-il possible sur cet
    /// appareil, maintenant ? Module natif **et** clé RevenueCat présents.
    ///
    /// Distinct de `PremPurchaseService.isAvailable`, qui dit si la couture
    /// **StoreKit** est posée (divergence assumée de `PremStoreKitPurchases`) :
    /// ici, c'est la sonde RevenueCat du web qui est traduite.
    private static var purchaseAvailable: Bool {
        PremPurchasesModules.nativePurchasesModule() != nil
            && !PremRevenueCatConfig.apiKey(for: .ios).isEmpty
    }

    /// `configureOnce(appUserID)` : configuration réelle. La source refuse sans
    /// module ni clé (`if (!purchases || !apiKey) return false`) plutôt que de
    /// configurer à vide.
    private static func configureOnce(appUserID: String) async -> Bool {
        guard let purchases = PremPurchasesModules.nativePurchasesModule() else {
            return false
        }
        let key = PremRevenueCatConfig.apiKey(for: .ios)
        guard !key.isEmpty else { return false }
        do {
            try await purchases.configure(apiKey: key, appUserID: appUserID)
            return true
        } catch {
            return false
        }
    }

    /// `entitlementActive(customerInfo)` : l'entitlement attendu est-il actif
    /// dans le client info RevenueCat (`entitlements.active[duello_pro]`) ?
    private static func entitlementActive(_ customerInfo: String) -> Bool {
        guard let data = customerInfo.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entitlements = object["entitlements"] as? [String: Any],
              let active = entitlements["active"] as? [String: Any]
        else { return false }
        return active[PremRevenueCatConfig.entitlement] != nil
    }
}

/// Cellule partagée de la promesse de configuration (une par session), pendant
/// du `configurePromise` de module de la source : la configuration n'est tentée
/// qu'une fois, et les appels suivants attendent la même promesse.
private final class PremRevenueCatConfigureStore {
    static let shared = PremRevenueCatConfigureStore()

    /// `configurePromise` : `nil` tant qu'aucune configuration n'a été demandée.
    var task: Task<Bool, Never>?

    private init() {}
}
