import Foundation

/// Message affiché pour une erreur du client Duello.
enum TrainErrorMessage {
    /// Message localisé du client quand il en porte un, repli sinon.
    static func text(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return "Le contenu Duello est injoignable."
    }
}
