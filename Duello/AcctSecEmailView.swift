import SwiftUI

/// Écran « Nouvelle adresse e-mail » du compte.
///
/// Porté de `src/screens/AccountEmailScreen.tsx` : saisie de l'adresse, contrôle
/// minimal `^\S+@\S+\.\S+$`, refus d'une adresse identique à l'actuelle, états
/// d'enregistrement et d'erreur, libellés repris mot pour mot.
///
/// Le changement passe par `POST /auth/email/change` (`changeServerEmail` de
/// `src/utils/serverSession.ts`). Cet endpoint n'est pas exposé par
/// `DuelloAPIAccount.swift` : il est replié dans le helper local
/// `AcctSecEmailAPI`, conformément au brief (pas d'édition de `DuelloAPI.swift`).
///
/// Limite assumée : la source Expo n'a **aucune** étape de « code de
/// vérification » — le serveur renvoie directement une session. Ce portage s'en
/// tient donc à la saisie et aux états. Le jeton de session rafraîchi par le
/// serveur n'est pas persisté (`SessionStore.session` est `private(set)` et
/// `SessionStore.swift` est hors périmètre) ; seul l'e-mail du profil est mis à
/// jour.
struct AcctSecEmailView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    /// Adresse de départ ; par défaut celle du profil connecté.
    var initialEmail: String? = nil

    @State private var nextEmail = ""
    @State private var errorMessage = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    DuelloTextField(
                        title: "Nouvelle adresse e-mail",
                        text: $nextEmail,
                        textContentType: .emailAddress,
                        keyboard: .emailAddress
                    )
                    .onChange(of: nextEmail) { _ in errorMessage = "" }

                    if !errorMessage.isEmpty { errorCard }
                    saveButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Adresse e-mail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                if nextEmail.isEmpty { nextEmail = initialEmail ?? session.profile.email }
            }
        }
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
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Enregistrer")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(isSaving)
    }

    // MARK: Soumission

    /// Adresse actuelle normalisée, telle que comparée par la source Expo.
    private var currentEmail: String {
        (initialEmail ?? session.profile.email)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func submit() {
        let normalized = nextEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValidEmail(normalized) else {
            errorMessage = "Saisis une adresse e-mail valide."
            return
        }
        guard normalized != currentEmail else {
            errorMessage = "Saisis une nouvelle adresse e-mail."
            return
        }
        isSaving = true
        errorMessage = ""
        Task {
            defer { isSaving = false }
            do {
                try await AcctSecEmailAPI.change(email: normalized, token: session.token)
                session.profile.email = normalized
                session.persistProfile()
                dismiss()
            } catch {
                errorMessage = Self.message(
                    for: error,
                    fallback: "Impossible de modifier l’adresse e-mail."
                )
            }
        }
    }

    /// Contrôle d'adresse minimal de la source : `^\S+@\S+\.\S+$`.
    private static func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
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

/// `POST /auth/email/change` — helper local (`DuelloAPIAccount.swift` n'expose
/// pas ce point d'entrée ; voir `changeServerEmail` de `serverSession.ts`).
private enum AcctSecEmailAPI {
    static func change(email: String, token: String?) async throws {
        let body = try DuelloAPI.encodeBody(["email": email])
        let response = try await DuelloAPI.request(
            DuelloAPI.AuthResponse.self,
            "auth/email/change",
            method: "POST",
            token: token,
            body: body
        )
        guard response.session != nil else {
            throw DirectoryError(message: "Impossible de modifier l’adresse e-mail.")
        }
    }
}
