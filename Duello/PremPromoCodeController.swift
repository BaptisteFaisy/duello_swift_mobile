import Foundation
import Combine
import UIKit

// MARK: - État du formulaire de code promo

/// Portage de `src/hooks/usePromoCode.ts` : l'état du formulaire de code promo
/// et les étiquettes de prix réduits qu'il produit pour les offres.
///
/// Le code vit uniquement dans cet objet, en mémoire — il n'est ni persisté ni
/// journalisé, comme la source qui écarte le stockage (`textContentType="none"`,
/// `importantForAutofill="no"`, aucun `AsyncStorage`).
///
/// L'annonce d'accessibilité de la source (`AccessibilityInfo`) passe par
/// `UIAccessibility` : SwiftUI n'expose `AccessibilityNotification` qu'à partir
/// d'iOS 17, hors cible.
final class PremPromoCodeController: ObservableObject {
    /// Saisie courante, déjà normalisée (majuscules, sans caractère parasite).
    @Published private(set) var code = ""
    /// Réponse serveur de la dernière activation réussie.
    @Published private(set) var result: PremPromoResult?
    @Published private(set) var submitting = false
    /// Message d'erreur lisible, vide quand tout va bien.
    @Published private(set) var failure = ""

    /// `canSubmit` : au moins six caractères, hors envoi en cours.
    var canSubmit: Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= PremPricing.codeMinLength && !submitting
    }

    /// `discounted` : étiquettes de prix réduits par offre remisable, une fois
    /// le code activé. Vide tant que le serveur n'a rien accordé.
    var discounted: [PremOfferId: PremDiscount] {
        guard let percentOff = result?.percentOff else { return [:] }
        var labels: [PremOfferId: PremDiscount] = [:]
        for period in PremPricing.promoPeriods {
            labels[period] = PremPricing.discountLabels(period, percentOff: percentOff)
        }
        return labels
    }

    /// `promoCodeFeedback` : la ligne de statut affichée sous le formulaire.
    var feedback: String {
        if !failure.isEmpty { return failure }
        guard let result else { return "" }
        if result.applied {
            return "Code activé : \(PremPricing.savingLabel(result.percentOff)) sur tes offres Premium."
        }
        return "Ce code est déjà activé sur ton compte."
    }

    /// `setCode` : normalise la saisie et efface l'erreur précédente.
    func setCode(_ value: String) {
        code = PremPricing.normalizedCode(value)
        failure = ""
    }

    /// `submit` : active le code pour le compte de la session courante.
    /// Sans jeton, aucun appel réseau n'est tenté — le refus est le même que
    /// celui du serveur pour un compte non connecté.
    @MainActor
    func submit(token: String?) async {
        guard !submitting else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let token, !token.isEmpty else {
            failure = "Connecte-toi à un compte Duello pour utiliser un code promo."
            return
        }
        submitting = true
        do {
            let applied = try await PremPromoService.applyPromoCode(code: trimmed, token: token)
            result = applied
            failure = ""
            announce(applied)
        } catch {
            result = nil
            failure = PremPromoService.failureMessage(for: error)
        }
        submitting = false
    }

    /// `AccessibilityInfo.announceForAccessibility` : annoncée à chaque
    /// activation réussie, y compris quand le code était déjà actif.
    private func announce(_ applied: PremPromoResult) {
        let percent = PremPricing.percentText(applied.percentOff)
        UIAccessibility.post(
            notification: .announcement,
            argument: "Code promo activé : \(percent) pour cent de réduction."
        )
    }
}
