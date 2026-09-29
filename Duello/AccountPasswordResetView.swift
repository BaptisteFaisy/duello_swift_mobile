import SwiftUI

/// Écran « Nouveau mot de passe » (voir `PasswordResetScreen.tsx` et
/// `PasswordResetForm.tsx`) : nouveau mot de passe + confirmation. Le mot de
/// passe est envoyé au serveur (`AcctSecResetTransport.resetServerPassword`,
/// port de `resetServerPassword` de `passwordResetApi.ts`) et la session
/// ouverte est remise à l'appelant.
///
/// R1-AUTH (U04#1, U04#2) — 2026-09-27 : c'est le **seul** écran de
/// réinitialisation, ouvert par le lien entrant (`DuelloApp.onOpenURL` →
/// `PasswordResetView(email:token:)`, `App.tsx:2460-2478`). Le jeton du lien
/// (`token`) et l'appel serveur étaient absents ; l'état « enregistrement » du
/// bouton est porté (`saving`).
///
/// PARITÉ (U04#4..#13) — 2026-09-28 : chrome aligné sur la source — plus de
/// barre de navigation ni de « Fermer », mais le `BackButton` de la source
/// (chevron `chevron-back` 21 `ink`, boîte 44×44, marges 22/8/6, désactivé
/// `opacity 0.45`) ; bascule œil `eye-outline`/`eye-off-outline` 21 `inkSoft`
/// dans un bouton 36×36 rayon 12 fond `primaryLight` ; champ e-mail en lecture
/// seule (`mail-outline` 20 `inkSoft`, fond `surfaceMuted`) toujours rendu ;
/// carte d'erreur `alert-circle-outline` 19 `ink` sur `surfaceMuted` ; panneau
/// `maxWidth 520` centré, marges horizontales 22, padding vertical 26,
/// `marginTop 30` puis `gap 19` du formulaire, écart eyebrow→titre 10, bouton
/// 54 ; libellé de politique repris mot pour mot. La bascule de visibilité est
/// partagée par les deux champs (`form.passwordVisible` de la source) : seul le
/// premier porte le bouton. Pas d'alerte de succès (la source ouvre la session,
/// `App.tsx:2213`).
///
/// PARITÉ (2026-09-29) — métriques secondaires reprises : décalage du chevron
/// de retour `translateX(-4)` (`BackButton.tsx:93`), interligne du titre
/// (`lineHeight 35`) et du texte d'erreur (`lineHeight 17`) via `.lineSpacing`,
/// placeholder teinté `Theme.inkFaint` (`placeholderTextColor`,
/// `PasswordResetForm.tsx:74`).
struct PasswordResetView: View {
    /// Adresse du compte concerné, affichée en lecture seule.
    var email: String = ""
    /// Jeton du lien de réinitialisation (`App.tsx:2464-2470`), transmis **brut**
    /// à `POST /auth/password/reset`.
    var token: String = ""
    /// Session serveur ouverte après le changement de mot de passe, remise à
    /// l'appelant pour qu'il la confie à `SessionStore` (`App.tsx:2213`).
    var onAuthenticated: ((ServerSession) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmation = ""
    /// `form.passwordVisible` : état **partagé** par les deux champs
    /// (`PasswordResetForm.tsx:23,30`).
    @State private var passwordVisible = false
    @State private var errorMessage = ""
    @State private var saving = false

    var body: some View {
        VStack(spacing: 0) {
            backButton
            GeometryReader { proxy in
                ScrollView {
                    panel
                        .frame(maxWidth: 520, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 26)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Theme.background)
        // `changePassword`/`changeConfirmation` de la source effacent l'erreur
        // dès que la saisie bouge (`usePasswordResetForm.ts:28-35`).
        .onChange(of: password) { _ in errorMessage = "" }
        .onChange(of: confirmation) { _ in errorMessage = "" }
    }

    /// `BackButton` de `PasswordResetScreen.tsx:28-34` : chevron `chevron-back`
    /// 21 `ink` dans une boîte 44×44 transparente (le style du composant impose
    /// `borderWidth 0` / `borderRadius 0` / fond transparent, `BackButton.tsx:76-95`),
    /// marges 22/8/6, désactivé pendant l'enregistrement (`opacity 0.45`).
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            IonIcon(name: "chevron-back", size: 21, color: Theme.ink)
                // `icon: { transform: [{ translateX: -4 }] }` de `BackButton.tsx:93`.
                .offset(x: -4)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(saving)
        .opacity(saving ? 0.45 : 1)
        .accessibilityLabel("Revenir à la connexion")
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Panneau `PasswordResetForm.tsx:14-38` : eyebrow, titre (`marginTop 10`)
    /// puis formulaire (`marginTop 30`, `gap 19`).
    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nouveau mot de passe")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink)
            Text("Choisis ton nouveau mot de passe")
                .font(.system(size: 30, weight: .black))
                // `title: { lineHeight: 35 }` de `PasswordResetForm.tsx:135-141`.
                .lineSpacing(5)
                .foregroundStyle(Theme.ink)
                .padding(.top, 10)
            form
                .padding(.top, 30)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 19) {
            emailField
            passwordField(
                title: "Nouveau mot de passe",
                text: $password,
                showToggle: true
            )
            passwordField(
                title: "Confirme le mot de passe",
                text: $confirmation,
                showToggle: false
            )
            if !errorMessage.isEmpty { errorCard }
            saveButton
        }
    }

    /// Champ e-mail **toujours rendu**, en lecture seule (`PasswordResetForm.tsx:40-55`) :
    /// légende 13/800 `ink`, `mail-outline` 20 `inkSoft`, fond `surfaceMuted`,
    /// bordure 1.5 `border`, rayon medium, hauteur 55.
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adresse e-mail")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                IonIcon(name: "mail-outline", size: 20, color: Theme.inkSoft)
                Text(email)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 55)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1.5)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Adresse e-mail du compte")
    }

    /// Champ local (`PasswordResetForm.tsx:57-101`) : légende 13/800 `ink`,
    /// icône `key-outline` 20 `inkSoft`, placeholder = libellé, bordure 1.5
    /// `border`, fond `surface`, hauteur 55. Bascule œil
    /// `eye-outline`/`eye-off-outline` 21 `inkSoft` dans un bouton 36×36 rayon
    /// 12 fond `primaryLight` (`:82-97`, `:158-165`).
    private func passwordField(
        title: String,
        text: Binding<String>,
        showToggle: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                IonIcon(name: "key-outline", size: 20, color: Theme.inkSoft)

                Group {
                    // `placeholder={label}` + `placeholderTextColor={colors.inkFaint}`
                    // (`PasswordResetForm.tsx:73-74`) : libellé teinté `inkFaint`.
                    if passwordVisible {
                        TextField("", text: text, prompt: Text(title).foregroundColor(Theme.inkFaint))
                    } else {
                        SecureField("", text: text, prompt: Text(title).foregroundColor(Theme.inkFaint))
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(title)

                if showToggle { visibilityToggle }
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

    /// Bascule œil `eye-outline`/`eye-off-outline` 21 `inkSoft` dans un bouton
    /// 36×36 rayon 12 fond `primaryLight` (`PasswordResetForm.tsx:82-97`,
    /// `:158-165`). Extraite de `passwordField()` (52 l. > 50, ratchet de
    /// complexité) : partagée par les deux champs (`form.passwordVisible` de la
    /// source), seul le premier la porte (`showToggle`) ; corps inchangé.
    private var visibilityToggle: some View {
        Button {
            passwordVisible.toggle()
        } label: {
            IonIcon(
                name: passwordVisible ? "eye-off-outline" : "eye-outline",
                size: 21,
                color: Theme.inkSoft
            )
            .frame(width: 36, height: 36)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            passwordVisible ? "Masquer le mot de passe" : "Afficher le mot de passe"
        )
    }

    /// Carte d'erreur (`PasswordResetForm.tsx:103-110, 166-180`) : fond
    /// `surfaceMuted`, rayon medium, padding 13, gap 10, `alert-circle-outline`
    /// 19 `ink`, texte 12/700 `ink`.
    private var errorCard: some View {
        HStack(spacing: 10) {
            IonIcon(name: "alert-circle-outline", size: 19, color: Theme.ink)
            Text(errorMessage)
                .font(.system(size: 12, weight: .bold))
                // `errorText: { lineHeight: 17 }` de `PasswordResetForm.tsx:174-180`.
                .lineSpacing(5)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    /// Bouton enregistrer (`PasswordResetForm.tsx:112-125, 181-189`) : hauteur
    /// 54, rayon 18, fond `primary`, texte 15/900 blanc ; désactivé
    /// `opacity 0.55`.
    private var saveButton: some View {
        Button {
            submit()
        } label: {
            Text(saving ? "Enregistrement…" : "Enregistrer")
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(saving)
        .opacity(saving ? 0.55 : 1)
    }

    /// `submit` de `usePasswordResetForm.ts:39-59` : validation locale, puis
    /// enregistrement serveur ; la session ouverte est remise à l'appelant.
    /// La source n'affiche aucun message de succès : la session ouverte suffit
    /// (`App.tsx:2213`) ; l'écran se ferme.
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
        saving = true
        Task {
            defer { saving = false }
            do {
                let authentication = try await AcctSecResetTransport.resetServerPassword(
                    email: email,
                    token: token,
                    password: password
                )
                onAuthenticated?(authentication.session)
                dismiss()
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    /// Message d'erreur : celui du serveur s'il est localisable, sinon le repli
    /// de la source Expo (`usePasswordResetForm.ts:52-55`).
    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "Impossible d’enregistrer le nouveau mot de passe."
    }
}

/// Message de la politique de mot de passe, repris mot pour mot de
/// `shared/new-password-policy.mjs:3-4` (`NEW_PASSWORD_POLICY_MESSAGE`).
private let newPasswordPolicyMessage = "Choisis un mot de passe de 8 à 128 caractères."

/// Bornes de la politique de mot de passe Expo
/// (`shared/new-password-policy.mjs:1-2,6-10`).
private func isValidNewPassword(_ value: String) -> Bool {
    value.count >= 8 && value.count <= 128
}
