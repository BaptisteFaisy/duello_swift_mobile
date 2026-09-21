//
//  EvEventPhotoSheet.swift
//  Duello
//
//  Rendu photo de l'événement : le participant choisit toutes ses pages d'un
//  coup, elles s'affichent en petit à la place des champs de réponse et une
//  vignette s'agrandit à l'appui.
//
//  Ces photos ne sont jamais transcrites pendant l'épreuve : elles partent avec
//  la copie, puis rejoignent le compte rendu après la correction. Le
//  participant garde le moyen de revenir aux champs écrits ou dictés.
//
//  Fichier source Expo porté : `src/components/event/EventPhotoSheet.tsx`.
//  Substitutions SF Symbols : images-outline → photo.on.rectangle.angled ;
//  add → plus.
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit

struct EvEventPhotoSheet: View {
    let photoUris: [String]
    let onPhotos: ([String]) -> Void

    @State private var zoomedUri: String?
    @State private var picking = false

    /// Nombre de pages rendues d'un coup (`selectionLimit: 24`).
    private let selectionLimit = 24

    var body: some View {
        VStack(spacing: 10) {
            if photoUris.isEmpty {
                pickButton
            } else {
                thumbnails
                replaceButton
            }
        }
        .padding(.bottom, 24)
        .sheet(isPresented: $picking) {
            EvEventPhotoLibraryPicker(selectionLimit: selectionLimit) { uris in
                picking = false
                if !uris.isEmpty { onPhotos(uris) }
            }
        }
        .overlay(zoomOverlay)
    }

    /// Bouton d'invite quand aucune page n'est encore rendue.
    private var pickButton: some View {
        Button { picking = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text("Soumettre des photos pour tout le sujet")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Soumettre les photos pour tout le sujet")
    }

    /// Pellicule horizontale des pages rendues, chaque vignette agrandissable.
    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(photoUris.enumerated()), id: \.offset) { index, uri in
                    Button { zoomedUri = uri } label: {
                        thumbnail(uri)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Agrandir la photo \(index + 1)")
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Bouton d'ajout ou de remplacement des pages.
    private var replaceButton: some View {
        Button { picking = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Ajouter / remplacer")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.inkSoft)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
        .buttonStyle(.plain)
    }

    /// Une vignette de page, lue depuis son URI de fichier.
    @ViewBuilder private func thumbnail(_ uri: String) -> some View {
        if let image = localImage(uri) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 100)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        } else {
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .fill(Theme.surfaceMuted)
                .frame(width: 76, height: 100)
        }
    }

    /// Fenêtre plein écran : la vignette s'agrandit, un appui la referme.
    @ViewBuilder private var zoomOverlay: some View {
        if let uri = zoomedUri, let image = localImage(uri) {
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            }
            .contentShape(Rectangle())
            .onTapGesture { zoomedUri = nil }
        }
    }

    /// Image locale d'une URI de fichier, `nil` si elle est illisible.
    private func localImage(_ uri: String) -> UIImage? {
        guard let url = URL(string: uri) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
