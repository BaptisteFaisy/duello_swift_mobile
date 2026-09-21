import SwiftUI

// Porté depuis `src/components/remote-photo-connection/RemotePhotoPhonePanel.tsx`
// (lot N, photo à distance). Panneau du téléphone : en attente du PC, puis
// boutons « Prendre une photo » et « Choisir dans mes photos » avec la
// progression d'envoi. La sélection réelle est déléguée à la vue appelante.

/// Carte de connexion du téléphone.
struct RemPhotoPhonePanel: View {
    let connected: Bool
    let sending: RemPhotoSendingProgress?
    let onCamera: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if connected {
                RemPhotoConnectedPhoneBody(sending: sending, onCamera: onCamera, onLibrary: onLibrary)
            } else {
                RemPhotoWaitingBody()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }
}

/// `WaitingPanel` : indicateur d'attente et consigne de compte.
struct RemPhotoWaitingBody: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("En attente — connecte-toi au même compte Duello sur ton ordinateur pour envoyer tes photos automatiquement.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// `ConnectedPhonePanel` : confirmation d'appairage et boutons d'envoi.
struct RemPhotoConnectedPhoneBody: View {
    let sending: RemPhotoSendingProgress?
    let onCamera: () -> Void
    let onLibrary: () -> Void

    private var busy: Bool { sending != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.progress)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("PC connecté")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Les prochaines photos apparaîtront sur l’ordinateur.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            RemPhotoPhotoSendButton(sending: sending, action: onCamera)
            Button(action: onLibrary) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choisir dans mes photos")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Theme.ink)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
    }
}

/// `PhotoSendButton` : capture directe, libellé de progression pendant l'envoi.
struct RemPhotoPhotoSendButton: View {
    let sending: RemPhotoSendingProgress?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if sending != nil {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "camera")
                }
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(sending != nil)
    }

    private var label: String {
        if let sending { return "Envoi \(sending.current)/\(sending.total)…" }
        return "Prendre une photo"
    }
}
