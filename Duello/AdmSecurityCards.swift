//
//  AdmSecurityCards.swift
//  Duello
//
//  Cartes de sécurité du compte administrateur : clé d'accès serveur, mot de
//  passe, déconnexion.
//
//  Fichiers source Expo portés :
//    - src/admin/AdminApp.tsx          (champs « Clé d'accès serveur »,
//      « Nouveau mot de passe », « Confirmer le mot de passe », `submitPassword`)
//    - src/components/LogoutControl.tsx (confirmation de déconnexion)
//    - shared/new-password-policy.mjs   (`AdmPasswordPolicy`)
//
//  Les libellés et les messages sont repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// État du formulaire de mot de passe (`status` du source).
private enum AdmPasswordPhase {
    case idle, saving, saved, error
}

/// `Clé d'accès serveur (facultative)` : jeton `DUELLO_ADMIN_TOKEN` du compte.
struct AdmAccessKeyCard: View {
    @Binding var token: String
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdmCardHeading(icon: "server.rack", title: "Accès aux données admin")
            AdmFieldLabel(title: "Clé d’accès serveur (facultative)")
            HStack(spacing: 0) {
                field
                revealButton
            }
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            Text("Le serveur de production exige DUELLO_ADMIN_TOKEN. Saisis cette clé ici : elle reste dans le stockage isolé du compte admin et n’est jamais intégrée au bundle de l’application.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Saisie masquée par défaut, comme `secureTextEntry` du source.
    @ViewBuilder
    private var field: some View {
        Group {
            if isRevealed {
                TextField("Aucune clé nécessaire", text: $token)
            } else {
                SecureField("Aucune clé nécessaire", text: $token)
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.ink)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }

    private var revealButton: some View {
        Button {
            isRevealed.toggle()
        } label: {
            Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Masquer la clé" : "Afficher la clé")
    }
}

/// `Sécurité du compte` : nouveau mot de passe et confirmation.
struct AdmPasswordCard: View {
    var onChangePassword: (String) async throws -> Void

    @State private var password = ""
    @State private var confirmation = ""
    @State private var isRevealed = false
    @State private var phase: AdmPasswordPhase = .idle
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdmCardHeading(icon: "key", title: "Sécurité du compte")
            passwordField
            AdmFieldLabel(title: "Confirmer le mot de passe")
            confirmationField
            submitButton
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(phase == .saved ? Theme.primary : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 7) {
            AdmFieldLabel(title: "Nouveau mot de passe")
            HStack(spacing: 0) {
                Group {
                    if isRevealed {
                        TextField("Nouveau mot de passe", text: $password)
                    } else {
                        SecureField("Nouveau mot de passe", text: $password)
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRevealed ? "Masquer le mot de passe" : "Afficher le mot de passe")
            }
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private var confirmationField: some View {
        Group {
            if isRevealed {
                TextField("Répète le mot de passe", text: $confirmation)
            } else {
                SecureField("Répète le mot de passe", text: $confirmation)
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.ink)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .onChange(of: password) { _ in resetFeedback() }
        .onChange(of: confirmation) { _ in resetFeedback() }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "key")
                    .font(.system(size: 15, weight: .bold))
                Text(phase == .saving ? "Modification…" : "Modifier le mot de passe")
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(phase == .saving)
        .opacity(phase == .saving ? 0.55 : 1)
        .accessibilityLabel("Modifier le mot de passe")
    }

    /// `submitPassword` : politique de longueur, correspondance, puis envoi.
    @MainActor
    private func submit() async {
        guard AdmPasswordPolicy.isValid(password) else {
            phase = .error
            message = AdmPasswordPolicy.message
            return
        }
        guard password == confirmation else {
            phase = .error
            message = "Les deux mots de passe ne correspondent pas."
            return
        }
        phase = .saving
        message = ""
        do {
            try await onChangePassword(password)
            password = ""
            confirmation = ""
            phase = .saved
            message = "Le mot de passe administrateur a été modifié."
        } catch {
            phase = .error
            message = "Impossible de modifier le mot de passe pour le moment."
        }
    }

    /// Une nouvelle frappe efface le message précédent (`setStatus('idle')`).
    private func resetFeedback() {
        if phase != .saving {
            phase = .idle
            message = ""
        }
    }
}

/// `LogoutControl` : déconnexion du compte admin, avec confirmation.
/// Le composant du source n'affiche qu'un bouton — la description n'apparaît
/// que dans le dialogue de confirmation.
struct AdmLogoutCard: View {
    var onLogout: () async throws -> Void

    @State private var isConfirming = false
    @State private var didFail = false

    var body: some View {
        Button {
            isConfirming = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Se déconnecter")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Se déconnecter")
        .confirmationDialog(
            "Se déconnecter ?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Se déconnecter", role: .destructive) {
                Task { await performLogout() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les réglages administrateur resteront associés à ce compte.")
        }
        .alert("Déconnexion impossible", isPresented: $didFail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("La session n’a pas pu être fermée sur cet appareil. Réessaie.")
        }
    }

    @MainActor
    private func performLogout() async {
        do {
            try await onLogout()
        } catch {
            didFail = true
        }
    }
}
