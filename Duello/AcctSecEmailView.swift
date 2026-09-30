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

    /// Adresse telle que la source la passe au formulaire (`email` de
    /// `AccountEmailScreen.tsx`) : le paramètre explicite prime, sinon le profil.
    private var sourceEmail: String { initialEmail ?? session.profile.email }

    var body: some View {
        // `contentContainerStyle` de la source (`AccountEmailScreen.tsx:107-113`) :
        // `flexGrow: 1` (contenu à au moins la hauteur visible), `formArea` centré
        // verticalement (`justifyContent: 'center'`, 82 % / 420), le bouton
        // d'envoi restant collé au bas (`marginTop: 'auto'`).
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    backButton
                    Spacer(minLength: 0)
                    form
                        .frame(width: min((proxy.size.width - 40) * 0.82, 420))
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .onAppear {
            if nextEmail.isEmpty { nextEmail = sourceEmail }
        }
        // `useEffect(() => setNextEmail(email), [email])` de la source : la
        // saisie reprend la valeur passée dès que celle-ci change.
        .onChange(of: initialEmail) { _ in nextEmail = sourceEmail }
    }

    // MARK: Sous-vues

    /// `BackButton` « Retour aux paramètres » : chevron `chevron-back` 20 encre,
    /// sans graisse, centré dans une boîte 40 × 40 puis décalé de -4 pt, cible
    /// tactile élargie de 8 pt (`BackButton.tsx:61-95`). `AccountEmailScreen.tsx`
    /// n'a pas de barre de navigation : le chevron est en tête de contenu.
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            IonIcon(name: "chevron-back", size: 20, color: Theme.ink)
                .offset(x: -4)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .padding(8)
                .contentShape(Rectangle())
                .padding(-8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour aux paramètres")
    }

    /// Formulaire (`form` de la source) : légende, champ à icône `mail-outline`
    /// 20, message d'erreur. La largeur 82 % / 420 est posée par `body`.
    private var form: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nouvelle adresse e-mail")
                .font(.system(size: 12, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                IonIcon(name: "mail-outline", size: 20, color: Theme.inkSoft)

                TextField("", text: $nextEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    // `input` (`AccountEmailScreen.tsx:135`) : 14, sans graisse (400).
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .onSubmit { submit() }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(Theme.ink, lineWidth: 1.5)
            )

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: nextEmail) { _ in errorMessage = "" }
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
        // `submitButton.borderRadius: radii.medium` (14) de `AccountEmailScreen.tsx:142`,
        // là où `DuelloPrimaryButton` (partagé) pose `radii.large` (18).
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
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
