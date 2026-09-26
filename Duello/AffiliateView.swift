import SwiftUI

// MARK: - Espace affiliation
//
// Portage de `src/features/affiliate/AccountAffiliateContent.tsx` (assemblage
// des sections, dans l'ordre de la source) et de
// `src/screens/AccountAffiliateScreen.tsx` (en-tête avec retour).
//
// Ordre de la source : en-tête, état de chargement, puis — si le portefeuille
// est disponible — pastille de mode, solde, paliers de gains, avertissement de
// compatibilité, code d'affiliation, carte Stripe, formulaire de retrait, avis
// d'erreur et de succès, historique des retraits.
//
// Écarts assumés : l'espacement est uniforme (`14`) là où la source pose des
// marges par carte, et le portefeuille est relu au retour au premier plan via
// `scenePhase` (équivalent de l'écouteur `AppState` de React Native).

/// Espace affiliation : gains, paliers, portefeuille et retraits.
struct AffiliateView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = AffiliateEarningsController()

    /// Retour fourni par l'appelant ; sans lui, l'écran se ferme lui-même.
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AffiliateScreenHeader(
                    onBack: goBack,
                    refreshing: controller.refreshing,
                    refreshDisabled: controller.refreshing || controller.loading,
                    onRefresh: refresh
                )
                AffiliateLoadState(
                    loading: controller.loading,
                    hasWallet: controller.wallet != nil,
                    loadError: controller.loadError,
                    onRetry: retryLoad
                )
                if let wallet = controller.wallet {
                    walletSections(wallet)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 42)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.surface)
        .task { await controller.load(token: session.token) }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await controller.load(token: session.token, quiet: true) }
        }
    }

    @ViewBuilder
    private func walletSections(_ wallet: AffWallet) -> some View {
        AffiliateModePill(wallet: wallet)
        AffiliateBalanceCard(wallet: wallet)
        AffiliateMilestoneSection(wallet: wallet)
        notice(AffiliateCopy.compatibilityMessage(wallet), icon: "exclamationmark.circle")
        AffiliatePublicIdCard(
            publicId: wallet.publicId,
            copied: controller.publicIdCopied,
            onCopy: controller.copyPublicId
        )
        AffiliateStripeCard(
            copy: AffiliateCopy.connectionCopy(wallet),
            enabled: wallet.enabled,
            busy: controller.busy,
            opening: controller.openingStripe,
            onOpen: openStripe
        )
        AffiliateWithdrawalForm(controller: controller, onSubmit: submit)
        notices
        AffiliateWithdrawalHistory(controller: controller, onRetry: retry)
    }

    /// Avis de la dernière action : échec puis succès, dans l'ordre de la source.
    @ViewBuilder
    private var notices: some View {
        notice(controller.actionError, icon: "exclamationmark.circle")
        notice(controller.success, icon: "checkmark.circle")
    }

    @ViewBuilder
    private func notice(_ message: String?, icon: String) -> some View {
        if let message, !message.isEmpty {
            AffiliateNotice(message: message, icon: icon)
        }
    }

    private func goBack() {
        if let onBack { onBack() } else { dismiss() }
    }

    /// Bouton d'actualisation de l'en-tête (`loadWallet(true)`).
    private func refresh() {
        Task { await controller.load(token: session.token, quiet: true) }
    }

    /// « Réessayer » du chargement initial (`loadWallet()`).
    private func retryLoad() {
        Task { await controller.load(token: session.token) }
    }

    private func openStripe() {
        Task { await controller.openStripePortal(token: session.token) }
    }

    private func submit() {
        Task { await controller.submitWithdrawal(token: session.token) }
    }

    private func retry(_ withdrawal: AffWithdrawal) {
        Task { await controller.retryWithdrawal(withdrawal, token: session.token) }
    }
}
