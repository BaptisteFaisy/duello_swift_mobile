// [SubjProgramMerge] Fusion du programme de filière et de la progression locale.
// Porté de `src/screens/SubjectsScreen.tsx` (lignes 1005-1085 :
// `LEGACY_CHAPTER_IDS`, `mergeWithProgram`) et
// `src/utils/subjectProgress.ts` (`findStoredChapterById`).

import Foundation

/// Correspondances minimales pour conserver la progression de l'ancien
/// découpage de chapitres (`LEGACY_CHAPTER_IDS`).
enum SubjLegacyChapterIDs {
    /// Ancien identifiant(s) encore susceptible de porter le statut d'un
    /// chapitre renommé.
    static let map: [String: [String]] = [
        "raisonnement": ["sommes-produits"],
        "ensembles-applications": ["raisonnement"],
        "fonctions-usuelles": ["convexite"],
        "derivation-successive": ["taylor-developpements-limites"],
        "espaces-vectoriels": ["dimension"],
        "matrices-applications-lineaires": ["applications-lineaires"],
        "espaces-probabilises-finis": [
            "espaces-probabilises",
            "denombrement",
            "probabilites-conditionnelles",
            "variables-finies",
            "lois-finies-usuelles",
            "lois-usuelles",
        ],
        "variables-discretes": ["lois-discretes-usuelles", "lois-usuelles"],
        "couples-discrets": ["couples-finis"],
        "taylor-developpements-limites": ["developpements-limites", "taylor"],
        "analyse-concours": ["series-complements"],
        "fonctions-plusieurs-variables": ["fonctions-deux-variables"],
        "calcul-differentiel": [
            "optimisation",
            "optimisation-premier-ordre",
            "optimisation-second-ordre",
            "optimisation-contrainte",
        ],
        "valeurs-propres": ["polynomes-annulateurs"],
        "algebre-bilineaire": ["projection-orthogonale"],
        "endomorphismes-symetriques": ["reduction-symetrique"],
        "variables-densite": ["lois-densite-usuelles", "moments"],
        "couples-vecteurs": ["sommes-variables-independantes"],
        "convergences": ["convergence-loi"],
        "estimation-ponctuelle": ["estimation", "estimation-intervalles"],
    ]

    /// Anciens identifiants d'un chapitre ; liste vide s'il n'a jamais été
    /// renommé.
    static func aliases(for chapterId: String) -> [String] {
        map[chapterId] ?? []
    }
}

/// Statut de colle d'un chapitre (`colleStatus`), conservé pour ne pas perdre
/// les saisies déjà enregistrées : les modes exercices et colles partagent
/// désormais `courseStatus` et `masteryLevel`.
enum SubjColleStatus: String, CaseIterable {
    case todo
    case prepared
    case done
}

/// Chapitre d'une matière dans la progression locale.
struct SubjChapter: Identifiable, Hashable {
    let id: String
    let name: String
    let domain: String?
    /// Prérequis du chapitre. Le programme Swift (`TrackChapter`) ne les porte
    /// pas encore : la fusion les laisse vides.
    var prerequisites: [String]
    var courseStatus: TrainCourseStatus
    var masteryLevel: Int?
    var colleStatus: SubjColleStatus
}

/// Matière de la progression locale (`Subject`).
struct SubjSubject: Identifiable, Hashable {
    let id: String
    let name: String
    let fullName: String?
    let icon: String
    var lastUpdate: Date?
    var chapters: [SubjChapter]
}

/// Chapitre tel qu'il revient du stockage local (JSON non typé côté Expo).
struct SubjStoredChapter: Decodable {
    let id: String?
    let courseStatus: String?
    let masteryLevel: Int?
    let colleStatus: String?
}

/// Matière telle qu'elle revient du stockage local.
struct SubjStoredSubject: Decodable {
    let id: String?
    /// `lastUpdate` revient du stockage sous forme de chaîne ISO.
    let lastUpdate: String?
    let chapters: [SubjStoredChapter]?
}

/// `mergeWithProgram` : repart du programme de la filière et y replace la
/// progression enregistrée. Une matière ou un chapitre ajouté au programme
/// apparaît donc immédiatement, sans effacer ce qui a déjà été coché.
enum SubjProgramMerge {
    /// `defaultCourseStatus` décide de ce qu'affiche un chapitre encore jamais
    /// renseigné (le programme de 1re année d'un élève de 2e année part à « vu »).
    static func mergeWithProgram(
        program: [TrackSubject],
        stored: [SubjStoredSubject],
        defaultCourseStatus: TrainCourseStatus
    ) -> [SubjSubject] {
        program.map { subject in
            let saved = stored.first { $0.id == subject.id }
            let savedChapters = saved?.chapters ?? []

            return SubjSubject(
                id: subject.id,
                name: subject.name,
                fullName: subject.fullName,
                icon: subject.icon,
                lastUpdate: date(from: saved?.lastUpdate),
                chapters: subject.chapters.map { chapter in
                    let savedChapter = findStoredChapter(
                        in: savedChapters,
                        chapterId: chapter.id,
                        legacyIds: SubjLegacyChapterIDs.aliases(for: chapter.id)
                    )
                    return SubjChapter(
                        id: chapter.id,
                        name: chapter.name,
                        domain: chapter.domain,
                        prerequisites: [],
                        courseStatus: courseStatus(of: savedChapter, default: defaultCourseStatus),
                        masteryLevel: savedChapter?.masteryLevel,
                        colleStatus: colleStatus(of: savedChapter)
                    )
                }
            )
        }
    }

    /// `findStoredChapterById` : l'entrée du découpage actuel d'abord, puis un
    /// ancien identifiant. Les traiter dans un seul `first` ferait hériter deux
    /// lignes du même statut.
    static func findStoredChapter(
        in stored: [SubjStoredChapter],
        chapterId: String,
        legacyIds: [String]
    ) -> SubjStoredChapter? {
        if let exact = stored.first(where: { $0.id == chapterId }) { return exact }
        return stored.first { item in
            guard let id = item.id else { return false }
            return legacyIds.contains(id)
        }
    }

    /// `lastUpdate` revient du stockage sous forme de chaîne : on la reconvertit.
    static func date(from raw: String?) -> Date? {
        guard let raw else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    /// Statut de cours retenu : une valeur stockée inconnue retombe sur le
    /// défaut plutôt que de faire échouer la lecture.
    private static func courseStatus(
        of chapter: SubjStoredChapter?,
        default fallback: TrainCourseStatus
    ) -> TrainCourseStatus {
        guard let raw = chapter?.courseStatus,
              let status = TrainCourseStatus(rawValue: raw) else { return fallback }
        return status
    }

    /// Statut de colle retenu ; « à préparer » par défaut.
    private static func colleStatus(of chapter: SubjStoredChapter?) -> SubjColleStatus {
        guard let raw = chapter?.colleStatus,
              let status = SubjColleStatus(rawValue: raw) else { return .todo }
        return status
    }
}
