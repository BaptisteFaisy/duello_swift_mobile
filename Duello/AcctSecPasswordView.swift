import SwiftUI

/// Écran « Nouveau mot de passe » du compte.
///
/// Porté de `src/screens/AccountPasswordScreen.tsx` (champ unique, bascule
/// d'affichage œil, politique de robustesse) et de
/// `src/components/PasswordResetForm.tsx` (champ « Confirme le mot de passe »).
/// Politique alignée sur `shared/new-password-policy.mjs` : 8 à 128 caractères.
///
/// Le changement passe par `POST /auth/password/change` (`changeServerPassword`
/// de `src/utils/serverSession.ts`), replié dans le helper local
/// `AcctSecPasswordAPI`.
///
/// Limite assumée : la source Expo ne demande **pas** le mot de passe actuel et
/// l'endpoint n'accepte que le nouveau (`{ password }`). Un champ « actuel »
/// serait donc une saisie non vérifiée côté serveur : il est volontairement
/// omis plutôt que simulé.
struct AcctSecPasswordView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmation = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AcctSecPasswordField(
                        title: "Nouveau mot de passe",
                        text: $password,
                        isVisible: showPassword,
                        onToggle: { showPassword.toggle() }
                    )
                    .onChange(of: password) { _ in errorMessage = "" }

                    AcctSecPasswordField(
                        title: "Confirme le mot de passe",
                        text: $confirmation,
                        isVisible: showPassword
                    )
                    .onChange(of: confirmation) { _ in errorMessage = "" }

                    if !errorMessage.isEmpty { errorCard }
                    saveButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Mot de passe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: Politique de mot de passe (voir `new-password-policy.mjs`)

    /// Message annonçant les deux bornes, repris mot pour mot de la source.
    static let policyMessage = "Le mot de passe doit contenir entre 8 et 128 caractères."

    static func isValidNewPassword(_ value: String) -> Bool {
        value.count >= 8 && value.count <= 128
    }

    // MARK: Sous-vues

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
            Text(isSaving ? "Enregistrement…" : "Enregistrer")
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(isSaving)
    }

    // MARK: Soumission

    private func submit() {
        guard Self.isValidNewPassword(password) else {
            errorMessage = Self.policyMessage
            return
        }
        guard password == confirmation else {
            errorMessage = "Les deux mots de passe ne correspondent pas."
            return
        }
        isSaving = true
        errorMessage = ""
        Task {
            defer { isSaving = false }
            do {
                try await AcctSecPasswordAPI.change(password: password, token: session.token)
                dismiss()
            } catch {
                errorMessage = Self.message(
                    for: error,
                    fallback: "Impossible de modifier le mot de passe."
                )
            }
        }
    }

    /// Message d'erreur : celui du serveur s'il est localisable, sinon le repli
    /// de la source Expo.
    private static func message(for error: Error, fallback: String) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return fallback
    }
}

/// Champ de mot de passe avec bascule d'affichage (œil), comme
/// `AccountPasswordScreen.tsx`. Privé à ce fichier.
private struct AcctSecPasswordField: View {
    let title: String
    @Binding var text: String
    let isVisible: Bool
    var onToggle: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)

            HStack(spacing: 10) {
                Image(systemName: "key")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)

                Group {
                    if isVisible {
                        TextField("", text: $text)
                    } else {
                        SecureField("", text: $text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)

                if let onToggle {
                    Button(action: onToggle) {
                        Image(systemName: isVisible ? "eye.slash" : "eye")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .accessibilityLabel(isVisible ? "Masquer le mot de passe" : "Afficher le mot de passe")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

/// `POST /auth/password/change` — helper local (`DuelloAPIAccount.swift`
/// n'expose pas ce point d'entrée ; voir `changeServerPassword`).
private enum AcctSecPasswordAPI {
    static func change(password: String, token: String?) async throws {
        let body = try DuelloAPI.encodeBody(["password": password])
        let response = try await DuelloAPI.request(
            DuelloAPI.AuthResponse.self,
            "auth/password/change",
            method: "POST",
            token: token,
            body: body
        )
        guard response.session != nil else {
            throw DirectoryError(message: "Impossible de modifier le mot de passe.")
        }
    }
}
