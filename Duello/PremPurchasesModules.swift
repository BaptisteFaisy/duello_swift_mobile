//
//  PremPurchasesModules.swift
//  Duello
//
//  Sondes des modules natifs RevenueCat — équivalent iOS de
//  `purchaseModules.native.ts`.
//
//  Fichier source Expo porté (commentaires repris mot pour mot) :
//    - src/utils/purchaseModules.native.ts
//        `nativePurchasesModule`, `nativePurchasesUIModule`.
//
//  ⚠️ La source porte un avertissement qui explique **pourquoi** une sonde
//  naïve ne suffit pas : `globalThis.require` n'existe pas dans un bundle React
//  Native, si bien que sonder `globalThis.require` renvoyait toujours `null`,
//  `isPurchaseAvailable()` toujours `false`, et le bouton d'abonnement restait
//  inerte même avec le module compilé et la clé posée. Côté Swift, il n'y a ni
//  `require` ni bundle dynamique : un module natif absent est absent à la
//  compilation. La sonde honnête renvoie donc `nil` et l'appelant sait, sans
//  ambiguïté, qu'aucun achat réel n'est possible.
//
//  Limite assumée (24/09/2026) : aucun module natif dans ce build, donc aucun
//  achat réel ; les sondes renvoient `nil` de façon explicite.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// `nativePurchasesModule()` / `nativePurchasesUIModule()` : sondes paresseuses.
enum PremPurchasesModules {
    /// Message d'indisponibilité, partagé avec la fenêtre d'abonnement.
    static let unavailableReason =
        "La facturation native (RevenueCat) n’est pas embarquée dans cette application."

    /// `nativePurchasesModule()` : le module natif est-il présent dans ce build ?
    /// Jamais ici — la cible n'embarque pas `react-native-purchases`.
    static func nativePurchasesModule() -> (any PremNativePurchases)? { nil }

    /// `nativePurchasesUIModule()` : l'interface RevenueCat (paywall, Customer
    /// Center) est-elle embarquée ? Jamais ici, pour la même raison.
    static func nativePurchasesUIModule() -> (any PremNativePurchasesUI)? { nil }
}
