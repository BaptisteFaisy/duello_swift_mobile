import SwiftUI

// Porté depuis les composants Expo du dossier
// `src/components/remote-photo-connection/` (lot N, photo à distance) :
//   RemotePhotoConnection.tsx, RemotePhotoIntro.tsx.
// Côté iOS, l'appareil est le téléphone : la variante web (panneau
// ordinateur, photos reçues) est fournie séparément (`RemPhotoReceivedGrid`),
// la surface ordinateur restant le web. Le libellé d'intro reprend donc la
// branche « téléphone » de `RemotePhotoIntro.tsx`.

/// Écran « Connecter au PC » : liaison du téléphone à Duello sur ordinateur.
struct RemPhotoConnectionView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var controller = RemPhotoController()
    @State private var cameraPresented = false
    @State private var libraryPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RemPhotoIntro()
            RemPhotoPhonePanel(
                connected: controller.connected,
                sending: controller.sending,
                onCamera: {
                    Task { @MainActor in
                        guard await RemPhotoCameraAccess.ensure() else {
                            controller.report(RemPhotoError(
                                message: "Autorise l'appareil photo pour envoyer ta copie.",
                                status: 403,
                                code: "camera-permission-denied"
                            ))
                            return
                        }
                        cameraPresented = true
                    }
                },
                onLibrary: { libraryPresented = true }
            )
            RemPhotoConnectionMessage(kind: .notice, text: controller.notice)
            RemPhotoConnectionMessage(kind: .error, text: controller.error)
            RemPhotoSecurityNote()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .onAppear { Task { @MainActor in controller.activate(token: session.token) } }
        .onDisappear { Task { @MainActor in controller.deactivate() } }
        .sheet(isPresented: $cameraPresented) {
            RemPhotoCameraPicker(
                onPick: { assets in
                    cameraPresented = false
                    Task { @MainActor in await controller.send(assets: assets) }
                },
                onError: { error in
                    cameraPresented = false
                    Task { @MainActor in controller.report(error) }
                }
            )
        }
        .sheet(isPresented: $libraryPresented) {
            RemPhotoLibraryPicker(
                selectionLimit: 8,
                onPick: { assets in
                    libraryPresented = false
                    Task { @MainActor in await controller.send(assets: assets) }
                }
            )
        }
    }
}

/// Ton d'un message de connexion.
enum RemPhotoMessageKind: Equatable {
    case notice
    case error
}

/// `RemotePhotoIntro` (branche téléphone).
struct RemPhotoIntro: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 44, height: 44)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            VStack(alignment: .leading, spacing: 4) {
                Text("Connecter au PC")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Cette page connecte ton téléphone à Duello sur ton ordinateur. Connecte-toi au même compte sur ton PC : la liaison est automatique.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// `ConnectionMessage` : bandeau notice / erreur, masqué si le texte est vide.
struct RemPhotoConnectionMessage: View {
    let kind: RemPhotoMessageKind
    let text: String

    private var isError: Bool { kind == .error }
    private var tint: Color { isError ? Theme.like : Theme.progress }

    var body: some View {
        if !text.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isError ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
    }
}

/// `SecurityNote` : rappel de confidentialité.
struct RemPhotoSecurityNote: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 12, weight: .semibold))
            Text("Tes photos restent privées et expirent automatiquement.")
                .font(.system(size: 12))
        }
        .foregroundStyle(Theme.inkFaint)
    }
}
