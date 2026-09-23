//
//  LoginScrFields.swift
//  Duello
//
//  Briques de l'écran de connexion sombre, portées de
//  `src/screens/LoginScreen.tsx` (styles `fieldGroup`, `fieldShell`,
//  `whiteFieldBorder`, `inputAction`, `errorCard`, `authDivider`,
//  `biometricButton`, `resetLink`, `primaryButton`) et du composant
//  `Field` / `FieldProps` de ce même fichier.
//
//  Fidélité : l'écran Expo est **noir** (fond `#000000`, texte blanc), alors
//  que `Theme.swift` décrit l'interface claire. Les teintes sombres sont donc
//  regroupées ici dans `LoginScrPalette` — aucune valeur n'est codée en dur
//  dans les vues. Les rayons viennent de `Theme.radiusMedium/Large` (14/18),
//  identiques à `radii` du thème Expo.
//
//  Réutilisation : le bouton principal blanc reprend `DuelloWelcomeButton`
//  (WelcomeView.swift), qui porte exactement le style `primaryButton` de la
//  source (blanc plein, radius 18, texte noir, appui 0.84/0.99).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// Teintes de l'écran de connexion sombre, relevées dans `LoginScreen.tsx`.
enum LoginScrPalette {
    /// `safeArea.backgroundColor` / `footer.backgroundColor`.
    static let background = Color.black
    /// Texte principal sur fond noir (`colors.white`).
    static let onDark = Color.white
    /// Texte secondaire (`#A3A3A3`).
    static let muted = Color(hex: 0xA3A3A3)
    /// Texte d'aide au-dessus des champs (`#737373`).
    static let placeholder = Color(hex: 0x737373)
    /// Icônes de champ (`#A3A3A3`).
    static let icon = Color(hex: 0xA3A3A3)
    /// `fieldShell.backgroundColor` (`#0B0B0B`).
    static let field = Color(hex: 0x0B0B0B)
    /// `fieldShell.borderColor` (`#2A2A2A`), aussi utilisé par les séparateurs.
    static let fieldBorder = Color(hex: 0x2A2A2A)
    /// `inputAction.backgroundColor` (`#1A1A1A`).
    static let action = Color(hex: 0x1A1A1A)
    /// `errorCard.backgroundColor` (`#151515`).
    static let errorCard = Color(hex: 0x151515)
    /// `errorCard.borderColor` (`#333333`).
    static let errorCardBorder = Color(hex: 0x333333)
}

// MARK: - Champ de formulaire

/// `FieldProps` de `LoginScreen.tsx` : description d'un champ, sans état.
struct LoginScrFieldProps {
    /// Libellé au-dessus du champ, déjà en capitales comme dans la source.
    var label: String
    var placeholder: String
    /// Symbole SF remplaçant l'`Ionicons` de la source.
    var icon: String? = nil
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .never
    /// `whiteBorder` : bordure blanche au lieu du gris `#2A2A2A`.
    var whiteBorder: Bool = false
    /// Vue de fin de champ (`trailing` de la source : l'œil d'affichage).
    var trailing: AnyView? = nil
}

/// `Field` de `LoginScreen.tsx` : libellé, coquille bordée, icône, accessoire.
///
/// `onEdit` remplace le `setError(null)` que la source exécute à chaque frappe.
struct LoginScrField: View {
    let props: LoginScrFieldProps
    @Binding var text: String
    var onEdit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(props.label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(LoginScrPalette.onDark)

            HStack(spacing: 10) {
                if let icon = props.icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LoginScrPalette.icon)
                }
                input
                if let trailing = props.trailing {
                    trailing
                }
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 55)
            .background(LoginScrPalette.field)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(
                        props.whiteBorder ? LoginScrPalette.onDark : LoginScrPalette.fieldBorder,
                        lineWidth: 1.5
                    )
            )
        }
    }

    @ViewBuilder private var input: some View {
        Group {
            if props.isSecure {
                SecureField("", text: $text, prompt: prompt)
            } else {
                TextField("", text: $text, prompt: prompt)
            }
        }
        .textInputAutocapitalization(props.autocapitalization)
        .keyboardType(props.keyboard)
        .autocorrectionDisabled()
        .textContentType(contentType)
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(LoginScrPalette.onDark)
        .onChange(of: text) { _ in onEdit() }
    }

    /// Texte d'invite, coloré comme `placeholderTextColor` de la source.
    private var prompt: Text {
        Text(props.placeholder).foregroundColor(LoginScrPalette.placeholder)
    }

    /// `keyboardType`/`secureTextEntry` de la source traduits en type de contenu.
    private var contentType: UITextContentType? {
        if props.isSecure { return .password }
        return props.keyboard == .emailAddress ? .emailAddress : nil
    }
}

/// Accessoire `trailing` du champ mot de passe : l'œil `eye-outline` /
/// `eye-off-outline` de la source, dans sa pastille `inputAction`.
struct LoginScrRevealToggle: View {
    @Binding var isRevealed: Bool

    var body: some View {
        Button {
            isRevealed.toggle()
        } label: {
            Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(LoginScrPalette.icon)
                .frame(width: 36, height: 36)
                .background(LoginScrPalette.action)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Masquer le mot de passe" : "Afficher le mot de passe")
    }
}

// MARK: - Bandeau d'erreur

/// `errorCard` de la source : icône d'alerte et message, sur carte sombre.
struct LoginScrErrorCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(LoginScrPalette.onDark)
            Text(message)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LoginScrPalette.onDark)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LoginScrPalette.errorCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(LoginScrPalette.errorCardBorder, lineWidth: 1)
        )
        .padding(.top, -6)
    }
}

// MARK: - Séparateur « OU »

/// `authDivider` de la source : deux filets et le mot « OU ».
struct LoginScrDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            rule
            Text("OU")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(LoginScrPalette.placeholder)
            rule
        }
        .padding(.vertical, -4)
    }

    private var rule: some View {
        Rectangle()
            .fill(LoginScrPalette.fieldBorder)
            .frame(height: 1)
    }
}

// MARK: - Boutons

/// Effet d'appui commun aux commandes de l'écran de connexion : opacité et
/// échelle réduites à l'appui (`pressed` de la source : 0.84 / 0.99 ; le
/// bouton retour de la source n'abaisse que l'opacité, à 0.6).
struct LoginScrPressStyle: ButtonStyle {
    var pressedOpacity: Double = 0.84
    var pressedScale: Double = 0.99

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
    }
}

/// `biometricButton` de la source : contour blanc, icône d'empreinte.
struct LoginScrBiometricButton: View {
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "touchid")
                    .font(.system(size: 23, weight: .semibold))
                Text(isLoading ? "Vérification…" : "Continuer avec la biométrie")
                    .font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(LoginScrPalette.onDark)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(LoginScrPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(LoginScrPalette.onDark, lineWidth: 1.5)
            )
        }
        .buttonStyle(LoginScrPressStyle())
        .disabled(isLoading)
        .opacity(isLoading ? 0.55 : 1)
        .accessibilityLabel("Continuer avec la biométrie")
    }
}

/// `resetLinkButton` de la source : lien discret, petit et centré.
struct LoginScrLinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(LoginScrPalette.muted)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// `primaryButton` de la source : bouton blanc plein, libellé + flèche.
///
/// Le style vient de `DuelloWelcomeButton` (WelcomeView.swift), partagé et
/// déjà aligné sur les mêmes mesures.
struct LoginScrFooterPrimary: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(DuelloWelcomeButton())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }
}

// MARK: - En-tête de réinitialisation / activation

/// Bloc `eyebrow` + `title` + `subtitle` de la source, affiché sur la page
/// des identifiants quand une réinitialisation ou une activation est en cours.
struct LoginScrEyebrowHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(LoginScrPalette.onDark)
            Text(title)
                .font(.system(size: 30, weight: .black))
                .tracking(-0.8)
                .lineSpacing(5)
                .foregroundStyle(LoginScrPalette.onDark)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 15))
                .lineSpacing(7)
                .foregroundStyle(LoginScrPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
