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
        // `COURSE_STATUS_COLORS.completed = colors.mastery` (#22C55E), le vert
        // commun de réussite — et non `colors.progress` (#16A34A).
        case .completed: return Theme.mastery
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

/// Visibilité persistée de la légende du statut de cours (`useCourseLegendVisibility`
/// de `hooks/useCourseLegendVisibility.ts`).
///
/// L'écran Expo range le masquage sous `ACCOUNT_STORAGE_KEYS.courseProgressLegendDismissed`,
/// par compte : une fois l'encart refermé, il ne revient ni à la réouverture
/// d'une matière ni au redémarrage. Le port n'a pas encore de stockage par
/// compte, ce store local tient le même drapeau dans un JSON séparé, sous la
/// même convention de persistance que `TrainCourseStatusStore`.
///
/// Le drapeau gouverne **les deux** usages de la légende : l'encart explicatif
/// animé (tête de matière) et le rappel statique (pied de la liste).
final class TrainCourseLegendStore: ObservableObject {
    /// Vrai tant que l'élève n'a pas refermé l'encart.
    @Published private(set) var isVisible: Bool = true

    private static let storageKey = "com.duello.ios.training.course-legend-dismissed"

    init() {
        restore()
    }

    /// Referme l'encart et retient le masquage (équivalent de `dismiss` du hook).
    func dismiss() {
        guard isVisible else { return }
        isVisible = false
        UserDefaults.standard.set(true, forKey: Self.storageKey)
    }

    private func restore() {
        isVisible = !UserDefaults.standard.bool(forKey: Self.storageKey)
    }
}
