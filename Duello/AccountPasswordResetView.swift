import SwiftUI

/// Écran « Nouveau mot de passe » (voir `PasswordResetScreen.tsx` et
/// `PasswordResetForm.tsx`) : nouveau mot de passe + confirmation, validés
/// localement. Aucun mot de passe n'est envoyé au serveur par cette version.
struct PasswordResetView: View {
    /// Adresse du compte concerné, affichée en lecture seule.
    var email: String = ""

    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage = ""
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if !email.isEmpty { emailCard }
                    passwordField(title: "Nouveau mot de passe", text: $password)
                    passwordField(title: "Confirme le mot de passe", text: $confirmation)
                    if !errorMessage.isEmpty { errorCard }
                    saveButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Nouveau mot de passe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .alert("Mot de passe enregistré", isPresented: $showConfirmation) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Ton nouveau mot de passe a bien été enregistré.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nouveau mot de passe")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink)
            Text("Choisis ton nouveau mot de passe")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Theme.ink)
        }
    }

    /// Champ local (`PasswordResetForm.tsx:57-101`) : légende 13/800
    /// `Theme.ink`, icône `key-outline` 20, placeholder = libellé, bordure 1.5
    /// `Theme.border`, fond `Theme.surface`. La bascule œil de la source n'est
    /// pas reprise ici (changement de comportement non spécifié).
    private func passwordField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                Image(systemName: "key")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)

                SecureField(title, text: text)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 55)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1.5)
            )
        }
    }

    private var emailCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adresse e-mail")
                .font(.system(size: 12, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            Text(email)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
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

    private var saveButton: some View {
        Button {
            submit()
        } label: {
            Text("Enregistrer")
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
    }

    private func submit() {
        guard isValidNewPassword(password) else {
            errorMessage = newPasswordPolicyMessage
            return
        }
        guard password == confirmation else {
            errorMessage = "Les deux mots de passe ne correspondent pas."
            return
        }
        errorMessage = ""
        showConfirmation = true
    }
}

/// Politique de mot de passe de l'app Expo : entre 8 et 128 caractères
/// (`shared/new-password-policy.mjs`, bornes vérifiées par
/// `newPasswordPolicy.test.ts`).
private let newPasswordPolicyMessage = "Le mot de passe doit contenir entre 8 et 128 caractères."

/// Bornes de la politique de mot de passe Expo.
private func isValidNewPassword(_ value: String) -> Bool {
    value.count >= 8 && value.count <= 128
}

/// Contrôle d'adresse minimal, aligné sur `validEmail` de
/// `ForgotPasswordScreen.tsx` : au plus 320 caractères, sans espace, de la
/// forme `local@domaine.tld`.
private func isPlausibleEmail(_ value: String) -> Bool {
    guard !value.isEmpty, value.count <= 320 else { return false }
    guard !value.contains(where: { $0.isWhitespace }) else { return false }
    let parts = value.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty else { return false }
    let domain = parts[1]
    guard let dot = domain.firstIndex(of: ".") else { return false }
    let afterDot = domain.index(after: dot)
    return dot != domain.startIndex && afterDot < domain.endIndex
}
