import Foundation
import UIKit

// MARK: - Actions de l'utilisateur dans l'espace affiliation
//
// Portage de `useAffiliateAmount`, `useAffiliateStripePortal` et
// `useAffiliateWithdrawalRetry` de
// `src/features/affiliate/useAffiliateEarningsController.ts`. Ces actions
// complètent l'état déclaré dans `AffiliateEarningsController.swift`.

extension AffiliateEarningsController {
    /// `setAmount` : chaque frappe efface les avis précédents.
    func setAmount(_ value: String) {
        updateAmount(value)
        clearNotices()
    }

    /// `useAvailableBalance` : préremplit le montant retirable maximal.
    func useAvailableBalance() {
        guard let wallet, let limits else { return }
        setAmount(AffiliateFormatting.inputValue(Swift.min(wallet.availableMinor, limits.maximum)))
    }

    /// `retryWithdrawal` : relance seulement la partie bancaire d'un retrait
    /// déjà réservé — aucun recrédit n'est décidé côté téléphone.
    @MainActor
    func retryWithdrawal(_ withdrawal: AffWithdrawal, token: String?) async {
        let action = AffFinancialAction.retry(withdrawal.id)
        guard begin(action) else { return }
        do {
            _ = try await AffiliateAPI.retryWithdrawal(id: withdrawal.id, token: token)
            succeed("Le virement bancaire a été relancé.")
        } catch {
            fail(error, fallback: "Impossible de relancer ce virement.")
        }
        await load(token: token, quiet: true)
        finish(action)
    }

    /// `openStripe` : les pages Stripe hébergées s'ouvrent dans le navigateur
    /// système, jamais dans une vue embarquée qui recevrait des informations
    /// bancaires.
    @MainActor
    func openStripePortal(token: String?) async {
        guard let wallet, wallet.enabled, begin(.stripe) else { return }
        do {
            let onboarding = try await AffiliateAPI.onboardingLink(token: token)
            guard let url = URL(string: onboarding.url) else {
                throw DirectoryError(message: "Réponse Stripe illisible")
            }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } catch {
            fail(error, fallback: "Impossible d’ouvrir la connexion Stripe.")
        }
        finish(.stripe)
    }
}
