//
//  OnbFlowControls.swift
//  Duello
//
//  LOT 12-B — déroulé de l'inscription : les contrôles restants de l'écran.
//
//  Fichier source Expo porté : `src/screens/OnboardingScreen.tsx` (composants
//  locaux non encore portés : le séparateur « OU » (`authDivider`), le bouton
//  biométrie (`biometricButton`), l'illustration d'école cible
//  (`goalIllustration`) et la liste de suggestions (`suggestionsList`).
//
//  Réutilise sans les redéfinir : `OnbUiChoiceSection` / `OnbUiChoiceChip`
//  (puces), `OnbUiField` (champs), `OnbUiProviderAccountSummary`
//  (récapitulatif fournisseur) — portés par le lot voisin `OnbUi`. Seuls les
//  contrôles absents de ce lot vivent ici, tous préfixés `OnbFlow`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

/// Séparateur « OU » de l'étape `credentials` (`authDivider`).
struct OnbFlowDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            line
            Text("OU")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}

/// `biometricButton` : création de compte par la biométrie.
struct OnbFlowBiometricButton: View {
    let verified: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: verified ? "checkmark.circle.fill" : "touchid")
                    .font(.system(size: 20))
                Text(verified ? "Biométrie validée" : "Créer mon compte avec la biométrie")
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(verified ? Theme.surface : Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(verified ? Theme.ink : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(verified ? Theme.ink : Theme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(verified ? "Biométrie validée" : "Choisir la biométrie pour créer mon compte")
    }
}

/// `goalIllustration` : l'école cible, dans un disque décoré.
struct OnbFlowGoalIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.progressLight)
                .frame(width: 86, height: 86)
                .rotationEffect(.degrees(-5))
            Image(systemName: "flag.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.progress)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 108)
        .accessibilityHidden(true)
    }
}

/// `suggestionsList` : liste déroulante des écoles correspondantes.
struct OnbFlowSchoolSuggestions: View {
    let schools: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(schools.enumerated()), id: \.element) { index, school in
                if index > 0 {
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
                Button {
                    onSelect(school)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "school")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.progress)
                        Text(school)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choisir \(school)")
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// Boutons Google / Apple de l'étape `auth-method`.
///
/// `GoogleAuthButton` (kit partagé) ouvre directement la session et n'expose pas
/// l'identité : le parcours passe donc par `GoogleAuthService` pour rendre la
/// main sans court-circuiter la complétion. Côté Apple, `AppleAuthView` fournit
/// déjà l'identité par rappel.
struct OnbFlowProviderButtons: View {
    let username: String?
    var onGoogle: (GoogleIdentity) -> Void
    var onApple: (AppleAuthIdentity) -> Void

    @State private var isGoogleLoading = false
    @State private var googleError: String?

    var body: some View {
        VStack(spacing: 10) {
            Button {
                signInWithGoogle()
            } label: {
                HStack(spacing: 10) {
                    GoogleGLogo()
                        .frame(width: 20, height: 20)
                    Text(isGoogleLoading ? "Connexion à Google…" : "Continuer avec Google")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.border, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(isGoogleLoading)
            .accessibilityLabel("Continuer avec Google")

            AppleAuthView(
                appearance: .light,
                disabled: isGoogleLoading,
                username: username,
                onAuthenticated: { identity, _ in onApple(identity) }
            )

            if let googleError {
                Text(googleError)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.like)
            }
        }
    }

    /// Ouvre la connexion Google et rend l'identité au parcours, sans ouvrir la
    /// session (contrairement à `GoogleAuthButton`, qui termine l'inscription).
    private func signInWithGoogle() {
        guard !isGoogleLoading else { return }
        isGoogleLoading = true
        googleError = nil
        Task {
            do {
                let auth = try await GoogleAuthService.shared.authenticate(username: username)
                onGoogle(auth.identity)
            } catch {
                googleError = "La connexion à Google a échoué."
            }
            isGoogleLoading = false
        }
    }
}
