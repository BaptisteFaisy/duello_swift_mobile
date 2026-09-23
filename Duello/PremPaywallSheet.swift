import SwiftUI

// MARK: - Feuille de paiement Premium

/// Portage de `src/components/PaywallContent.tsx` : la présentation unique de
/// l'offre Premium, réutilisée telle quelle par la section « Premium » des
/// réglages et par la fenêtre ouverte depuis un outil Premium.
///
/// L'enveloppe (fond assombri, marges, défilement) reste à la charge de
/// l'appelant : `PremToolPaywallHost` la monte en feuille, `PremiumView`
/// l'affiche en ligne sous sa barre de navigation.
struct PremPaywallSheet: View {
    /// Explication affichée lorsque l'ouverture vient d'un outil Premium.
    var notice: String? = nil
    /// Quota de corrections du compte ; absent lorsque la fenêtre sert de
    /// simple porte de paiement.
    var quota: PremQuotaSnapshot? = nil
    /// Jeton de session, transmis à la carte « code promo ».
    var token: String? = nil
    /// Fermeture ; absente quand l'appelant ferme autrement (feuille tirée,
    /// barre de navigation).
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusCard
            PremOffersSection(token: token)
        }
    }

    /// `DUELLO PREMIUM` / « Passe en illimité », et la croix de fermeture
    /// quand la feuille en porte une.
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DUELLO PREMIUM")
                    .font(.system(size: 10, weight: .black))
                    .kerning(1.2)
                    .foregroundStyle(Theme.inkSoft)
                Text("Passe en illimité")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer")
            }
        }
    }

    /// La ligne d'état : l'explication d'un outil Premium prime, sinon le quota
    /// de défis gratuits — jamais pour un compte déjà abonné.
    @ViewBuilder
    private var statusCard: some View {
        if let notice {
            PremNoticeCard(icon: "lock", message: notice)
        } else if let quota, !quota.subscribed {
            PremNoticeCard(icon: "bolt", message: quota.remainingLabel)
        }
    }
}

/// Carte d'état de la feuille : icône Premium et texte, encadré sur fond gris.
struct PremNoticeCard: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.premium)
            Text(message)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
