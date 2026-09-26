import SwiftUI

// MARK: - Retour utilisateur

/// Écran « Un bug ? » : retour d'un élève vers l'équipe Duello.
/// Reprend `FeedbackScreen.tsx` : aucun titre de navigation, chevron de retour
/// en tête de contenu, champs SUJET et MESSAGE, carte d'erreur d'envoi et bouton
/// « Envoyer mon message ». L'envoi reste local — aucune requête réseau n'est
/// émise par cette vue.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage = ""
    @State private var showConfirmation = false

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                backButton
                formCard
                if !errorMessage.isEmpty { errorCard }
                sendButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .alert("Message envoyé", isPresented: $showConfirmation) {
            Button("OK") { resetForm() }
        } message: {
            Text("Ton retour a bien été transmis à l’équipe Duello. Merci pour ta contribution !")
        }
    }

    /// Chevron de retour : la source n'a ni titre de navigation ni « Fermer ».
    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour aux paramètres")
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(title: "SUJET") {
                TextField("Ex: Problème de synchronisation", text: $subject)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .stroke(Theme.ink, lineWidth: 1.5)
                    )
            }
            field(title: "MESSAGE") {
                TextField("Décris ton retour en détail...", text: $message, axis: .vertical)
                    .lineLimit(6...12)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .stroke(Theme.ink, lineWidth: 1.5)
                    )
            }
        }
    }

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(errorMessage)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var sendButton: some View {
        Button(action: submit) {
            HStack(spacing: 10) {
                if isSending {
                    ProgressView().tint(Theme.surface)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Envoyer mon message")
                }
            }
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(!canSend)
        .opacity(canSend ? 1 : 0.5)
    }

    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
            content()
        }
        .padding(.vertical, 4)
    }

    /// Envoi local : confirmation puis remise à zéro de SUJET et MESSAGE au OK.
    private func submit() {
        guard canSend else { return }
        isSending = true
        errorMessage = ""
        Task { @MainActor in
            isSending = false
            showConfirmation = true
        }
    }

    private func resetForm() {
        subject = ""
        message = ""
    }
}
