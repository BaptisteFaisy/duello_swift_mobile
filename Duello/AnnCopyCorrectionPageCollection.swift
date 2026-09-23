import SwiftUI
import UIKit

// MARK: - Collecte des pages d'une partie

/// Collecte des pages de la partie : grille des vignettes, ajout et retrait,
/// ouverture de l'appareil photo (repli sur la photothèque). Extension de
/// `AnnCopyCorrectionSheet`.
extension AnnCopyCorrectionSheet {
    var pageGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            if let data = page.imageData {
                                CachedImage(.data(data, key: page.cacheKey)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    pagePlaceholder
                                }
                            } else {
                                pagePlaceholder
                            }
                        }
                        .frame(height: 145)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        Text("Page \(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(9)
                    }
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                    Button {
                        removePage(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.like)
                            .padding(7)
                            .background(Theme.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(7)
                    .accessibilityLabel("Supprimer la page \(index + 1)")
                }
            }
        }
    }

    /// Repli d'une vignette sans image : fond muet et icône document.
    private var pagePlaceholder: some View {
        ZStack {
            Theme.surfaceMuted
            Image(systemName: "doc.text")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    func append(pages additions: [AnnCopyPage]) {
        guard !additions.isEmpty else { return }
        var next = pages
        next.append(contentsOf: additions)
        pages = Array(next.prefix(Self.maxPages))
    }

    private func removePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages.remove(at: index)
    }

    /// Ouvre l'appareil photo, ou la photothèque à défaut.
    ///
    /// `Info.plist` ne déclare pas encore `NSCameraUsageDescription` : sans
    /// cette clé, iOS interrompt l'application dès l'accès à l'appareil photo.
    /// Le bouton se replie donc sur la photothèque en affichant le message de
    /// permission de l'application Expo, plutôt que de rester sans effet.
    func requestCamera() {
        errorMessage = ""
        let available = UIImagePickerController.isSourceTypeAvailable(.camera)
        let declared = (Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        if available && declared {
            activePicker = .camera
            return
        }
        errorMessage = "Autorise l’appareil photo pour photographier ta copie."
        activePicker = .library
    }
}
