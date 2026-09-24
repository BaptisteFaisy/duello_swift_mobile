//
//  AppleAuthView.swift
//  Duello
//
//  Bouton « Continuer avec Apple », porté depuis l'app Expo. Fichiers source :
//    - src/components/AppleAuthButton.tsx        (`AppleAuthButton`,
//                                                 états chargement/erreur,
//                                                 libellés FR)
//    - src/components/AppleAuthButton.types.ts   (`AppleAuthButtonProps`)
//    - src/components/AppleAuthButton.web.tsx    (`showWebFallback`,
//                                                 « Se connecter via Apple »)
//    - src/components/SocialAuthFallbackButton.tsx (`SocialAuthFallbackButton`,
//                                                 `unavailableMessage`)
//
//  `AppleAuthView` porte le bouton « Continuer avec Apple » avec deux
//  habillages (`AppleAuthVariant`) : par défaut la **peinture du champ
//  d'onboarding** (`GoogleFieldButtonStyle`), la même que le bouton Google —
//  les deux fournisseurs de l'étape `auth-method` forment une paire, cotes et
//  couleurs dans `Theme.provider*` ; `AppleAuthVariant.native` conserve la
//  peinture du bouton Apple natif. États : libellé échangé contre « Connexion
//  à Apple… » pendant l'échange (habillage « champ »), message d'erreur,
//  silence total sur une annulation. `AppleAuthFallbackButton` couvre le repli
//  web.
//
//  Limite assumée : `AuthenticationServices` n'est pas vérifiable hors Apple ;
//  l'appui déclenche `AppleAuthService`, qui renvoie une erreur documentée
//  quand la brique manque.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// Apparence du bouton Apple (`appearance` de `AppleAuthButtonProps`).
enum AppleAuthAppearance {
    case light
    case dark
}

/// Habillage du bouton Apple (`variant` de `AppleAuthButtonProps`).
enum AppleAuthVariant {
    /// `onboarding-field` : la peinture du **champ d'onboarding**, identique au
    /// bouton Google (`GoogleFieldButtonStyle`) — fond encre `#111111`, filet
    /// blanc 1.5, contenu blanc, rayon 14. C'est l'habillage des deux écrans
    /// (`LoginScreen`, `OnboardingScreen`), donc le défaut.
    case field
    /// `default` : le bouton Apple **natif** (`AppleAuthenticationButtonStyle`
    /// `.WHITE` en thème sombre) — fond blanc, contenu noir, sans bordure.
    case native
}

/// Bouton « Continuer avec Apple » avec ses états. `onAuthenticated` reçoit
/// l'identité nettoyée par le serveur et la session Duello à ouvrir : la
/// connexion du bouton n'ouvre pas la session elle-même (comme le bouton Expo,
/// dont `onAuthenticated` est appelé après validation serveur).
struct AppleAuthView: View {
    var appearance: AppleAuthAppearance = .light
    /// Défaut = habillage dominant du RN (`variant="onboarding-field"` sur les
    /// deux écrans) : le champ sombre partagé avec le bouton Google.
    var variant: AppleAuthVariant = .field
    var disabled: Bool = false
    var username: String? = nil
    var onAuthenticated: (AppleAuthIdentity, DuelloAPI.SessionPayload) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?
    /// `useAppleAvailability` : le bouton disparaît quand Apple Sign In n'est
    /// pas disponible sur l'appareil (`if (!available) return null`).
    @State private var isAvailable = AppleAuthAvailability.isAvailable()

    var body: some View {
        VStack(spacing: 7) {
            if isAvailable {
                providerButton
            }

            // Le texte d'état s'affiche **sous** le bouton, en plus du libellé
            // échangé dans le bouton (habillage « champ »), comme la source.
            if isLoading {
                Text("Connexion à Apple…")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(appearance == .dark ? Color(hex: 0xA3A3A3) : Theme.inkSoft)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(appearance == .dark ? Theme.providerErrorOnDark : Theme.providerError)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Le bouton lui-même, dans l'habillage demandé. L'habillage « champ »
    /// réutilise `GoogleFieldButtonStyle` : les deux fournisseurs de l'étape
    /// `auth-method` peignent alors, au pixel près, le même champ (fond
    /// `#111111`, filet blanc 1.5, rayon 14, appui `#1D1D1D`).
    @ViewBuilder
    private var providerButton: some View {
        switch variant {
        case .field:
            Button {
                Task { await authenticate() }
            } label: {
                label
            }
            .buttonStyle(GoogleFieldButtonStyle(appearance: .dark, isDimmed: disabled || isLoading))
            .disabled(disabled || isLoading)
            .accessibilityLabel("Continuer avec Apple")
        case .native:
            Button {
                Task { await authenticate() }
            } label: {
                label
            }
            .buttonStyle(AppleFieldButtonStyle(
                appearance: appearance,
                isDimmed: disabled || isLoading
            ))
            .disabled(disabled || isLoading)
            .accessibilityLabel("Continuer avec Apple")
        }
    }

    /// Corps du bouton : logo Apple + libellé. La teinte du contenu vient de
    /// l'habillage : blanc pour le champ sombre, noir (thème sombre) ou blanc
    /// (thème clair) pour le bouton natif.
    private var label: some View {
        HStack(spacing: Theme.providerFieldSpacing) {
            Image(systemName: "apple.logo")
                .font(.system(size: Theme.providerLogoSize, weight: .medium))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: Theme.providerFieldMinHeight)
    }

    /// Libellé : dans l'habillage « champ », il est échangé contre « Connexion
    /// à Apple… » pendant l'échange (`AppleAuthButton.tsx:139`), le texte d'état
    /// s'affichant en plus **sous** le bouton ; le bouton natif garde son
    /// libellé.
    private var title: String {
        if variant == .field && isLoading { return "Connexion à Apple…" }
        return "Continuer avec Apple"
    }

    /// Preuve native puis vérification serveur ; l'annulation ne laisse
    /// aucune trace d'erreur.
    private func authenticate() async {
        guard !disabled, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await AppleAuthService.authenticate(username: username)
            onAuthenticated(result.identity, result.session)
        } catch {
            errorMessage = appleAuthErrorMessage(error)
        }
        isLoading = false
    }
}

/// `useAppleAvailability` (`AppleAuthentication.isAvailableAsync()`) : Apple
/// Sign In est disponible sur l'appareil (iOS 13+).
enum AppleAuthAvailability {
    static func isAvailable() -> Bool {
        #if canImport(AuthenticationServices)
        if #available(iOS 13.0, *) { return true }
        return false
        #else
        return false
        #endif
    }
}

/// Peinture du bouton Apple **natif** (`AppleAuthVariant.native`,
/// `AppleAuthenticationButtonStyle.WHITE` en thème sombre) : fond blanc, logo
/// et texte noirs, **sans bordure**, rayon 14, hauteur 55. L'habillage
/// « champ » (`AppleAuthVariant.field`) n'utilise **pas** ce style : il
/// réutilise `GoogleFieldButtonStyle` (champ sombre bordé de blanc), pour que
/// les deux boutons de l'étape `auth-method` peignent le même champ.
struct AppleFieldButtonStyle: ButtonStyle {
    var appearance: AppleAuthAppearance
    /// Bouton hors service : 55 %, le `styles.disabled` de la source.
    var isDimmed: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(appearance == .dark ? Color.black : Color.white)
            .background(background(configuration))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(isDimmed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }

    /// Thème sombre : bouton blanc (contenu noir) ; thème clair : bouton noir
    /// (contenu blanc).
    private func background(_ configuration: Configuration) -> Color {
        if appearance == .dark {
            return configuration.isPressed ? Color(hex: 0xF0F0F0) : Color.white
        }
        return configuration.isPressed ? Color(hex: 0x1D1D1D) : Color.black
    }
}

/// Repli web de `AppleAuthButton.web.tsx` via `SocialAuthFallbackButton` :
/// bouton noir « Se connecter via Apple ». Sans handler, l'appui affiche le
/// message d'indisponibilité.
struct AppleAuthFallbackButton: View {
    var label: String = "Se connecter via Apple"
    var unavailableMessage: String? = "La connexion Apple sur le web n’est pas encore configurée."
    var appearance: AppleAuthAppearance = .light
    var disabled: Bool = false
    var onPress: (() -> Void)? = nil

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 7) {
            Button(action: handlePress) {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 21, weight: .regular))
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(appearance == .dark ? AppleAuthPalette.inkOnLight : AppleAuthPalette.lightOnInk)
                .background(appearance == .dark ? AppleAuthPalette.lightOnInk : AppleAuthPalette.inkOnLight)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(appearance == .dark ? AppleAuthPalette.fallbackBorder : AppleAuthPalette.lightOnInk, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .opacity(disabled ? 0.55 : 1)
            .accessibilityLabel(label)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(appearance == .dark ? Theme.providerErrorOnDark : Theme.providerError)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func handlePress() {
        if let onPress {
            onPress()
            return
        }
        if let unavailableMessage {
            errorMessage = unavailableMessage
        }
    }
}

/// Teintes du repli web (`AppleAuthFallbackButton`), reprises de
/// `SocialAuthFallbackButton.tsx`. Les teintes des états du bouton (statut,
/// échec) vivent dans `Theme.provider*`, partagées avec le bouton Google.
private enum AppleAuthPalette {
    static let inkOnLight = Color(hex: 0x1F1F1F)
    static let lightOnInk = Color(hex: 0xFFFFFF)
    static let fallbackBorder = Color(hex: 0x747775)
}
