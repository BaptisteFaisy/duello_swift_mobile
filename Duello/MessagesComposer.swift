import SwiftUI

// MARK: - Champ de saisie

/// Barre de saisie avec bouton d'envoi, style de la `Composer` d'Expo.
struct ComposerBar: View {
    let placeholder: String
    @Binding var text: String
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("", text: $text, axis: .vertical)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...5)
                .padding(.vertical, 9)
                .frame(minHeight: 38, alignment: .leading)
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.inkFaint)
                            .allowsHitTesting(false)
                    }
                }

            Button(action: onSend) {
                IonIcon(name: "arrow-up", size: 19, color: Theme.surface)
                    .frame(width: 40, height: 40)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.35)
            .accessibilityLabel("Envoyer")
        }
        .padding(.vertical, 7)
        .padding(.leading, 14)
        .padding(.trailing, 7)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
