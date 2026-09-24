import SwiftUI

// MARK: - Mot de passe

/// Écran « Mot de passe oublié » (voir `ForgotPasswordScreen.tsx`) : saisie de
/// l'adresse e-mail puis demande d'envoi du lien de réinitialisation
/// (`POST /auth/password/reset-request`, même route que
/// `AcctSecPasswordResetForm.sendResetRequest`).
///
/// Thème **sombre** de la source, valeur par valeur : fond `#000000`, texte et
/// icônes `colors.white`, sous-titre `#A3A3A3`, coquille de champ `#0B0B0B`
/// bordée de blanc (1.5), cartes `#151515` bordées de `#333333` (1), bouton
/// blanc à libellé noir. Pas de barre de navigation : la source a une
/// `topBar` avec le `BackButton` (chevron) de retour.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var errorMessage = ""
    @State private var sending = false
    @State private var sent = false

    var body: some View {
        ZStack {
            ForgotPasswordPalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                // `content` de la source : `flexGrow: 1` + `justifyContent:
                // 'center'` — le panneau se centre quand il tient, défile sinon.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            panel
                                .frame(maxWidth: 520, alignment: .leading)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 26)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                }
            }
        }
    }

    // MARK: Barre supérieure

    /// `topBar` (`paddingHorizontal: 22`, `paddingTop: 8`, `paddingBottom: 6`)
    /// et son `BackButton` : chevron blanc 21, zone 44×44 centrée, pictogramme
    /// décalé de −4 (`styles.icon` de `BackButton.tsx`), appui à 60 %.
    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(ForgotPasswordPalette.onDark)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .offset(x: -4)
            }
            .buttonStyle(ForgotPasswordPressStyle(opacity: 0.6))
            .accessibilityLabel("Revenir à la connexion")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: Panneau

    /// `panel` : `maxWidth: 520`, contenu aligné à gauche.
    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MOT DE PASSE OUBLIÉ")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(ForgotPasswordPalette.onDark)

            Text("Retrouve l’accès à ton compte")
                .font(.system(size: 30, weight: .black))
                .tracking(-0.8)
                .lineSpacing(5)
                .foregroundStyle(ForgotPasswordPalette.onDark)
                .padding(.top, 10)

            Text("Indique l’adresse e-mail de ton compte. Tu recevras un lien sécurisé pour choisir un nouveau mot de passe.")
                .font(.system(size: 15))
                .lineSpacing(7)
                .foregroundStyle(ForgotPasswordPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            // `form` : `marginTop: 30`, `gap: 19`.
            form.padding(.top, 30)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 19) {
            emailField
            if sent { sentCard }
            if !errorMessage.isEmpty { errorCard }
            sendButton
        }
    }

    // MARK: Champ e-mail

    /// `fieldGroup` (`gap: 8`) et `fieldShell` : icône `mail-outline` 20
    /// `#A3A3A3`, placeholder `camille@email.fr` `#737373`, saisie 15 regular
    /// blanche, coquille `#0B0B0B` bordée de blanc (1.5), rayon 14.
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ADRESSE E-MAIL")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(ForgotPasswordPalette.onDark)

            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ForgotPasswordPalette.icon)

                TextField("", text: $email, prompt: prompt)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(ForgotPasswordPalette.onDark)
                    .padding(.vertical, 13)
                    .accessibilityLabel("Adresse e-mail du compte")
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 55)
            .background(ForgotPasswordPalette.field)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(ForgotPasswordPalette.onDark, lineWidth: 1.5)
            )
        }
        .onChange(of: email) { _ in
            errorMessage = ""
            sent = false
        }
    }

    /// Texte d'invite coloré comme `placeholderTextColor` de la source.
    private var prompt: Text {
        Text("camille@email.fr").foregroundColor(ForgotPasswordPalette.placeholder)
    }

    // MARK: Cartes

    /// `sentCard` : `alignItems: 'flex-start'`, icône `checkmark-circle-outline`
    /// 20 blanche, texte 12/17 gras.
    private var sentCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ForgotPasswordPalette.onDark)
            Text("Si un compte correspond à cette adresse, tu recevras un e-mail dans quelques instants. Le lien restera valable 30 minutes.")
                .font(.system(size: 12, weight: .bold))
                .lineSpacing(5)
                .foregroundStyle(ForgotPasswordPalette.onDark)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgotPasswordPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(ForgotPasswordPalette.cardBorder, lineWidth: 1)
        )
    }

    /// `errorCard` : `alignItems: 'center'`, icône `alert-circle-outline` 19
    /// blanche, texte 12/17 gras.
    private var errorCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(ForgotPasswordPalette.onDark)
            Text(errorMessage)
                .font(.system(size: 12, weight: .bold))
                .lineSpacing(5)
                .foregroundStyle(ForgotPasswordPalette.onDark)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgotPasswordPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(ForgotPasswordPalette.cardBorder, lineWidth: 1)
        )
    }

    // MARK: Bouton d'envoi

    /// `sendButton` : hauteur 54, `gap: 9`, rayon 18, fond blanc, libellé noir
    /// 15 et flèche `arrow-forward` 20 noire ; désactivé à `opacity: 0.55`.
    private var sendButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 9) {
                Text(sending ? "Envoi…" : (sent ? "Renvoyer le lien" : "Envoyer le lien"))
                Image(systemName: "arrow.forward")
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(DuelloPrimaryButton(onDark: true))
        .disabled(sending)
        .opacity(sending ? 0.55 : 1)
    }

    // MARK: Soumission

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

// MARK: - Palette sombre (voir `ForgotPasswordScreen.tsx`)

/// Valeurs de la source sombre de l'écran. Chaque constante reprend l'hex
/// **exact** du `StyleSheet` de `ForgotPasswordScreen.tsx` (clé en commentaire).
private enum ForgotPasswordPalette {
    /// `safeArea.backgroundColor` (`#000000`).
    static let background = Color.black
    /// `colors.white` : texte et icônes sur fond noir.
    static let onDark = Color.white
    /// `subtitle.color` (`#A3A3A3`).
    static let muted = Color(hex: 0xA3A3A3)
    /// `input.placeholderTextColor` (`#737373`).
    static let placeholder = Color(hex: 0x737373)
    /// Icône de champ (`mail-outline`, `#A3A3A3`).
    static let icon = Color(hex: 0xA3A3A3)
    /// `fieldShell.backgroundColor` (`#0B0B0B`).
    static let field = Color(hex: 0x0B0B0B)
    /// `sentCard`/`errorCard` `backgroundColor` (`#151515`).
    static let card = Color(hex: 0x151515)
    /// `sentCard`/`errorCard` `borderColor` (`#333333`).
    static let cardBorder = Color(hex: 0x333333)
}

/// Appui commun de l'écran : simple baisse d'opacité, sans forme ni fond
/// (le `pressed` du `BackButton`/`AppPressable` de la source).
private struct ForgotPasswordPressStyle: ButtonStyle {
    var opacity: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? opacity : 1)
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
