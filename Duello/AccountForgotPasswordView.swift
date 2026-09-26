import SwiftUI

// MARK: - Mot de passe

/// Écran « Mot de passe oublié » (voir `ForgotPasswordScreen.tsx`) : saisie de
/// l'adresse e-mail puis demande d'envoi du lien de réinitialisation
/// (`POST /auth/password/reset-request`, même route que
/// `AcctSecPasswordResetForm.sendResetRequest`).
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var errorMessage = ""
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    emailField
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
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
            Text("Retrouve l’accès à ton compte")
                .font(.system(size: 30, weight: .black))
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
            Text("Indique l’adresse e-mail de ton compte. Tu recevras un lien sécurisé pour choisir un nouveau mot de passe.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(Color(hex: 0xA3A3A3))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Champ local (`ForgotPasswordScreen.tsx:128-153`) : légende 13/800
    /// `Theme.ink`, icône `mail-outline` 20, placeholder `camille@email.fr`,
    /// libellé d'accessibilité « Adresse e-mail du compte ». Le thème sombre de
    /// la source (écart de thème) n'est pas repris ici.
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adresse e-mail")
                .font(.system(size: 13, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)

                TextField("camille@email.fr", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Adresse e-mail du compte")
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 55)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(Theme.ink, lineWidth: 1.5)
            )
        }
        .onChange(of: email) { _ in
            errorMessage = ""
            sent = false
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
            HStack(spacing: 9) {
                Text(sending ? "Envoi…" : (sent ? "Renvoyer le lien" : "Envoyer le lien"))
                Image(systemName: "arrow.forward")
                    .font(.system(size: 20, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(sending)
    }

    private func submit() {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard AcctSecEmailValidation.isPlausibleEmail(normalized) else {
            sent = false
            errorMessage = "Saisis une adresse e-mail valide."
            return
        }
        errorMessage = ""
        sent = false
        sending = true
        Task {
            defer { sending = false }
            do {
                try await AcctSecForgotPasswordAPI.requestReset(email: normalized)
                email = normalized
                sent = true
            } catch {
                errorMessage = Self.message(
                    for: error,
                    fallback: "Impossible d’envoyer l’e-mail pour le moment."
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

/// `POST /auth/password/reset-request` — helper local (`DuelloAPI.swift` n'est
/// pas modifié ; même route que `AcctSecPasswordResetForm.sendResetRequest`).
private enum AcctSecForgotPasswordAPI {
    static func requestReset(email: String) async throws {
        let body = try DuelloAPI.encodeBody(["email": email])
        let data = try await DuelloAPI.request(
            "auth/password/reset-request",
            method: "POST",
            body: body
        )
        let payload = try? DuelloAPI.decoder.decode(AcctSecForgotPasswordResponse.self, from: data)
        guard payload?.accepted == true else {
            throw DirectoryError(message: "La réponse du service de mot de passe est invalide.")
        }
    }
}

/// Réponse de `POST /auth/password/reset-request` (voir
/// `AcctSecResetRequestResponse`).
private struct AcctSecForgotPasswordResponse: Decodable {
    var accepted: Bool?
}
