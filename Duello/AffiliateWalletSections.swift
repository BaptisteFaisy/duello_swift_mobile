import SwiftUI

// MARK: - Sections du portefeuille affilié
//
// Portage de `src/features/affiliate/AffiliateWalletSections.tsx` (en-tête,
// état de chargement, avis, pastille de mode, solde, code d'affiliation, carte
// Stripe) avec les mesures de
// `src/features/affiliate/affiliateEarningsStyles.ts`.
//
// La source anime l'arrivée des cartes (`Animated`) ; ici elles sont rendues
// directement : aucune information ne dépend de l'animation.

/// `AffiliateScreenHeader` : retour, actualisation et titre « AFFILIATION ».
struct AffiliateScreenHeader: View {
    let onBack: () -> Void
    let refreshing: Bool
    let refreshDisabled: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 0) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retour aux paramètres")

                Spacer(minLength: 0)
                refreshButton
            }
            .frame(minHeight: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text("AFFILIATION")
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(1.1)
                    .foregroundStyle(Theme.inkSoft)
                Text("Mes gains")
                    .font(.system(size: 30, weight: .heavy))
                    .kerning(-0.8)
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 14)
    }

    private var refreshButton: some View {
        Button(action: onRefresh) {
            Group {
                if refreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .frame(width: 40, height: 40)
            .background(Theme.surfaceMuted)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(refreshDisabled)
        .accessibilityLabel("Actualiser mon solde affilié")
    }
}

/// `AffiliateNotice` : bandeau d'information, d'alerte ou d'échec, avec action
/// facultative (« Réessayer » sur l'échec de chargement).
struct AffiliateNotice: View {
    let message: String
    let icon: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}

/// `AffiliateLoadState` : chargement initial, puis échec avec « Réessayer ».
struct AffiliateLoadState: View {
    let loading: Bool
    let hasWallet: Bool
    let loadError: String?
    let onRetry: () -> Void

    var body: some View {
        if loading && !hasWallet {
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Chargement du solde…")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        } else if let loadError = loadError, !hasWallet {
            AffiliateNotice(
                message: loadError,
                icon: "icloud.slash",
                actionLabel: "Réessayer",
                action: onRetry
            )
        }
    }
}

/// `AffiliateModePill` : mention « SIMULATION » ou « MODE TEST ».
struct AffiliateModePill: View {
    let wallet: AffWallet

    var body: some View {
        if wallet.mode == .sandbox || wallet.simulated {
            Text(wallet.simulated ? "SIMULATION" : "MODE TEST")
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.8)
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Theme.surfaceMuted)
                .clipShape(Capsule())
        }
    }
}

/// `AffiliateBalanceCard` : disponible, en cours de versement, déjà versé.
struct AffiliateBalanceCard: View {
    let wallet: AffWallet

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DISPONIBLE")
                .font(.system(size: 10, weight: .heavy))
                .kerning(1)
                .foregroundStyle(Theme.inkFaint)
            Text(AffiliateFormatting.amount(wallet.availableMinor))
                .font(.system(size: 34, weight: .heavy))
                .kerning(-1)
                .foregroundStyle(Color.white)
                .padding(.top, 5)

            HStack(alignment: .top, spacing: 0) {
                detail("En cours", value: wallet.reservedMinor)
                Rectangle()
                    .fill(Theme.inkSoft)
                    .frame(width: 1)
                    .padding(.horizontal, 18)
                detail("Déjà versé", value: wallet.paidMinor)
            }
            .padding(.top, 20)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
    }

    private func detail(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
            Text(AffiliateFormatting.amount(value))
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `AffiliatePublicIdCard` : code d'affiliation visible et copiable.
struct AffiliatePublicIdCard: View {
    let publicId: String
    let copied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TON CODE D’AFFILIATION")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(Theme.inkSoft)
                Text(publicId)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                Text("Partage ce code. Après son enregistrement, chaque paiement Premium hebdomadaire ou annuel validé te rapporte \(AffiliateCopy.paymentRewardLabel).")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onCopy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copier mon code d’affiliation")
        }
        .padding(14)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}

/// `AffiliateStripeCard` : état du compte Stripe Connect et son action.
struct AffiliateStripeCard: View {
    let copy: AffConnectionCopy
    let enabled: Bool
    let busy: Bool
    let opening: Bool
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: copy.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 5) {
                    Text(copy.title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(copy.detail)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if enabled, let actionLabel = copy.actionLabel {
                actionButton(actionLabel)
            }
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

    private func actionButton(_ label: String) -> some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                if opening {
                    ProgressView().controlSize(.small)
                } else {
                    Text(label)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.45 : 1)
        .padding(.top, 15)
        .accessibilityLabel(label)
    }
}
