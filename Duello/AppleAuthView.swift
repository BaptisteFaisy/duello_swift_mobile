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
//  `AppleAuthView` porte le bouton « Continuer avec Apple » **dans la peinture
//  du champ d'onboarding** (`GoogleFieldButtonStyle`), la même que le bouton
//  Google : les deux fournisseurs de l'étape `auth-method` forment une paire,
//  cotes et couleurs dans `Theme.provider*`. États : libellé échangé contre
//  « Connexion à Apple… » pendant l'échange, message d'erreur, silence total
//  sur une annulation. `AppleAuthFallbackButton` couvre le repli web.
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

/// Bouton « Continuer avec Apple » avec ses états. `onAuthenticated` reçoit
/// l'identité nettoyée par le serveur et la session Duello à ouvrir : la
/// connexion du bouton n'ouvre pas la session elle-même (comme le bouton Expo,
/// dont `onAuthenticated` est appelé après validation serveur).
struct AppleAuthView: View {
    var appearance: AppleAuthAppearance = .light
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

            // Le libellé du bouton reste « Continuer avec Apple » ; le texte
            // d'état s'affiche **sous** le bouton, comme la source.
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

    /// Corps du bouton : logo Apple + libellé, dans la peinture **blanche**
    /// du bouton natif Apple (`AppleAuthenticationButtonStyle.WHITE` en thème
    /// sombre) — distincte de `GoogleFieldButtonStyle`.
    private var label: some View {
        HStack(spacing: Theme.providerFieldSpacing) {
            Image(systemName: "apple.logo")
                .font(.system(size: Theme.providerLogoSize, weight: .medium))
            Text("Continuer avec Apple")
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: Theme.providerFieldMinHeight)
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

/// Peinture du bouton Apple de l'étape fournisseur : la source emploie le
/// bouton **natif** Apple (`AppleAuthenticationButtonStyle.WHITE` en thème
/// sombre) — fond blanc, logo et texte noirs, **sans bordure**, rayon 14,
/// hauteur 55. Distincte de `GoogleFieldButtonStyle` (champ sombre bordé de
/// blanc).
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
