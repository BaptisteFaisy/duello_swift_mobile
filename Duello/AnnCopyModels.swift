import Foundation
import UIKit

// MARK: - Correction de copie : statuts et modèles

/// Statut d'une correction de copie (`AnnaleCopyCorrectionStatus`).
enum AnnCopyStatus: String, Codable, CaseIterable, Identifiable {
    case uploading
    case queued
    case reading
    case grading
    case ready
    case failed

    var id: String { rawValue }

    /// Libellé affiché (`annaleCopyStatusLabel`), mot pour mot.
    var label: String {
        switch self {
        case .uploading: return "Envoi des pages"
        case .queued: return "Dans la file de correction"
        case .reading: return "Lecture de la copie"
        case .grading: return "Vérification des raisonnements"
        case .ready: return "Correction prête"
        case .failed: return "Correction interrompue"
        }
    }

    /// Un job est actif tant qu'il n'a pas atteint un statut terminal
    /// (`isAnnaleCopyJobActive`) : `ready` et `failed` sont terminaux.
    var isActive: Bool { self != .ready && self != .failed }
}

/// Retour du correcteur sur un exercice précis de la copie.
struct AnnCopyExerciseFeedback: Codable, Equatable, Identifiable {
    var label: String
    var score: Double
    var maxScore: Double
    var feedback: String

    var id: String { label }

    /// Note de l'exercice, formatée comme l'app Expo : `score/maxScore`.
    var scoreLabel: String {
        "\(AnnCopyFormat.trimmed(score))/\(AnnCopyFormat.trimmed(maxScore))"
    }
}

/// Compte rendu d'une partie corrigée (`AnnaleCopyCorrectionResult`).
struct AnnCopyResult: Codable, Equatable {
    var score: Double
    var summary: String
    var strengths: [String]
    var improvements: [String]
    var exerciseFeedback: [AnnCopyExerciseFeedback]

    /// Note ramenée sur 20, une décimale, comme `score.toFixed(1)`.
    var scoreLabel: String { AnnCopyFormat.oneDecimal(score) }
}

/// Page photographiée d'une copie (`AnnaleCopyPage`), conservée en base64.
struct AnnCopyPage: Identifiable, Equatable {
    let id = UUID()
    var imageBase64: String
    var mimeType: String

    /// Octets JPEG de la page, décodés depuis le base64.
    var imageData: Data? {
        Data(base64Encoded: imageBase64)
    }

    /// Clé de cache stable de la page (un `id` = une page).
    var cacheKey: String {
        "anncopy-page-\(id.uuidString)"
    }

    /// Image décodée, servie par le cache partagé : renvoie l'image si elle est
    /// déjà décodée, sinon déclenche le décodage hors main thread (une seule
    /// fois). La grille, elle, se rafraîchit via `CachedImage`.
    var image: UIImage? {
        guard let data = imageData else { return nil }
        return ImageCache.shared.load(data, key: cacheKey)
    }

    /// Qualité d'enregistrement reprise de l'app Expo (`quality: 0.78`).
    static let jpegQuality: CGFloat = 0.78
}

/// Une correction de copie suivie par l'application
/// (`AnnaleCopyCorrectionJob`).
struct AnnCopyJob: Codable, Equatable, Identifiable {
    var jobId: String
    var attemptKey: String
    var itemId: String
    var title: String
    /// Partie de l'épreuve couverte par les pages envoyées.
    var partLabel: String
    var status: AnnCopyStatus
    /// Avancement en pourcentage, calculé localement pendant l'envoi.
    var progress: Double
    var estimatedSeconds: Double
    var pageCount: Int
    var createdAt: Double
    var updatedAt: Double
    var notifyOnReady: Bool
    var result: AnnCopyResult? = nil
    var error: String? = nil

    var id: String { jobId }

    var isActive: Bool { status.isActive }

    /// Libellé du statut.
    var statusLabel: String { status.label }

    /// Fraction affichée par la barre : plancher visuel de 3 %, comme Expo.
    var progressFraction: Double {
        max(3, min(100, progress)) / 100
    }

    /// Estimation du temps restant, mot pour mot de la fenêtre Expo.
    var estimateLabel: String {
        guard estimatedSeconds > 0 else { return "" }
        if estimatedSeconds < 60 { return "moins d’une minute" }
        let minutes = Int((estimatedSeconds / 60).rounded(.up))
        return "environ \(minutes) min"
    }
}

/// Mises en forme numériques partagées par la correction de copie.
enum AnnCopyFormat {
    /// Nombre à une décimale, comme `Number.toFixed(1)`.
    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Nombre débarrassé de sa décimale inutile (barème entier).
    static func trimmed(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return oneDecimal(value)
    }
}

// MARK: - Persistance locale des corrections

/// Stockage local des corrections de copie, aligné sur la clé Expo
/// `ACCOUNT_STORAGE_KEYS.annaleCopyCorrections`.
enum AnnCopyStore {
    static let storageKey = "prepapp-annale-copy-corrections:v1"
    /// `saveAnnaleCopyCorrectionJobs` conserve les 40 entrées les plus récentes.
    static let maxJobs = 40

    static func load() -> [AnnCopyJob] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        let jobs = (try? JSONDecoder().decode([AnnCopyJob].self, from: data)) ?? []
        return jobs.map { job in
            var normalized = job
            let trimmed = job.partLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            // Compatibilité avec les corrections créées avant les dépôts par
            // partie : elles portent alors le libellé « Copie complète ».
            normalized.partLabel = trimmed.isEmpty ? "Copie complète" : trimmed
            return normalized
        }
    }

    static func save(_ jobs: [AnnCopyJob]) {
        let sorted = jobs.sorted { $0.updatedAt > $1.updatedAt }
        let bounded = Array(sorted.prefix(maxJobs))
        guard let data = try? JSONEncoder().encode(bounded) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
