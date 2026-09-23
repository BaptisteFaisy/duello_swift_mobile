import Foundation
import Combine

// MARK: - Avancement item par item

/// Résultat d'une tentative d'exercice ou de colle, du pire au meilleur
/// (voir `ItemOutcome` de `src/utils/exerciseProgress.ts`).
enum ItemOutcome: String, Codable {
    case fail
    case partial
    case success

    /// Rang de comparaison, pour ne jamais rétrograder le meilleur résultat
    /// acquis (équivalent de `OUTCOME_RANK` côté Expo).
    var rank: Int {
        switch self {
        case .fail: return 0
        case .partial: return 1
        case .success: return 2
        }
    }
}

/// Suivi d'un item (exercice ou colle), aligné sur `ItemProgress` d'Expo.
struct ItemProgress: Codable, Equatable {
    /// Nombre total de fois où l'item a été tenté.
    var attempts: Int = 0
    /// Réussites complètes.
    var successes: Int = 0
    /// Réussites partielles.
    var partials: Int = 0
    /// Meilleur résultat jamais atteint, `nil` tant que l'item n'a pas été tenté.
    var bestOutcome: ItemOutcome? = nil
    /// Minutes mises la première fois que l'item a été entièrement réussi.
    var firstSuccessMinutes: Int? = nil
}

// MARK: - Bilans par matière

/// Bilan d'entraînement d'une matière pour un type d'item, aligné sur
/// `TrainingStat` d'`EnhancedProgressScreen.tsx`. Le total n'annonce que les
/// items réellement servis : une matière sans contenu reste à zéro.
struct TrainingStat: Equatable {
    /// Items servis pour la matière.
    var total: Int = 0
    /// Items dont le meilleur résultat est une réussite complète.
    var mastered: Int = 0
    /// Items au moins une fois tentés.
    var attempted: Int = 0
    /// Somme des tentatives des items tentés.
    var attempts: Int = 0

    /// Fraction de maîtrise, bornée à [0, 1] ; 0 sans contenu servi.
    var fraction: Double {
        total > 0 ? Double(mastered) / Double(total) : 0
    }
}

/// Gain d'XP horodaté (`XpEntry` de `types.ts` réduit au tracé), pour la courbe
/// d'XP de la vitrine (`ChartXpSeries.build`).
struct ProgressXpEntry: Codable, Equatable {
    /// XP du gain.
    var xp: Double
    /// Instant du gain, en millisecondes depuis l'époque Unix.
    var at: Double
}

/// Déplacement d'Elo horodaté (`history` de `useSubjectElo`), pour la courbe
/// d'Elo de la vitrine.
struct ProgressEloEntry: Codable, Equatable {
    /// Matière du déplacement.
    var subject: String
    /// Cote de la matière après le déplacement.
    var elo: Int
    /// Instant du déplacement, en millisecondes depuis l'époque Unix.
    var at: Double
}

/// Défis joués et gagnés dans une matière (voir `DuelStat` d'Expo).
struct DuelStat: Codable, Equatable {
    var played: Int = 0
    var won: Int = 0

    /// Taux de victoire, borné à [0, 1] ; 0 sans défi joué.
    var fraction: Double {
        played > 0 ? Double(won) / Double(played) : 0
    }

    /// Taux de victoire arrondi, en pourcentage (le `Math.round` d'Expo).
    var winRatePercent: Int {
        played > 0 ? Int((Double(won) / Double(played) * 100).rounded()) : 0
    }
}

// MARK: - Store

/// Progression locale de l'élève : activité d'entraînement, avancement item par
/// item, défis et cote par matière. Portage de `utils/activity.ts`,
/// `utils/exerciseProgress.ts` et `utils/subjectElo.ts`, persisté comme
/// `SessionStore` : un seul JSON dans les préférences (`UserDefaults`).
///
/// Les méthodes d'écriture (`recordExercise`, `recordDuel`…) vivent dans
/// `ProgressStore+Training.swift`, les lectures et agrégats (`trainingStat`,
/// `currentStreak`…) dans `ProgressStore+Stats.swift`. Les propriétés stockées,
/// la persistance et les outils partagés restent ici : une `extension` ne peut
/// pas ajouter de propriété stockée.
final class ProgressStore: ObservableObject {

    // MARK: Activité

    /// Exercices terminés, toutes matières confondues.
    @Published var exercisesCompleted: Int = 0
    /// Défis terminés.
    @Published var challengesCompleted: Int = 0
    /// Défis gagnés.
    @Published var challengesWon: Int = 0
    /// Questions réussies.
    @Published var correctQuestions: Int = 0
    /// Minutes d'entraînement cumulées.
    @Published var exerciseMinutes: Int = 0
    /// Journées travaillées, en clés `AAAA-MM-JJ`.
    @Published var activeDays: [String] = []
    /// Minutes cumulées par matière ; la clé est le nom affiché de la matière,
    /// comme `activity.subjectMinutes[subject.name]` côté Expo.
    @Published var subjectMinutes: [String: Int] = [:]

    // MARK: Progression, défis et cote

    /// Avancement item par item, indexé par identifiant d'item.
    @Published var items: [String: ItemProgress] = [:]
    /// Défis joués et gagnés par matière (clé = nom affiché de la matière).
    @Published var duels: [String: DuelStat] = [:]
    /// Cote Elo par matière (clé = nom affiché de la matière).
    @Published var subjectElos: [String: Int] = [:]

    // MARK: XP, programme et historiques

    /// XP totale acquise (`activityXp(activity)` = `buildXpSummary(activity).total`).
    @Published var totalXp: Double = 0
    /// Couverture du programme menant aux concours, en pourcentage
    /// (`competitionProgramPercent`).
    @Published var competitionProgramPercent: Int = 0
    /// Gains d'XP horodatés (`activity.history`), pour la courbe d'XP.
    @Published var xpHistory: [ProgressXpEntry] = []
    /// Déplacements d'Elo horodatés (`history` de `useSubjectElo`), pour la
    /// courbe d'Elo.
    @Published var eloHistory: [ProgressEloEntry] = []

    /// Cote de départ d'une matière jamais défiée (`INITIAL_SUBJECT_ELO`).
    static let initialElo = 1100

    private static let storageKey = "com.duello.ios.progress"

    init() {
        restore()
    }

    // MARK: Persistance

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let snapshot = try? JSONDecoder().decode(ProgressSnapshot.self, from: data)
        else { return }

        exercisesCompleted = snapshot.exercisesCompleted
        challengesCompleted = snapshot.challengesCompleted
        challengesWon = snapshot.challengesWon
        correctQuestions = snapshot.correctQuestions
        exerciseMinutes = snapshot.exerciseMinutes
        activeDays = snapshot.activeDays
        subjectMinutes = snapshot.subjectMinutes
        items = snapshot.items
        duels = snapshot.duels
        subjectElos = snapshot.subjectElos
        totalXp = snapshot.totalXp
        competitionProgramPercent = snapshot.competitionProgramPercent
        xpHistory = snapshot.xpHistory
        eloHistory = snapshot.eloHistory
    }

    /// Écrit l'instantané courant dans les préférences. `internal` : appelée par
    /// les méthodes d'écriture de `ProgressStore+Training.swift`.
    func persist() {
        var snapshot = ProgressSnapshot()
        snapshot.exercisesCompleted = exercisesCompleted
        snapshot.challengesCompleted = challengesCompleted
        snapshot.challengesWon = challengesWon
        snapshot.correctQuestions = correctQuestions
        snapshot.exerciseMinutes = exerciseMinutes
        snapshot.activeDays = activeDays
        snapshot.subjectMinutes = subjectMinutes
        snapshot.items = items
        snapshot.duels = duels
        snapshot.subjectElos = subjectElos
        snapshot.totalXp = totalXp
        snapshot.competitionProgramPercent = competitionProgramPercent
        snapshot.xpHistory = xpHistory
        snapshot.eloHistory = eloHistory

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    // MARK: Outils partagés

    /// Instant courant, en millisecondes depuis l'époque Unix (`Date.now()`).
    static func nowMilliseconds() -> Double {
        Date().timeIntervalSince1970 * 1000
    }

    /// Nom de matière utilisable comme clé, `nil` quand il est vide.
    static func subjectKey(_ subject: String?) -> String? {
        let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Instantané persisté

/// Contenu du JSON unique écrit dans les préférences. Les champs absents ou
/// d'un type inattendu sont relus à zéro : un stockage partiel ne doit jamais
/// effacer le reste de la progression (même esprit que `UserProfile`).
private struct ProgressSnapshot: Codable {
    var exercisesCompleted: Int = 0
    var challengesCompleted: Int = 0
    var challengesWon: Int = 0
    var correctQuestions: Int = 0
    var exerciseMinutes: Int = 0
    var activeDays: [String] = []
    var subjectMinutes: [String: Int] = [:]
    var items: [String: ItemProgress] = [:]
    var duels: [String: DuelStat] = [:]
    var subjectElos: [String: Int] = [:]
    var totalXp: Double = 0
    var competitionProgramPercent: Int = 0
    var xpHistory: [ProgressXpEntry] = []
    var eloHistory: [ProgressEloEntry] = []

    enum CodingKeys: String, CodingKey {
        case exercisesCompleted, challengesCompleted, challengesWon, correctQuestions
        case exerciseMinutes, activeDays, subjectMinutes, items, duels, subjectElos
        case totalXp, competitionProgramPercent, xpHistory, eloHistory
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exercisesCompleted = Self.readCount(container, .exercisesCompleted)
        challengesCompleted = Self.readCount(container, .challengesCompleted)
        challengesWon = Self.readCount(container, .challengesWon)
        correctQuestions = Self.readCount(container, .correctQuestions)
        exerciseMinutes = Self.readCount(container, .exerciseMinutes)
        activeDays = ((try? container.decode([String].self, forKey: .activeDays)) ?? [])
            .filter { !$0.isEmpty }
        subjectMinutes = Self.readMinutes(container)
        items = (try? container.decode([String: ItemProgress].self, forKey: .items)) ?? [:]
        duels = (try? container.decode([String: DuelStat].self, forKey: .duels)) ?? [:]
        subjectElos = (try? container.decode([String: Int].self, forKey: .subjectElos)) ?? [:]
        totalXp = max(0, (try? container.decode(Double.self, forKey: .totalXp)) ?? 0)
        competitionProgramPercent = min(
            100,
            max(0, (try? container.decode(Int.self, forKey: .competitionProgramPercent)) ?? 0)
        )
        xpHistory = (try? container.decode([ProgressXpEntry].self, forKey: .xpHistory)) ?? []
        eloHistory = (try? container.decode([ProgressEloEntry].self, forKey: .eloHistory)) ?? []
    }

    /// Compteur relu sans erreur, jamais négatif.
    private static func readCount(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Int {
        max(0, (try? container.decode(Int.self, forKey: key)) ?? 0)
    }

    /// Cumuls par matière relus sans erreur : les entrées vides ou nulles sont
    /// écartées, comme `normalizeSubjectMinutes` côté Expo.
    private static func readMinutes(
        _ container: KeyedDecodingContainer<CodingKeys>
    ) -> [String: Int] {
        let stored = (try? container.decode([String: Int].self, forKey: .subjectMinutes)) ?? [:]
        return stored.filter { !$0.key.isEmpty && $0.value > 0 }
    }
}
