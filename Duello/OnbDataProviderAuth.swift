//
//  OnbDataProviderAuth.swift
//  Duello
//
//  Connexion par fournisseur (Google / Apple) au sein de l'inscription. Porté
//  de l'app Expo :
//    - src/hooks/useOnboardingProviderAuth.ts (`useOnboardingProviderAuth`,
//      `googleProfile`, `appleProfile`, `finishAuthentication`)
//    - src/utils/googleAccount.ts (`profileWithGoogleIdentity`,
//      `withoutGoogleProviderPhoto`)
//    - src/utils/appleAccount.ts (`profileWithAppleIdentity`,
//      `withoutRemoteProviderPhoto`) — réutilisé via `AppleAuthAccountResolver`
//
//  Les fonctions pures de fusion de profil sont exposées sur l'enum ; l'état
//  des identités vit dans `Model`, équivalent `ObservableObject` du hook,
//  compatible iOS 16. Aucune dépendance externe.
//

import Foundation
import Combine

/// Connexion par fournisseur du parcours d'inscription.
enum OnbDataProviderAuth {
    /// `googleProfile` : identité Google fusionnée dans le profil, selon le
    /// mode. En `upgrade`, seuls l'e-mail, la photo et la visibilité changent ;
    /// sinon l'identité remplace prénom, nom et affichage.
    static func googleProfile(
        _ current: UserProfile,
        identity: GoogleIdentity,
        mode: OnbDataSteps.Mode
    ) -> UserProfile {
        let provider = profileWithGoogleIdentity(current, identity: identity)
        let username = AcctSecUsernameAvailability.isValid(current.displayName)
            ? current.displayName
            : provider.displayName
        if mode == .upgrade {
            var result = current
            result.email = provider.email
            result.photoUri = provider.photoUri
            result.isPublic = true
            return result
        }
        var result = provider
        result.displayName = username
        result.firstName = username
        result.lastName = ""
        return result
    }

    /// `appleProfile` : identité Apple fusionnée dans le profil, selon le mode.
    /// Apple ne fournit jamais de photo : le champ photo reste inchangé.
    static func appleProfile(
        _ current: UserProfile,
        identity: AppleAuthIdentity,
        mode: OnbDataSteps.Mode
    ) -> UserProfile {
        let provider = AppleAuthAccountResolver.profileWithIdentity(current, identity: identity)
        let username = AcctSecUsernameAvailability.isValid(current.displayName)
            ? current.displayName
            : provider.displayName
        if mode == .upgrade {
            var result = current
            result.email = provider.email
            result.isPublic = true
            return result
        }
        var result = provider
        result.displayName = username
        result.firstName = username
        result.lastName = ""
        return result
    }

    /// `profileWithGoogleIdentity` (`googleAccount.ts`) : prénom en affichage,
    /// e-mail normalisé, profil public, sans photo distante d'un autre
    /// fournisseur.
    static func profileWithGoogleIdentity(
        _ profile: UserProfile,
        identity: GoogleIdentity
    ) -> UserProfile {
        var result = withoutProviderPhoto(profile)
        let words = identity.displayName.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let firstName = identity.firstName.isEmpty ? (words.first ?? "") : identity.firstName
        let lastName = identity.lastName.isEmpty
            ? words.dropFirst().joined(separator: " ")
            : identity.lastName
        result.displayName = firstName.isEmpty ? identity.displayName : firstName
        result.firstName = firstName
        result.lastName = lastName
        result.email = identity.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        result.isPublic = true
        return result
    }

    /// Étape suivante du parcours, bornée comme le hook
    /// (`Math.min(current + 1, stepsLength - 1)`).
    static func advancedStepIndex(current: Int, stepsLength: Int) -> Int {
        guard stepsLength > 0 else { return current }
        return min(current + 1, stepsLength - 1)
    }

    /// `withoutGoogleProviderPhoto` / `withoutRemoteProviderPhoto` : aucune URL
    /// distante n'est recopiée, une miniature locale reste intacte.
    private static func withoutProviderPhoto(_ profile: UserProfile) -> UserProfile {
        var result = profile
        if let photo = result.photoUri,
           photo.range(of: #"^https?://"#, options: [.regularExpression, .caseInsensitive]) != nil {
            result.photoUri = nil
        }
        return result
    }

    // MARK: État des identités (équivalent du hook)

    /// État des identités de fournisseur et parcours d'authentification,
    /// équivalent `ObservableObject` de `useOnboardingProviderAuth`.
    @MainActor
    final class Model: ObservableObject {
        @Published private(set) var googleIdentity: GoogleIdentity?
        @Published private(set) var appleIdentity: AppleAuthIdentity?

        init(
            initialGoogleIdentity: GoogleIdentity? = nil,
            initialAppleIdentity: AppleAuthIdentity? = nil
        ) {
            googleIdentity = initialGoogleIdentity
            appleIdentity = initialAppleIdentity
        }

        /// `authenticateWithGoogle` : prévient le parent, mémorise l'identité
        /// Google (et efface l'Apple), fusionne le profil et rend l'étape
        /// suivante. L'appelant efface mot de passe et biométrie, comme
        /// `finishAuthentication`.
        func authenticateWithGoogle(
            _ identity: GoogleIdentity,
            mode: OnbDataSteps.Mode,
            currentProfile: UserProfile,
            currentStep: Int,
            stepsLength: Int,
            onAuthenticated: (GoogleIdentity) async -> Void
        ) async -> (profile: UserProfile, stepIndex: Int) {
            await onAuthenticated(identity)
            googleIdentity = identity
            appleIdentity = nil
            let profile = OnbDataProviderAuth.googleProfile(
                currentProfile,
                identity: identity,
                mode: mode
            )
            let step = OnbDataProviderAuth.advancedStepIndex(
                current: currentStep,
                stepsLength: stepsLength
            )
            return (profile, step)
        }

        /// `authenticateWithApple` : symétrique de `authenticateWithGoogle`.
        func authenticateWithApple(
            _ identity: AppleAuthIdentity,
            mode: OnbDataSteps.Mode,
            currentProfile: UserProfile,
            currentStep: Int,
            stepsLength: Int,
            onAuthenticated: (AppleAuthIdentity) async -> Void
        ) async -> (profile: UserProfile, stepIndex: Int) {
            await onAuthenticated(identity)
            appleIdentity = identity
            googleIdentity = nil
            let profile = OnbDataProviderAuth.appleProfile(
                currentProfile,
                identity: identity,
                mode: mode
            )
            let step = OnbDataProviderAuth.advancedStepIndex(
                current: currentStep,
                stepsLength: stepsLength
            )
            return (profile, step)
        }
    }
}
