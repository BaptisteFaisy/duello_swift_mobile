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
    @State private var passwordVisible = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // `BackButton` de `PasswordResetScreen.tsx` : hors du défilement,
            // chevron nu dans un cadre 44×44, marge haute 8 / basse 6 /
            // latérale 22.
            backButton

            // Contenu défilant de `PasswordResetScreen.tsx` (`content`) :
            // `flexGrow: 1` + `justifyContent: 'center'` — le panneau se centre
            // verticalement quand il tient, et défile sinon.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        panel
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
            }
        }
        .background(Theme.background)
    }

    // MARK: Panneau (`PasswordResetForm.tsx`)

    /// `panel` : `maxWidth: 520`, centré, sous le `paddingHorizontal: 22` /
    /// `paddingVertical: 26` du conteneur défilant.
    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            form
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
    }

    /// `header` : eyebrow 11/900 `letterSpacing: 1.5`, titre 30/900
    /// `lineHeight: 35` (soit `lineSpacing: 5`), écart eyebrow→titre 10.
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOUVEAU MOT DE PASSE")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(Theme.ink)
            Text("Choisis ton nouveau mot de passe")
                .font(.system(size: 30, weight: .black))
                .lineSpacing(5)
                .foregroundStyle(Theme.ink)
        }
    }

    /// `form` : `marginTop: 30`, `gap: 19` entre les groupes de champ.
    private var form: some View {
        VStack(alignment: .leading, spacing: 19) {
            emailField
            passwordField(
                title: "Nouveau mot de passe",
                text: $password,
                showsToggle: true
            )
            passwordField(
                title: "Confirme le mot de passe",
                text: $confirmation,
                showsToggle: false
            )
            if !errorMessage.isEmpty { errorCard }
            saveButton
        }
        .padding(.top, 30)
    }

    // MARK: Champs

    /// `EmailField` : légende 13/800 `Theme.ink`, coquille 55 de haut, bordure
    /// 1.5 `Theme.border`, fond `Theme.surfaceMuted` (lecture seule), icône
    /// `mail-outline` 20 `Theme.inkSoft`, valeur `Theme.ink` 15 régulière.
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adresse e-mail")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)

                TextField("", text: .constant(email))
                    .disabled(true)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `PasswordField` : légende 13/800 `Theme.ink`, icône `key-outline` 20
    /// `Theme.inkSoft`, saisie 15 régulière `Theme.ink`, coquille 55 de haut
    /// bordée 1.5 `Theme.border` sur fond `Theme.surface`. Le premier champ
    /// porte la bascule œil 36×36 (`Theme.primaryLight`, rayon 12) ; elle
    /// pilote l'affichage des **deux** champs, comme `passwordVisible` partagé
    /// de la source.
    private func passwordField(
        title: String,
        text: Binding<String>,
        showsToggle: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                Image(systemName: "key")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)

                Group {
                    if passwordVisible {
                        TextField(title, text: text)
                    } else {
                        SecureField(title, text: text)
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)

                if showsToggle {
                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 36, height: 36)
                            .background(Theme.primaryLight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        passwordVisible
                            ? "Masquer le mot de passe"
                            : "Afficher le mot de passe"
                    )
                }
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Cartes

    /// `ResetError` : `alert-circle-outline` 19 `Theme.ink`, texte 12/700
    /// `lineHeight: 17` (`lineSpacing: 5`) `Theme.ink`, `gap: 10`,
    /// `padding: 13`, rayon 14, fond `Theme.surfaceMuted`.
    private var errorCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 19))
                .foregroundStyle(Theme.ink)
            Text(errorMessage)
                .font(.system(size: 12, weight: .bold))
                .lineSpacing(5)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    // MARK: Boutons

    /// `BackButton` de `PasswordResetScreen.tsx` — composant **partagé**
    /// `DuelloBackButton` (port de `BackButton.tsx`). Appelé comme la source :
    /// `iconSize: 21`, boîte 44×44 (`styles.backButton` de l'écran), marges
    /// 22 / 8 / 6. Le chevron `Theme.ink`, le décalage −4 (`styles.icon`) et
    /// l'appui à 60 % viennent du composant. Son `styles.button`, appliqué
    /// **après** le style d'écran, neutralise `borderWidth` / `borderRadius` /
    /// `backgroundColor` : le bouton reste un chevron nu, sans cadre ni fond.
    private var backButton: some View {
        HStack(spacing: 0) {
            DuelloBackButton(
                iconSize: 21,
                accessibilityLabel: "Revenir à la connexion",
                action: { dismiss() }
            )
            .frame(width: 44, height: 44)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// `SaveButton` : hauteur 54, rayon **18** (`saveButton.borderRadius` de la
    /// source), fond `Theme.primary`, libellé blanc 15/**900**. Le rayon 18 est
    /// passé au composant partagé `DuelloPrimaryButton` (défaut 14) ; la graisse
    /// 900 est son défaut (`.black`).
    private var saveButton: some View {
        Button {
            submit()
        } label: {
            Text("Enregistrer")
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(DuelloPrimaryButton(radius: 18))
    }

    // MARK: Soumission

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
        // Fenêtre commune `AppAlert` (jamais `.alert` natif) : la source Expo
        // passe toutes ses alertes par `AppAlertProvider`. Bouton « OK » unique
        // (libellé du port) auquel la fermeture de la feuille est rattachée —
        // la source n'a pas d'alerte de succès (elle authentifie et quitte
        // l'écran), la confirmation est propre au port.
        AppAlert.alert(
            "Mot de passe enregistré",
            "Ton nouveau mot de passe a bien été enregistré.",
            [AppAlertButton("OK", onPress: { dismiss() })]
        )
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
