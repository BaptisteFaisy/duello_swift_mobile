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
//  `AppleAuthView` reproduit le bouton natif : apparence claire/sombre, état
//  de chargement « Connexion à Apple… », message d'erreur, et silence total
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

    var body: some View {
        VStack(spacing: 7) {
            Button {
                Task { await authenticate() }
            } label: {
                label
            }
            .buttonStyle(.plain)
            .disabled(disabled || isLoading)
            .opacity(disabled || isLoading ? 0.55 : 1)
            .accessibilityLabel("Continuer avec Apple")

            if isLoading {
                Text("Connexion à Apple…")
                    .font(.system(size: 11))
                    .foregroundStyle(appearance == .dark ? AppleAuthPalette.statusOnDark : Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(appearance == .dark ? AppleAuthPalette.errorOnDark : AppleAuthPalette.error)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Corps du bouton : logo Apple + libellé, encre pleine sur fond clair.
    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.logo")
                .font(.system(size: 17, weight: .medium))
            Text("Continuer avec Apple")
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 55)
        .foregroundStyle(appearance == .dark ? AppleAuthPalette.inkOnLight : AppleAuthPalette.lightOnInk)
        .background(appearance == .dark ? AppleAuthPalette.lightOnInk : AppleAuthPalette.inkOnLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    .foregroundStyle(appearance == .dark ? AppleAuthPalette.errorOnDark : AppleAuthPalette.error)
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

/// Teintes du bouton Apple, reprises de `appleErrorMessage` et des styles de
/// `AppleAuthButton.tsx` / `SocialAuthFallbackButton.tsx`.
private enum AppleAuthPalette {
    /// `colors.prerequisitesMissing` (`#B42318`).
    static let error = Color(hex: 0xB42318)
    static let errorOnDark = Color(hex: 0xFF8A80)
    static let statusOnDark = Color(hex: 0xA3A3A3)
    static let inkOnLight = Color(hex: 0x1F1F1F)
    static let lightOnInk = Color(hex: 0xFFFFFF)
    static let fallbackBorder = Color(hex: 0x747775)
}
