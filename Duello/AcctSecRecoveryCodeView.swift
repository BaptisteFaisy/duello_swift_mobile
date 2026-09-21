import SwiftUI

// Vue du code de secours — portée depuis `src/components/RecoveryCodeModal.tsx`
// et son usage dans `src/screens/LoginScreen.tsx` (titre et description par
// défaut repris mot pour mot).
//
// L'appareil n'envoie aucun courriel : ce code est le seul moyen de rouvrir un
// compte administrateur dont le mot de passe est oublié. Il n'est donc affiché
// qu'une fois — le compte n'en garde que l'empreinte — et la carte reste
// bloquante jusqu'à l'accusé de réception. La copie passe par le
// presse-papiers système.

/// Carte de remise du code de secours : le code en clair, un avertissement, la
/// copie et le bouton d'accusé de réception.
struct AcctSecRecoveryCodeView: View {
    /// Code en clair, affiché une seule fois.
    let code: String
    var title: String = "Nouveau code de secours administrateur"
    var description: String = "Il remplace le précédent, qui ne fonctionne plus. Il est réservé à la récupération du compte administrateur."
    var onDismiss: () -> Void = {}

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            iconShell
            Text(title)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(description)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            codeShell
            warning
            copyButton
            dismissButton
        }
        .padding(22)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(22)
    }

    private var iconShell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15).fill(Theme.primaryLight)
            Image(systemName: "key")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .frame(width: 44, height: 44)
    }

    private var codeShell: some View {
        Text(code)
            .font(.system(size: 20, weight: .black, design: .monospaced))
            .tracking(2)
            .foregroundStyle(Theme.ink)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .padding(.horizontal, 12)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1.5)
            )
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Ce code ne sera plus affiché. Note-le hors de l’application.")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    private var copyButton: some View {
        Button {
            copyCode()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .bold))
                Text(copied ? "Code copié" : "Copier le code")
                    .font(.system(size: 14, weight: .heavy))
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(Theme.ink)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var dismissButton: some View {
        Button {
            onDismiss()
        } label: {
            Text("J’ai noté ce code")
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
    }

    private func copyCode() {
        UIPasteboard.general.string = code
        copied = true
    }
}
