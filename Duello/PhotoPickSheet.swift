//
//  PhotoPickSheet.swift
//  Duello
//
//  Feuille « Modifier ma photo » — port de
//  `src/components/profile-photo/ProfilePhotoPickerModal.tsx`,
//  `profile-photo/profilePhotoPickerStyles.ts` et du contrôleur de
//  `profile-photo/useProfilePhotoPicker.ts` (phases `idle` / `waiting` /
//  `saving`, statut du téléphone, retrait de la photo).
//
//  L'app Expo montrait cette carte sur le Web et un `AppAlert` natif sur
//  mobile : le portage unifie sur cette feuille, seule surface iOS. La
//  capture depuis un téléphone lié reste déléguée à l'appelant (lot N) ; le
//  statut affiché provient de `phoneStatus`.
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit

/// Statut du téléphone lié (`ProfilePhotoPhoneStatus`).
enum PhotoPickPhoneStatus {
    case checking, connected, disconnected, unavailable
}

/// Phase de la feuille (`ProfilePhotoPickerPhase`).
private enum PhotoPickPhase { case idle, waiting, saving }

struct PhotoPickSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Photo actuelle : `nil` masque l'action de suppression.
    let currentPhotoUri: String?
    /// Statut du téléphone lié ; `.unavailable` par défaut (relais du lot N).
    var phoneStatus: PhotoPickPhoneStatus = .unavailable
    /// Capture depuis le téléphone connecté (déléguée) ; `nil` = non disponible.
    var choosePhone: (() async -> UIImage?)? = nil
    /// Ouverture de l'écran « Connecter au PC » (`onConnectPhone`).
    var onConnectPhone: (() -> Void)? = nil
    /// Enregistre la photo validée (`nil` = suppression), comme `onChange`.
    let onCommit: (String?) -> Void

    @State private var phase: PhotoPickPhase = .idle
    @State private var error = ""
    @State private var activeSource: PhotoPickSource?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if phase == .idle { choicesView } else { statusView }
            }
            .duelloCard()
            .padding(16)
        }
        .background(Theme.background)
        .fullScreenCover(item: $activeSource) { source in
            PhotoPickService.picker(
                source: source,
                onPick: { image in
                    activeSource = nil
                    commit(image)
                },
                onCancel: { activeSource = nil }
            )
            .ignoresSafeArea()
        }
    }

    /// En-tête : titre, fermeture et description de la miniature publiée.
    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 12) {
                Text("Modifier ma photo")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .disabled(phase == .saving)
                .accessibilityLabel("Fermer")
            }
            Text("Elle sera recadrée en carré et visible sur ton profil public.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.trailing, 32)
        }
    }

    /// Choix de la source : appareil, fichier local, téléphone lié.
    private var choicesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            sourceAction(
                icon: "camera",
                title: "Prendre une photo",
                description: "Utilise la caméra de cet appareil",
                disabled: false,
                loading: false
            ) { selectLocal(.camera) }
            sourceAction(
                icon: "laptopcomputer",
                title: "Importer depuis cet ordinateur",
                description: "Choisis un fichier enregistré sur cet appareil",
                disabled: false,
                loading: false
            ) { selectLocal(.library) }
            sourceAction(
                icon: "iphone",
                title: "Importer depuis mon téléphone",
                description: phoneDescription,
                disabled: phoneStatus != .connected,
                loading: phoneStatus == .checking
            ) { selectPhone() }
            if phoneStatus != .connected && phoneStatus != .checking {
                connectButton
            }
            if !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.like)
                    .padding(.top, 4)
            }
            if currentPhotoUri != nil {
                removeButton
            }
        }
        .padding(.top, 22)
    }

    /// Attente du téléphone ou préparation de la miniature.
    @ViewBuilder private var statusView: some View {
        if phase == .waiting {
            VStack(spacing: 0) {
                ProgressView().tint(Theme.primary).scaleEffect(1.3).padding(.top, 34)
                Text("En attente du téléphone")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 16)
                Text("Valide la demande dans Duello, puis choisis ta photo sur le téléphone connecté.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 7)
                Button { phase = .idle } label: {
                    Text("Annuler la demande")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 42)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                ProgressView().tint(Theme.primary).scaleEffect(1.3).padding(.top, 34)
                Text("Préparation de la photo…")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }

    /// « Comment lier mon téléphone » : ouvre l'écran de connexion.
    private var connectButton: some View {
        Button { onConnectPhone?() } label: {
            HStack(spacing: 7) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Text("Comment lier mon téléphone")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .disabled(onConnectPhone == nil)
    }

    /// « Supprimer la photo actuelle » : vide la photo puis ferme.
    private var removeButton: some View {
        Button {
            onCommit(nil)
            dismiss()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.like)
                Text("Supprimer la photo actuelle")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.like)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.plain)
        .padding(.top, 18)
    }

    /// Description de l'action « téléphone », selon le statut du lien.
    private var phoneDescription: String {
        switch phoneStatus {
        case .checking: return "Vérification du lien avec ton téléphone…"
        case .connected: return "Téléphone lié à ton compte"
        case .unavailable: return "Connexion impossible pour le moment"
        case .disconnected:
            return "Connecte-toi au même compte Duello sur ton téléphone pour le lier."
        }
    }

    /// Ligne de source : icône, titre, description et chevron.
    private func sourceAction(
        icon: String,
        title: String,
        description: String,
        disabled: Bool,
        loading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(Theme.primaryLight)
                    if loading {
                        ProgressView().tint(Theme.primary)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(description)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .opacity(disabled ? 0.52 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    /// Caméra ou photothèque locales : la permission caméra précède la vue.
    @MainActor private func selectLocal(_ source: PhotoPickSource) {
        error = ""
        guard source == .camera else {
            activeSource = source
            return
        }
        Task { @MainActor in
            if await PhotoPickService.ensureCameraAccess() {
                activeSource = .camera
            } else {
                error = PhotoPickError.cameraPermissionDenied.message
            }
        }
    }

    /// Reprise depuis le téléphone lié : passe en attente puis enregistre.
    @MainActor private func selectPhone() {
        guard let choosePhone else { return }
        error = ""
        phase = .waiting
        Task { @MainActor in
            let image = await choosePhone()
            if let image {
                commit(image)
            } else {
                phase = .idle
                error = "Aucun téléphone lié. Connecte-toi au même compte Duello sur ton téléphone."
            }
        }
    }

    /// Recadre, compresse puis confie la miniature (`onChange`).
    @MainActor private func commit(_ image: UIImage) {
        phase = .saving
        error = ""
        Task { @MainActor in
            await Task.yield()
            do {
                let dataUri = try PhotoPickService.dataUri(from: image)
                onCommit(dataUri)
                dismiss()
            } catch let failure {
                self.error = (failure as? PhotoPickError)?.message
                    ?? "La photo n’a pas pu être préparée."
            }
            phase = .idle
        }
    }
}
