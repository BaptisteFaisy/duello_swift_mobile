import SwiftUI

/// Statut du cours d'un chapitre (`Chapter['courseStatus']`), dans l'ordre du
/// cycle d'appui : à venir → en cours → vu → à venir.
enum TrainCourseStatus: String, CaseIterable {
    case notStarted = "not-started"
    case inProgress = "in-progress"
    case completed = "completed"

    /// Libellé affiché (`COURSE_STATUS_LABELS`).
    var label: String {
        switch self {
        case .notStarted: return "À venir"
        case .inProgress: return "En cours"
        case .completed: return "Vu"
        }
    }

    /// Icône du rond de statut (`COURSE_STATUS_ICONS`, transposée en SF Symbols).
    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "clock"
        case .completed: return "checkmark.circle"
        }
    }

    /// Couleur du rond de statut (`COURSE_STATUS_COLORS`).
    var tint: Color {
        switch self {
        case .notStarted: return Theme.inkFaint
        case .inProgress: return Theme.inkSoft
        case .completed: return Theme.progress
        }
    }

    /// Statut suivant du cycle (`toggleCourseStatus`).
    var next: TrainCourseStatus {
        switch self {
        case .notStarted: return .inProgress
        case .inProgress: return .completed
        case .completed: return .notStarted
        }
    }
}

/// Statut de cours des chapitres, persisté localement.
///
/// L'écran Expo range `courseStatus` dans la progression de matière ; le port
/// n'a pas encore de store partagé pour ce champ. En attendant, ce store local
/// tient la même information, dans un JSON séparé, sous la même convention de
/// persistance que `SessionStore` et `ProgressStore`.
final class TrainCourseStatusStore: ObservableObject {
    @Published private(set) var statuses: [String: String] = [:]

    private static let storageKey = "com.duello.ios.training.course-status"

    init() {
        restore()
    }

    /// Statut d'un chapitre ; « À venir » tant qu'il n'a jamais été touché.
    func status(for chapterId: String) -> TrainCourseStatus {
        guard let raw = statuses[chapterId], let status = TrainCourseStatus(rawValue: raw) else {
            return .notStarted
        }
        return status
    }

    /// Fait avancer un chapitre d'un cran dans le cycle des statuts.
    func cycle(_ chapterId: String) {
        guard !chapterId.isEmpty else { return }
        statuses[chapterId] = status(for: chapterId).next.rawValue
        persist()
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        statuses = stored.filter { !$0.key.isEmpty && TrainCourseStatus(rawValue: $0.value) != nil }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(statuses) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
