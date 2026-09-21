import SwiftUI

// MARK: - Mot de passe

/// Écran « Mot de passe oublié » (voir `ForgotPasswordScreen.tsx`) : saisie de
/// l'adresse e-mail puis confirmation locale. Aucun e-mail n'est réellement
/// expédié par cette version.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var errorMessage = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    DuelloTextField(
                        title: "Adresse e-mail",
                        text: $email,
                        textContentType: .emailAddress,
                        keyboard: .emailAddress
                    )
                    .onChange(of: email) { _ in
                        errorMessage = ""
                        sent = false
                    }
                    if sent { sentCard }
                    if !errorMessage.isEmpty { errorCard }
                    sendButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mot de passe oublié")
                .font(.system(size: 11, weight: .black))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
            Text("Retrouve l’accès à ton compte")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Indique l’adresse e-mail de ton compte. Tu recevras un lien sécurisé pour choisir un nouveau mot de passe.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sentCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.progress)
            Text("Si un compte correspond à cette adresse, tu recevras un e-mail dans quelques instants. Le lien restera valable 30 minutes.")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.like)
            Text(errorMessage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var sendButton: some View {
        Button {
            submit()
        } label: {
            Text(sent ? "Renvoyer le lien" : "Envoyer le lien")
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
    }

    private func submit() {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isPlausibleEmail(normalized) else {
            sent = false
            errorMessage = "Saisis une adresse e-mail valide."
            return
        }
        errorMessage = ""
        sent = true
    }
}
