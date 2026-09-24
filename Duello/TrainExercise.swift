import Foundation

/// Nature du sujet, qui décide de l'accord des libellés (`getItemLabel`,
/// `availabilityLabel`, `successLabel` de `SubjectsScreen.tsx`).
enum TrainExerciseKind {
    case exercise
    case colle
    case dissertation

    /// Nom au singulier.
    var singular: String {
        switch self {
        case .exercise: return "exercice"
        case .colle: return "colle"
        case .dissertation: return "dissertation"
        }
    }

    /// Colles et dissertations sont féminines dans les libellés accordés.
    var isFeminine: Bool { self != .exercise }

    /// Nom accordé au nombre annoncé.
    func noun(count: Int) -> String { count > 1 ? singular + "s" : singular }
}

/// Un exercice servi par l'API, avec l'identifiant d'item utilisé par
/// l'avancement local.
struct TrainExercise: Identifiable, Hashable {
    let key: String
    let chapterId: String
    let title: String
    let difficulty: Int?
    let solution: String?
    /// Énoncé servi. Jeté avant la phase 2 : il est nécessaire à la revue de
    /// prérequis (`ProgPrereq.review(_:)` lit le texte du sujet).
    let statement: String
    /// Revue de prérequis du sujet, calculée au chargement du chapitre ; `nil`
    /// tant qu'elle n'a pas été demandée, ou quand la filière n'est pas servie.
    var prerequisiteReview: ProgPrereqReview?

    /// Identifiant d'item `chapitre::exercice::clé` (`servedBank.ts`), la clé
    /// sous laquelle `ProgressStore` enregistre une tentative.
    var id: String { TrainItemID.make(chapterId: chapterId, key: key) }

    /// Égalité par identifiant d'item : `id` est l'identité partagée avec
    /// `ProgressStore`. La revue de prérequis, chargée après coup, ne doit pas
    /// changer l'identité d'un sujet (`ProgPrereqReview` n'est pas `Hashable`).
    static func == (lhs: TrainExercise, rhs: TrainExercise) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Le serveur laisse le corrigé absent tant que la relecture n'a pas eu lieu.
    var hasSolution: Bool {
        !(solution ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(seed: DuelloAPI.ChapterExercise) {
        key = seed.key
        chapterId = seed.chapterId
        title = seed.title
        difficulty = seed.difficulty
        solution = seed.solution
        statement = seed.statement
        prerequisiteReview = nil
    }

    /// Port de `groupItemsByDifficulty` : on entre dans un chapitre par le plus
    /// accessible, l'ordre de la banque étant conservé à l'intérieur d'un
    /// palier. Un palier absent de `DIFFICULTY_ORDER` ferme la marche au lieu
    /// d'être perdu, le contenu servi n'étant pas garanti sur les six niveaux.
    static func orderedByDifficulty(_ items: [TrainExercise]) -> [TrainExercise] {
        let known = TrainDifficulty.order.flatMap { level in
            items.filter { $0.difficulty == level }
        }
        let unknown = items.filter { item in
            guard let difficulty = item.difficulty else { return true }
            return !TrainDifficulty.order.contains(difficulty)
        }
        return known + unknown
    }
}
