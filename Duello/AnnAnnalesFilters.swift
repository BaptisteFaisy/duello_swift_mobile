import Foundation

// MARK: - Types d'épreuve par filière

/// Listes de types d'épreuve proposées au filtre, par filière
/// (`ECG_ANNALE_TYPES` et consorts de `annaleTypes.ts`).
enum AnnAnnaleTypes {
    static let ecg: [String] = ["Maths I", "Maths I-III", "Maths II", "EDHEC", "EMLYON", "ECRICOME"]
    static let mp: [String] = ["X-ENS A", "X-ENS B", "X-ENS C", "CCMP 1", "CCMP 2", "CCS 1", "CCS 2", "CCINP 1", "CCINP 2"]
    static let mpi: [String] = ["X-ENS M", "X-ENS M-I", "CCMP 1", "CCMP 2", "CCS 1", "CCS 2", "CCINP 1", "CCINP 2"]
    static let pc: [String] = ["X-ENS", "CCMP 1", "CCMP 2", "CCS 1", "CCS 2", "CCINP 1", "CCINP 2"]

    /// Liste propre à la filière affichée (`annaleTypeOptions`).
    static func options(track: String, specialty: String = "") -> [String] {
        switch track {
        case "ECG":
            return specialty.hasPrefix("Maths appliquées") ? ecg : ecg.filter { $0 != "Maths I-III" }
        case "MP", "MP*", "MP/MP*":
            return mp
        case "MPI":
            return mpi
        case "PC", "PT", "PSI":
            return pc
        default:
            return []
        }
    }
}

// MARK: - Filtres de la liste

/// Un choix proposé par un menu de filtre.
struct AnnFilterOption: Identifiable, Hashable {
    var id: String
    var label: String
    /// Palier de difficulté, renseigné pour le menu « Difficulté ».
    var difficulty: Int? = nil
}

/// Un menu de filtre, aligné sur `ExerciseBadgeGroup` (`exerciseBadgeFilter.ts`).
struct AnnFilterGroup: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case type
        case domain
        case difficulty
        case prerequisite
    }

    var kind: Kind
    var label: String
    var options: [AnnFilterOption]

    var id: String { kind.rawValue }
}

extension AnnFilterGroup {
    /// `PREREQUISITE_FILTER_OPTIONS` de `exerciseBadgeFilter.ts`.
    static let prerequisiteOptions: [String] = ["Prêt", "En partie", "Plus tard"]
}
