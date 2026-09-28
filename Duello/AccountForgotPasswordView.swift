import SwiftUI

// MARK: - Mot de passe

/// Écran « Mot de passe oublié » (voir `ForgotPasswordScreen.tsx`) : saisie de
/// l'adresse e-mail puis demande d'envoi du lien de réinitialisation
/// (`POST /auth/password/reset-request`, `requestServerPasswordReset` de
/// `passwordResetApi.ts:10-19`).
///
/// R1-AUTH (U03#1) — 2026-09-27 : l'écran est présenté depuis la connexion
/// (`LoginIntAssembly`, `onOpenPasswordReset`), comme `App.tsx:2524-2531`. La
/// prop `initialEmail` (adresse saisie dans la connexion) préremplit le champ,
/// comme `useState(initialEmail.trim().toLowerCase())` de la source.
///
/// U03 — 2026-09-28 : parité exacte avec la source — l'écran est **noir**
/// (`safeArea backgroundColor '#000000'`, texte blanc, cartes `#151515` bordées
/// `#333333`, champ `#0B0B0B` bordé de blanc), comme le reste de l'auth
/// (`LoginScrPalette`, `LoginScrFields.swift`) ; chevron de retour
/// `chevron-back` 21 blanc en haut à gauche (`BackButton`) ; icônes Ionicons
/// (`IonIcon`) ; centrage vertical (`justifyContent: 'center'`) ; marges 22 ;
/// rayon 14 ; interlignes 35/22/17 ; corps du POST `{ email, destination }`.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var errorMessage = ""
    @State private var sending = false
    @State private var sent = false

    /// Adresse préremplie (normalisée : minuscules, sans espaces).
    init(initialEmail: String = "") {
        _email = State(
            initialValue: initialEmail
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        )
    }

    var body: some View {
        ZStack {
            LoginScrPalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                // `scrollContent` de la source : `flexGrow: 1` +
                // `justifyContent: 'center'` — le panneau se centre quand il
                // tient et défile sinon. `automaticallyAdjustKeyboardInsets`
                // et `KeyboardAvoidingView` (behavior `padding`) sont repris
                // par l'ajustement clavier natif de `ScrollView`.
                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            panel
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                    // `keyboardShouldPersistTaps="handled"` / `keyboardDismissMode`
                    // par défaut (`'none'`) : le clavier reste à l'écran.
                    .scrollDismissesKeyboard(.never)
                }
            }
        }
    }

    /// `topBar` de la source (`:67-75`, `:170`) : chevron `chevron-back` 21
    /// blanc, `iconColor={colors.white}`, `iconSize={21}`, icône décalée de -4
    /// (`BackButton.tsx:93`), zone tactile 44×44 (`styles.backButton`),
    /// `paddingHorizontal: 22`, `paddingTop: 8`, `paddingBottom: 6`.
    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                IonIcon(name: "chevron-back", size: 21, color: LoginScrPalette.onDark)
                    .offset(x: -4)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Revenir à la connexion")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// `content` + `panel` de la source (`:178-184`) : panneau largeur 100 %,
    /// `maxWidth: 520`, centré, `paddingHorizontal: 22`, `paddingVertical: 26` ;
    /// l'en-tête est le bloc eyebrow/titre/sous-titre (styles identiques à
    /// `LoginScreen.tsx:729-738`, porté par `LoginScrEyebrowHeader`), et le
    /// formulaire suit à `marginTop: 30` (`form`, `gap: 19`).
    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScrEyebrowHeader(
                eyebrow: "MOT DE PASSE OUBLIÉ",
                title: "Retrouve l’accès à ton compte",
                subtitle: "Indique l’adresse e-mail de ton compte. Tu recevras un lien sécurisé pour choisir un nouveau mot de passe."
            )
            VStack(alignment: .leading, spacing: 19) {
                emailField
                if sent { sentCard }
                if !errorMessage.isEmpty { errorCard }
                sendButton
            }
            .padding(.top, 30)
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
    }

    /// `EmailField` + `fieldShell` de la source (`:128-153`, `:196-209`) :
    /// légende 13/800 blanche, enveloppe `mail-outline` 20 `#A3A3A3`, coquille
    /// `#0B0B0B` bordée de blanc (1.5), rayon `radii.medium` (14), `minHeight`
    /// 55, placeholder `camille@email.fr` teinté `#737373`.
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adresse e-mail")
                .font(.system(size: 13, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(LoginScrPalette.onDark)

            HStack(spacing: 10) {
                IonIcon(name: "mail-outline", size: 20, color: LoginScrPalette.icon)

                TextField(
                    "",
                    text: $email,
                    prompt: Text("camille@email.fr")
                        .foregroundColor(LoginScrPalette.placeholder)
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15))
                .foregroundStyle(LoginScrPalette.onDark)
                .padding(.vertical, 13)
                .accessibilityLabel("Adresse e-mail du compte")
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 55)
            .background(LoginScrPalette.field)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(LoginScrPalette.onDark, lineWidth: 1.5)
            )
        }
        .onChange(of: email) { _ in
            errorMessage = ""
            sent = false
        }
    }

    /// `SentMessage` de la source (`:156-165`, `:210-220`) :
    /// `checkmark-circle-outline` 20 blanc, texte 12/700 interligne 17, carte
    /// `#151515` bordée `#333333`, rayon `radii.medium`, `alignItems:
    /// 'flex-start'`, `gap: 10`, `padding: 13`.
    private var sentCard: some View {
        HStack(alignment: .top, spacing: 10) {
            IonIcon(name: "checkmark-circle-outline", size: 20, color: LoginScrPalette.onDark)
            Text("Si un compte correspond à cette adresse, tu recevras un e-mail dans quelques instants. Le lien restera valable 30 minutes.")
                .font(.system(size: 12, weight: .bold))
                .lineSpacing(5)
                .foregroundStyle(LoginScrPalette.onDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LoginScrPalette.errorCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(LoginScrPalette.errorCardBorder, lineWidth: 1)
        )
    }

    /// `errorCard` de la source (`:102-107`, `:221-231`) :
    /// `alert-circle-outline` 19 blanc, texte 12/700 interligne 17, carte
    /// `#151515` bordée `#333333`, rayon `radii.medium`, `alignItems:
    /// 'center'`, `gap: 10`, `padding: 13`.
    private var errorCard: some View {
        HStack(alignment: .center, spacing: 10) {
            IonIcon(name: "alert-circle-outline", size: 19, color: LoginScrPalette.onDark)
            Text(errorMessage)
                .font(.system(size: 12, weight: .bold))
                .lineSpacing(5)
                .foregroundStyle(LoginScrPalette.onDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LoginScrPalette.errorCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(LoginScrPalette.errorCardBorder, lineWidth: 1)
        )
    }

    /// `Pressable` + `sendButton` de la source (`:108-122`, `:232-243`) : blanc
    /// plein, rayon 18, hauteur 54, libellé noir 15/900, flèche `arrow-forward`
    /// 20 `#000000`, `gap: 9`. `AppPressable` fige l'état repos
    /// (`RESTING_PRESS_STATE`) → **aucun** retour d'appui ; l'état désactivé
    /// (`styles.disabled`, opacité **0.55**) est porté par l'opacité.
    private var sendButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 9) {
                Text(sending ? "Envoi…" : (sent ? "Renvoyer le lien" : "Envoyer le lien"))
                IonIcon(name: "arrow-forward", size: 20, color: .black)
            }
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        }
        .buttonStyle(.plain)
        .disabled(sending)
        .opacity(sending ? 0.55 : 1)
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
                let localized = (error as? LocalizedError)?.errorDescription
                errorMessage = localized ?? "Impossible d’envoyer l’e-mail pour le moment."
            }
        }
    }
}

/// `POST /auth/password/reset-request` — helper local (`DuelloAPI.swift` n'est
/// pas modifié).
private enum AcctSecForgotPasswordAPI {
    static func requestReset(email: String) async throws {
        // Corps `{ email, destination }` (`passwordResetApi.ts:11-19`) ;
        // `destination` vaut `'app'` hors web (`App.tsx:2527-2530` :
        // `Platform.OS === 'web' ? 'web' : 'app'`).
        let body = try DuelloAPI.encodeBody(["email": email, "destination": "app"])
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

/// Réponse de `POST /auth/password/reset-request` (voir `PasswordResetResponse`
/// de `passwordResetHttp.ts`).
private struct AcctSecForgotPasswordResponse: Decodable {
    var accepted: Bool?
}
