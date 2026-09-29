import SwiftUI

// Port de `src/components/RemotePhotoCapturePrompt.tsx`,
// `src/components/RemotePhotoCaptureCoordinator.tsx` et
// `src/components/remotePhotoCapturePromptStyles.ts` (RN) — invite de capture
// à distance côté téléphone récepteur : choix de la source, envoi en cours,
// refus. La sélection réelle réutilise les sélecteurs du lot 6
// (`RemPhotoCameraPicker`, `RemPhotoLibraryPicker`) — AVFoundation reste isolé
// là-bas — et l'`UIActivityViewController` est piloté par la vue appelante.
//
// Écarts assumés (2026-09-29) :
//   - l'écoute des notifications de demande de capture (`useCaptureNotificationEvents`,
//     `useRemotePhotoCapturePrompt.ts:28-46`) n'est pas portée : seul le sondage
//     2 s de `RemPhotoRxCaptureCoordinator` est branché (relève du lot PushNotif) ;
//   - l'hôte `RemPhotoRxCaptureHost` doit être monté à la racine par `DuelloApp`
//     (`App.tsx:2603`) — hunk « À raccorder » de ce lot, hors fichier.

/// `RemotePhotoCapturePrompt`.
struct RemPhotoRxCapturePrompt: View {
    let busy: Bool
    let busySource: RemPhotoRxPickerSource?
    let error: String
    let purpose: RemPhotoCapturePurpose
    let onSelectPhoto: (RemPhotoRxPickerSource) -> Void
    let onDecline: () -> Void

    private var profilePhoto: Bool { purpose == .profilePhoto }

    var body: some View {
        ZStack {
            RemPhotoRxStyles.promptBackdrop.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                RemPhotoRxPromptCopy(profilePhoto: profilePhoto)
                if !error.isEmpty {
                    Text(error)
                        .font(.system(size: RemPhotoRxStyles.promptErrorSize, weight: .bold))
                        .foregroundStyle(RemPhotoRxStyles.errorTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, RemPhotoRxStyles.promptErrorMarginTop)
                }
                RemPhotoRxPromptActions(
                    busy: busy,
                    busySource: busySource,
                    profilePhoto: profilePhoto,
                    onSelectPhoto: onSelectPhoto,
                    onDecline: onDecline
                )
            }
            .padding(RemPhotoRxStyles.promptCardPadding)
            .frame(maxWidth: RemPhotoRxStyles.promptCardMaxWidth, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RemPhotoRxStyles.promptCardRadius))
            .shadow(color: Theme.ink.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal, RemPhotoRxStyles.promptBackdropPaddingHorizontal)
        }
    }
}

/// `PromptCopy` : icône, titre et explication selon l'objectif.
struct RemPhotoRxPromptCopy: View {
    let profilePhoto: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IonIcon(name: profilePhoto ? "person-circle-outline" : "camera-outline", size: 26, color: Theme.primary)
                .frame(width: RemPhotoRxStyles.promptIconSize, height: RemPhotoRxStyles.promptIconSize)
                .background(RemPhotoRxStyles.promptIconBackground)
                .clipShape(RoundedRectangle(cornerRadius: RemPhotoRxStyles.promptIconRadius))
            Text(profilePhoto
                 ? "Duello Web demande ta photo de profil"
                 : "Duello Web demande une photo")
                .font(.system(size: RemPhotoRxStyles.promptTitleSize, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, RemPhotoRxStyles.promptTitleMarginTop)
            Text(profilePhoto
                 ? "Choisis ou prends la photo à utiliser. Elle sera recadrée, transmise à la page web connectée et rendue visible sur ton profil public."
                 : "Choisis une image existante ou prends ta copie en photo. Elle sera transmise automatiquement à la page web connectée.")
                .font(.system(size: RemPhotoRxStyles.promptBodySize, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, RemPhotoRxStyles.promptBodyMarginTop)
        }
    }
}

/// `PhotoAction` : bouton de source (appareil photo / photothèque).
struct RemPhotoRxPromptAction: View {
    let icon: String
    let label: String
    let primary: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                IonIcon(name: icon, size: 19, color: primary ? Theme.surface : Theme.ink)
                Text(label).font(.system(size: 13, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: RemPhotoRxStyles.promptButtonMinHeight)
            .foregroundStyle(primary ? Theme.surface : Theme.ink)
            .background(primary ? Theme.primary : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: RemPhotoRxStyles.promptButtonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: RemPhotoRxStyles.promptButtonRadius)
                    .stroke(primary ? Color.clear : Theme.border, lineWidth: 1)
            )
            .opacity(disabled ? RemPhotoRxStyles.promptDisabledOpacity : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

/// `PromptActions` : deux sources (ordre selon l'objectif) puis « Pas maintenant ».
struct RemPhotoRxPromptActions: View {
    let busy: Bool
    let busySource: RemPhotoRxPickerSource?
    let profilePhoto: Bool
    let onSelectPhoto: (RemPhotoRxPickerSource) -> Void
    let onDecline: () -> Void

    private var sources: [RemPhotoRxPickerSource] {
        profilePhoto ? [.library, .camera] : [.camera, .library]
    }

    private func label(_ source: RemPhotoRxPickerSource) -> String {
        source == .library
            ? (profilePhoto ? "Choisir ma photo" : "Choisir une image")
            : "Prendre une photo"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: RemPhotoRxStyles.promptActionsGap) {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    RemPhotoRxPromptAction(
                        icon: source == .camera ? "camera" : "images",
                        label: busySource == source ? "Envoi…" : label(source),
                        primary: index == 0,
                        disabled: busy,
                        action: { onSelectPhoto(source) }
                    )
                }
            }
            .padding(.top, RemPhotoRxStyles.promptActionsMarginTop)
            Button(action: onDecline) {
                Text("Pas maintenant")
                    .font(.system(size: RemPhotoRxStyles.promptDismissTextSize, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: RemPhotoRxStyles.promptDismissMinHeight)
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .padding(.top, RemPhotoRxStyles.promptDismissMarginTop)
        }
    }
}

/// `RemotePhotoCaptureCoordinator` : monte l'invite au niveau racine et
/// présente les sélecteurs demandés par le coordinateur.
struct RemPhotoRxCaptureHost: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator = RemPhotoRxCaptureCoordinator()

    var body: some View {
        ZStack {
            if let request = coordinator.request {
                RemPhotoRxCapturePrompt(
                    busy: coordinator.busy,
                    busySource: coordinator.busySource,
                    error: coordinator.error,
                    purpose: request.purpose,
                    onSelectPhoto: { source in Task { await coordinator.selectPhoto(source: source) } },
                    onDecline: { Task { await coordinator.decline() } }
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.15), value: coordinator.request?.id)
        .sheet(item: $coordinator.pickingSource, onDismiss: { coordinator.cancelPick() }) { source in
            picker(for: source)
        }
        .onAppear { coordinator.activate(token: session.token) }
        .onDisappear { coordinator.deactivate() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { coordinator.activate(token: session.token) }
            else { coordinator.deactivate() }
        }
    }

    @ViewBuilder private func picker(for source: RemPhotoRxPickerSource) -> some View {
        // `useRemotePhotoCapturePrompt.ts:110-116` : qualité 0.82 ; recadrage carré
        // 1:1 (`allowsEditing` / `aspect [1,1]`) pour une photo de profil.
        let profilePhoto = coordinator.request?.purpose == .profilePhoto
        switch source {
        case .camera:
            RemPhotoCameraPicker(
                allowsEditing: profilePhoto,
                quality: 0.82,
                onPick: { assets in
                    guard let asset = assets.first else { coordinator.cancelPick(); return }
                    Task { await coordinator.submit(asset: asset, source: .camera) }
                },
                onError: { error in coordinator.report(error) }
            )
        case .library:
            RemPhotoLibraryPicker(
                selectionLimit: 1,
                cropSquare: profilePhoto,
                quality: 0.82,
                onPick: { assets in
                    guard let asset = assets.first else { coordinator.cancelPick(); return }
                    Task { await coordinator.submit(asset: asset, source: .library) }
                }
            )
        }
    }
}

// MARK: - Montage racine

extension View {
    /// Monte l'invite de capture à distance au niveau racine, comme
    /// `RemotePhotoCaptureCoordinator` monté par `App.tsx:2603`. À appliquer
    /// dans le `ZStack` racine de `DuelloApp` (garde `session.isSignedIn`) :
    /// l'hôte hérite alors de `SessionStore` et de `scenePhase`.
    ///
    /// À raccorder (lot IMPL-09) : `DuelloApp.swift:151-157` doit ajouter
    /// `RemPhotoRxCaptureHost()` (ou ce modificateur) dans son `ZStack`, sous
    /// `if session.isSignedIn`.
    func remPhotoRxCaptureHost() -> some View {
        overlay { RemPhotoRxCaptureHost() }
    }
}
