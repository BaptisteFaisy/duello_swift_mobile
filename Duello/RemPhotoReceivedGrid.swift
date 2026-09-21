import SwiftUI
import UIKit

// Porté depuis `src/components/remote-photo-connection/RemotePhotoReceivedPhotos.tsx`
// (lot N, photo à distance). Grille des photos reçues côté ordinateur :
// aperçu, nom, taille, « Télécharger » et suppression. Sur iOS,
// « Télécharger » ouvre la feuille de partage (Enregistrer dans Photos,
// Fichiers…) à la place de l'ancre `download` du navigateur.

/// `RemotePhotoReceivedPhotos` : liste des photos arrivées dans la session.
struct RemPhotoReceivedGrid: View {
    let photos: [RemPhotoReceivedPhoto]
    let onDelete: (RemPhotoReceivedPhoto) -> Void

    @State private var sharing: RemPhotoReceivedPhoto?

    var body: some View {
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photos reçues")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Télécharge-les pour les importer dans ta copie sur Duello.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(photos) { photo in
                        RemPhotoReceivedPhotoCard(
                            photo: photo,
                            onDownload: { sharing = photo },
                            onDelete: { onDelete(photo) }
                        )
                    }
                }
            }
            .sheet(item: $sharing) { photo in
                RemPhotoShareSheet(photo: photo)
            }
        }
    }
}

/// `RemotePhotoCard` : aperçu et actions d'une photo reçue.
struct RemPhotoReceivedPhotoCard: View {
    let photo: RemPhotoReceivedPhoto
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            preview
            VStack(alignment: .leading, spacing: 2) {
                Text(photo.fileName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(photo.sizeLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkFaint)
            }
            HStack(spacing: 8) {
                Button(action: onDownload) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                        Text("Télécharger").font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(Theme.ink)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                }
                .buttonStyle(.plain)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.like)
                        .padding(8)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder private var preview: some View {
        if let image = UIImage(data: photo.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 110)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        } else {
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .fill(Theme.surfaceMuted)
                .frame(height: 110)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.inkFaint)
                )
        }
    }
}

/// `downloadRemotePhoto` : feuille de partage iOS à la place de l'ancre web.
struct RemPhotoShareSheet: UIViewControllerRepresentable {
    let photo: RemPhotoReceivedPhoto

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items = RemPhotoShareSheet.writeTemporaryFile(photo).map { [$0] } ?? []
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}

    /// Écrit les octets dans un fichier temporaire partageable.
    static func writeTemporaryFile(_ photo: RemPhotoReceivedPhoto) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(photo.fileName)
        do {
            try photo.data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
