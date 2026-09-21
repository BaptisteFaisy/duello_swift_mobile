import SwiftUI

// MARK: - Carte « code promo »

/// Portage de `src/components/premium-offers/PromoCodeCard.tsx` : la carte
/// placée sous les offres, avec son formulaire et sa ligne de statut.
///
/// absent : `letterSpacing: 0.35` de la saisie — SwiftUI n'expose pas
/// d'espacement de lettres sur un `TextField` (le modificateur `kerning` est
/// réservé à `Text`).
struct PremPromoCodeCard: View {
    @ObservedObject var controller: PremPromoCodeController
    /// Envoi du code : l'appelant fournit le jeton de session.
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PremPromoCodeForm(controller: controller, onSubmit: onSubmit)
            if !controller.feedback.isEmpty {
                PremPromoCodeStatus(
                    message: controller.feedback,
                    success: controller.failure.isEmpty
                )
            }
        }
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Utilisation d’un code promo")
    }
}

/// Le formulaire : saisie en majuscules puis bouton d'application.
struct PremPromoCodeForm: View {
    @ObservedObject var controller: PremPromoCodeController
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Code promo", text: codeBinding)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { if controller.canSubmit { onSubmit() } }
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .accessibilityLabel("Code promo")
                .accessibilityHint("Le code reste uniquement dans ce formulaire.")

            applyButton
        }
    }

    private var applyButton: some View {
        Button(action: onSubmit) {
            Text(controller.submitting ? "Vérification…" : "Appliquer le code")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .opacity(controller.canSubmit ? 1 : 0.42)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canSubmit)
        .accessibilityLabel(
            controller.submitting
                ? "Application du code promo en cours"
                : "Appliquer le code promo"
        )
    }

    /// La saisie passe par `setCode` : chaque frappe est normalisée.
    private var codeBinding: Binding<String> {
        Binding(
            get: { controller.code },
            set: { controller.setCode($0) }
        )
    }
}

/// La ligne de statut : succès en vert Premium, refus en rouge.
struct PremPromoCodeStatus: View {
    let message: String
    let success: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: success ? "checkmark.circle" : "exclamationmark.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(success ? Theme.premium : Theme.like)
            Text(message)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(success ? Theme.premium : Theme.like)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
