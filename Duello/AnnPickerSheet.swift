import Foundation

// MARK: - Sélecteur d'image demandé

/// Sélecteur d'image ouvert par la fenêtre de correction de copie.
enum AnnPickerSheet: String, Identifiable {
    case camera
    case library

    var id: String { rawValue }
}
