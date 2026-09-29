//
//  PremRevenueCatConfig.swift
//  Duello
//
//  Configuration RevenueCat de l'application.
//
//  Fichier source Expo porté (commentaires repris mot pour mot) :
//    - src/config/revenueCat.ts (`REVENUECAT_ENTITLEMENT`,
//      `REVENUECAT_PRODUCT_IDS`, `isRevenueCatApiKey`, `revenueCatApiKeyFor`,
//      `REVENUECAT_APPLE_CONFIGURED`, `REVENUECAT_GOOGLE_CONFIGURED`).
//
//  ⚠️ Les clés publiques du SDK RevenueCat ne sont pas des secrets : RevenueCat
//  les incorpore dans les applications clientes, comme les identifiants OAuth de
//  `googleAuth.ts`. Sans clé posée, le bouton d'abonnement reste volontairement
//  inactif : aucune commande ne peut être passée sans l'identifiant du projet.
//
//  Côté Expo les clés viennent de `EXPO_PUBLIC_REVENUECAT_*` ; côté Swift, de
//  l'`Info.plist` du bundle (`RevenueCatAPIKey`, `RevenueCatAppleAPIKey`,
//  `RevenueCatGoogleAPIKey`), relue à la demande. Aucune n'est posée dans ce
//  portage, donc `appleConfigured` / `googleConfigured` sont faux.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// Plateforme de boutique, pendant de `Platform.OS` de la source.
enum PremRevenueCatPlatform: String {
    case ios
    case android
}

/// `src/config/revenueCat.ts` : configuration RevenueCat de l'application.
enum PremRevenueCatConfig {
    /// `REVENUECAT_ENTITLEMENT` : entitlement attendu, aligné sur le traducteur
    /// serveur (`server/revenuecat-webhooks.mjs`) — un achat qui activerait un
    /// autre entitlement ne serait pas reconnu par l'application.
    static let entitlement = "duello_pro"

    /// `REVENUECAT_PRODUCT_IDS` : identifiants attendus dans l'Offering
    /// RevenueCat. Documentaire — les produits affichés et achetés viennent de
    /// l'Offering configurée dans RevenueCat, jamais d'une liste codée ici.
    static let productIds: [String: String] = [
        "weekly": "premium_weekly",
        "monthly": "premium_monthly",
        "yearly": "yearly",
        "annual": "premium_annual",
    ]

    /// `isRevenueCatApiKey` : forme d'une clé publique RevenueCat — préfixe
    /// `appl_` / `goog_` / `test_` suivi d'au moins 20 caractères.
    static func isRevenueCatApiKey(_ value: String) -> Bool {
        guard let prefix = ["appl_", "goog_", "test_"]
            .first(where: { value.hasPrefix($0) })
        else { return false }
        return validBody(value.dropFirst(prefix.count))
    }

    /// `revenueCatApiKeyFor(platform)` : clé de la boutique, sinon clé unique.
    static func apiKey(for platform: PremRevenueCatPlatform) -> String {
        platform == .ios ? appleKey : googleKey
    }

    /// `REVENUECAT_APPLE_CONFIGURED`.
    static var appleConfigured: Bool { isRevenueCatApiKey(appleKey) }

    /// `REVENUECAT_GOOGLE_CONFIGURED`.
    static var googleConfigured: Bool { isRevenueCatApiKey(googleKey) }

    /// `REVENUECAT_APPLE_API_KEY` : clé propre à l'App Store, sinon clé unique.
    static var appleKey: String {
        firstNonEmpty(info("RevenueCatAppleAPIKey"), singleKey)
    }

    /// `REVENUECAT_GOOGLE_API_KEY` : clé propre à Play, sinon clé unique.
    static var googleKey: String {
        firstNonEmpty(info("RevenueCatGoogleAPIKey"), singleKey)
    }

    /// `REVENUECAT_API_KEY` : clé unique du projet, posée pour toutes les
    /// plateformes (`EXPO_PUBLIC_REVENUECAT_API_KEY` côté Expo).
    static var singleKey: String { info("RevenueCatAPIKey") }

    /// Le corps d'une clé RevenueCat : `[A-Za-z0-9_-]{20,}` de la source.
    private static func validBody(_ body: Substring) -> Bool {
        body.count >= 20 && body.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-"
        }
    }

    /// Première valeur non vide des deux (repli `||` de la source).
    private static func firstNonEmpty(_ a: String, _ b: String) -> String {
        a.isEmpty ? b : a
    }

    /// Valeur de configuration du bundle, ébarbée, vide si absente.
    private static func info(_ key: String) -> String {
        ((Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
