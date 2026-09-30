//
//  PremPurchaseFlow.swift
//  Duello
//
//  Flux d’achat Premium : portage de `src/hooks/usePremiumPurchase.ts`.
//
//  Le hook Expo expose `available` / `busy` / `launch(offerId)` et ouvre soit
//  Stripe Checkout (web), soit le paywall RevenueCat (iOS/Android), avec les
//  alertes « Bienvenue en Premium » / « Abonnement restauré » / « Achat
//  indisponible » / « Paiement impossible ». Sur iOS natif il n’y a pas de web :
//  tout passe par la couture `PremCodePurchases` (`PremStoreKitPurchases`).
//
//  L’accès n’est jamais ouvert ici : un achat réussi est annoncé au serveur, et
//  `PremCodeSync` recopie la période sur le compte. Une simple fermeture de la
//  fenêtre reste silencieuse.
//
//  Cible : iOS 16.
//
import Foundation
import Combine

/// Alerte du flux d’achat (`AppAlert.alert` de `usePremiumPurchase.ts`) : un
/// titre et un corps, identifiés par leur contenu pour `.alert(item:)`.
struct PremPurchaseAlert: Identifiable, Equatable {
    let title: String
    let message: String
    var id: String { "\(title)|\(message)" }
}

/// Ouvre l’abonnement derrière « Accéder à Premium » (`usePremiumPurchase`).
@MainActor
final class PremPurchaseFlow: ObservableObject {

    /// `PURCHASE_FAILURE_MESSAGE`, mot pour mot.
    static let purchaseFailureMessage =
        "Le paiement n’a pas abouti. Vérifie ta connexion puis réessaie — aucun montant n’a été prélevé."
    /// `PAYWALL_UNAVAILABLE_MESSAGE`, mot pour mot.
    static let paywallUnavailableMessage =
        "La fenêtre d’abonnement n’est pas encore activée sur cette application."
    /// `SIGN_IN_REQUIRED_MESSAGE`, mot pour mot.
    static let signInRequiredMessage =
        "Connecte-toi à ton compte avant de t’abonner."

    /// Vrai pendant une tentative d’achat (« Ouverture… » du bouton).
    @Published private(set) var busy = false
    /// Alerte à présenter, `nil` tant qu’aucun message n’est à afficher.
    @Published var alert: PremPurchaseAlert?

    private let purchases: PremCodePurchases

    init(purchases: PremCodePurchases = PremStoreKitPurchases()) {
        self.purchases = purchases
    }

    /// `available` : `isStripeCheckoutSupported() || isPurchaseAvailable()`.
    /// Sur iOS natif, pas de Stripe web : la disponibilité vient du seam.
    var available: Bool { purchases.isAvailable }

    /// `launch(offerId)` : garde de session, achat, puis l’alerte exacte de la
    /// source. Un achat indisponible refuse **clairement**, jamais en silence.
    func launch(offerId: PremOfferId) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        guard !purchases.purchaserId.isEmpty else {
            alert = PremPurchaseAlert(
                title: "Connexion requise", message: Self.signInRequiredMessage)
            return
        }
        // `usePremiumPurchase.ts:88` : la facturation native se configure
        // **avant** la fenêtre d’achat ; sans configuration, « Achat
        // indisponible » (jamais un paywall ouvert dans le vide).
        guard await purchases.ensurePurchasesConfigured() else {
            alert = PremPurchaseAlert(
                title: "Achat indisponible", message: Self.paywallUnavailableMessage)
            return
        }
        do {
            try await purchases.beginPurchase(offerId: offerId.rawValue)
            alert = PremPurchaseAlert(
                title: "Bienvenue en Premium",
                message: "Ton abonnement est actif — l’accès s’ouvre d’un instant à l’autre.")
        } catch PremCodePurchaseError.unavailable {
            alert = PremPurchaseAlert(
                title: "Achat indisponible", message: Self.paywallUnavailableMessage)
        } catch {
            alert = PremPurchaseAlert(
                title: "Paiement impossible", message: Self.purchaseFailureMessage)
        }
    }
}
