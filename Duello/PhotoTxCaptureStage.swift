//
//  PhotoTxCaptureStage.swift
//  Duello
//
//  Étape de capture de la transcription photo (`PhotoCaptureStage.tsx`).
//  Découpage de `PhotoTranscriptionView.swift` — aucun changement de comportement
//  (mêmes noms, mêmes corps, mêmes chaînes, mêmes visibilités EFFECTIVES).
//

import SwiftUI
import UIKit
import PhotosUI
import Photos
import AVFoundation

// MARK: - Étape de capture

/// Port de `PhotoCaptureStage.tsx` : portée puis prise de vue ou import. Le panneau
/// `remote` (téléphone connecté) n'est pas porté : jamais atteint sur iOS.
struct PhotoTxCaptureStage: View {
    @ObservedObject var controller: PhotoTxController
    @State private var isCameraPresented = false
    @State private var isLibraryPresented = false
    @State private var libraryItems: [PhotosPickerItem] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            scopeTabs
            captureButtons
            if !controller.state.error.isEmpty {
                // `error` : 11pt gras 700, `colors.danger` (encre #0A0D0C).
                Text(controller.state.error)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
            if !controller.state.notice.isEmpty {
                // `notice` : 10pt gras 700, `colors.inkSoft` (refus du consentement IA).
                Text(controller.state.notice)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            PhotoTxCameraPicker(
                onPick: { image in
                    isCameraPresented = false
                    controller.dispatch(.pickPhoto(from: .camera, scope: controller.state.scope, images: [image], failure: nil))
                },
                onCancel: { isCameraPresented = false }
            )
        }
        .photosPicker(isPresented: $isLibraryPresented, selection: $libraryItems, maxSelectionCount: 24, matching: .images)
        .onChange(of: libraryItems) { items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { images.append(image) }
                }
                libraryItems = []
                controller.dispatch(.pickPhoto(from: .library, scope: controller.state.scope, images: images,
                                               failure: images.isEmpty ? PhotoTxText.photoUnavailable : nil))
            }
        }
        // Consentement IA accordé : la source mémorisée est ouverte maintenant,
        // donc après la fenêtre et non après la photo (`21#3`).
        .onChange(of: controller.selecteurDemande) { source in
            guard let source else { return }
            controller.selecteurDemande = nil
            ouvrir(source)
        }
    }

    /// Libellé de portée employé par les étiquettes d'accessibilité de la source
    /// (`PhotoCaptureStage.tsx:90,99`).
    private var scopeLabel: String {
        controller.state.scope == .question ? PhotoTxText.questionTab : PhotoTxText.exerciseTab
    }

    /// `captureTabs` + `CaptureTab` : deux onglets pleine largeur, le sélectionné
    /// souligné d'une ligne `primary` de 2pt, la rangée bordée de 1pt (`border`).
    private var scopeTabs: some View {
        HStack(spacing: 0) {
            scopeTab(PhotoTxText.questionTab, scope: .question)
            scopeTab(PhotoTxText.exerciseTab, scope: .exercise)
        }
        .background(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    private func scopeTab(_ title: String, scope: PhotoTxScope) -> some View {
        let selected = controller.state.scope == scope
        return Button {
            controller.dispatch(.setCaptureScope(scope))
        } label: {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(selected ? Theme.primary : Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                Rectangle()
                    .fill(selected ? Theme.primary : Color.clear)
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// Les deux voies de capture (`captureActions` : rangée, gap 10, marginTop 12).
    /// Sans appareil photo (le simulateur, par exemple) ou sans autorisation, la
    /// source remonte le message exact plutôt que d'ouvrir un sélecteur qui ne
    /// rendrait rien.
    private var captureButtons: some View {
        HStack(spacing: 10) {
            Button { startCamera() } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "camera", size: 19, color: Theme.surface)
                    Text(PhotoTxText.takePhoto)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.surface)
                }
                // `captureButton` : `paddingHorizontal: 8` interne (`styles:73`).
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(scopeLabel) : prendre une photo")
            Button { startLibrary() } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "images-outline", size: 18, color: Theme.primary)
                    Text(PhotoTxText.chooseImages)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                }
                // `captureButton` : `paddingHorizontal: 8` interne (`styles:73`).
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(scopeLabel) : choisir des images")
        }
        .padding(.top, 12)
    }

    private func startCamera() {
        // `photoTranscriptionAllowed` : l'accord de partage IA est demandé AVANT
        // d'ouvrir la caméra ; le sélecteur n'est ouvert qu'après acceptation.
        guard controller.autoriserCapture(.camera) else { return }
        ouvrir(.camera)
    }

    private func startLibrary() {
        guard controller.autoriserCapture(.library) else { return }
        ouvrir(.library)
    }

    /// Ouvre le sélecteur demandé, une fois l'accord de partage obtenu. Sans
    /// appareil photo (le simulateur, par exemple) ou sans autorisation, la
    /// source remonte le message exact plutôt que d'ouvrir un sélecteur vide.
    private func ouvrir(_ source: PhotoTxSource) {
        switch source {
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                controller.dispatch(.pickPhoto(from: .camera, scope: controller.state.scope, images: [], failure: PhotoTxText.photoUnavailable))
            } else if status == .denied || status == .restricted {
                controller.dispatch(.pickPhoto(from: .camera, scope: controller.state.scope, images: [], failure: PhotoTxText.cameraPermission))
            } else {
                isCameraPresented = true
            }
        case .library:
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .denied || status == .restricted {
                controller.dispatch(.pickPhoto(from: .library, scope: controller.state.scope, images: [], failure: PhotoTxText.libraryPermission))
            } else {
                isLibraryPresented = true
            }
        }
    }
}
