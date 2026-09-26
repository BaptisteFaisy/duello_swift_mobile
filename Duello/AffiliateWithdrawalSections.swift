import SwiftUI

// MARK: - Retraits d'affiliation
//
// Portage de `src/features/affiliate/AffiliateWithdrawalSections.tsx` :
// formulaire de retrait (montant, raccourci « Tout », envoi) et historique des
// virements avec relance. Mesures de
// `src/features/affiliate/affiliateEarningsStyles.ts`.

/// `AffiliateWithdrawalForm` : bornes, montant, puis envoi de la demande.
struct AffiliateWithdrawalForm: View {
    @ObservedObject var controller: AffiliateEarningsController
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Demander un retrait")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)

            if let limits = controller.limits {
                Text("Minimum \(AffiliateFormatting.amount(limits.minimum)) · maximum \(AffiliateFormatting.amount(limits.maximum))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 5)
            }

            AffiliateAmountField(controller: controller, onSubmit: onSubmit)
            submitButton
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var submitButton: some View {
        Button(action: onSubmit) {
            Group {
                if controller.withdrawing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.white)
                } else {
                    Text("Retirer mes gains")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(!controller.canSubmit)
        .opacity(controller.canSubmit ? 1 : 0.42)
        .padding(.top, 14)
    }
}

/// `AffiliateAmountField` : saisie en euros, suffixe « € », raccourci « Tout »,
/// puis erreur de saisie ou rappel du seuil.
struct AffiliateAmountField: View {
    @ObservedObject var controller: AffiliateEarningsController
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                field
                allButton
            }
            .padding(.top, 15)
            guidance
        }
    }

    private var field: some View {
        HStack(spacing: 0) {
            TextField("0,00", text: amountBinding)
                .keyboardType(.decimalPad)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .submitLabel(.done)
                .onSubmit { onSubmit() }
                .disabled(controller.busy)
                .accessibilityLabel("Montant du retrait en euros")
            Text("€")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.ink, lineWidth: 1.5)
        )
    }

    private var allButton: some View {
        Button(action: controller.useAvailableBalance) {
            Text("Tout")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 62, minHeight: 50)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(allDisabled)
        .opacity(allDisabled ? 0.45 : 1)
    }

    /// Message sous la saisie : erreur de saisie prioritaire, sinon le seuil.
    @ViewBuilder
    private var guidance: some View {
        if let invalidText {
            Text(invalidText)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
        } else if let hintText {
            Text(hintText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
    }

    /// `Saisis un montant valide.` quand la saisie n'est pas un montant,
    /// sinon l'erreur de borne ou de solde.
    private var invalidText: String? {
        let trimmed = controller.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && controller.amountMinor == nil { return "Saisis un montant valide." }
        return controller.amountError
    }

    private var hintText: String? {
        guard let wallet = controller.wallet else { return nil }
        return AffiliateCopy.withdrawalHint(wallet)
    }

    private var allDisabled: Bool {
        guard let wallet = controller.wallet else { return true }
        return wallet.availableMinor <= 0 || controller.busy
    }

    /// `onChangeText={controller.setAmount}` : chaque frappe est relue.
    private var amountBinding: Binding<String> {
        Binding(
            get: { controller.amount },
            set: { controller.setAmount($0) }
        )
    }
}

/// `AffiliateWithdrawalHistory` : les virements, du plus récent au plus ancien.
struct AffiliateWithdrawalHistory: View {
    @ObservedObject var controller: AffiliateEarningsController
    let onRetry: (AffWithdrawal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Historique")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)
            if let wallet = controller.wallet {
                if wallet.withdrawals.isEmpty {
                    emptyState
                } else {
                    rows(wallet)
                }
            }
        }
        .padding(.top, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text("Aucun retrait pour le moment.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .padding(.top, 12)
    }

    private func rows(_ wallet: AffWallet) -> some View {
        ForEach(wallet.withdrawals) { withdrawal in
            AffiliateWithdrawalRow(
                withdrawal: withdrawal,
                canRetry: wallet.enabled && AffiliateCopy.canRetry(withdrawal.status),
                busy: controller.busy,
                retrying: controller.retryingId == withdrawal.id,
                onRetry: { onRetry(withdrawal) }
            )
        }
    }
}

/// `AffiliateWithdrawalRow` : un virement, son statut et sa relance.
struct AffiliateWithdrawalRow: View {
    let withdrawal: AffWithdrawal
    let canRetry: Bool
    let busy: Bool
    let retrying: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("VIREMENT")
                    .font(.system(size: 8, weight: .heavy))
                    .kerning(0.7)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.bottom, 4)
                Text(AffiliateFormatting.amount(withdrawal.amountMinor))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(AffiliateFormatting.date(withdrawal.requestedAt))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 3)
                if let failureMessage = withdrawal.failureMessage {
                    Text(failureMessage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 7) {
                Text(AffiliateCopy.withdrawalLabel(withdrawal.status))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 128, alignment: .trailing)
                if canRetry { retryButton }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 10)
    }

    private var retryButton: some View {
        Button(action: onRetry) {
            Group {
                if retrying {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Relancer")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                }
            }
            .frame(minWidth: 68, minHeight: 30)
            .padding(.horizontal, 10)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.45 : 1)
    }
}
