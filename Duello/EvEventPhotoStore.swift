//
//  EvEventPhotoStore.swift
//  Duello
//
//  Enregistrement des photos rendues avec la copie : chaque page choisie est
//  écrite en JPEG dans un dossier applicatif, et c'est son URI de fichier qui
//  devient une entrée du brouillon — les photos restent donc référencées même
//  après une fermeture de l'application, comme les `photoUris` d'Expo.
//
//  Fichiers source Expo portés : `src/components/event/EventPhotoSheet.tsx`
//  (qualité de compression 0,8) et `src/utils/eventDrafts.ts` (photoUris).
//
//  Cible : iOS 16.
//
import Foundation
import UIKit

enum EvEventPhotoStore {
    /// Qualité JPEG demandée par la source (`quality: 0.8`).
    static let jpegQuality: CGFloat = 0.8
    /// Dossier applicatif des photos d'événement.
    static let directoryName = "duello-events"

    /// Enregistre une image en JPEG et rend son URI de fichier.
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: jpegQuality),
              let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try data.write(to: url)
            return url.absoluteString
        } catch {
            return nil
        }
    }
}
