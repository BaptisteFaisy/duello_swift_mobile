import Foundation

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
final class ProgressStore: ObservableObject {

    // MARK: Activité

    /// Exercices terminés, toutes matières confondues.
    @Published private(set) var exercisesCompleted: Int = 0
    /// Défis terminés.
    @Published private(set) var challengesCompleted: Int = 0
    /// Défis gagnés.
    @Published private(set) var challengesWon: Int = 0
    /// Questions réussies.
    @Published private(set) var correctQuestions: Int = 0
    /// Minutes d'entraînement cumulées.
    @Published private(set) var exerciseMinutes: Int = 0
    /// Journées travaillées, en clés `AAAA-MM-JJ`.
    @Published private(set) var activeDays: [String] = []
    /// Minutes cumulées par matière ; la clé est le nom affiché de la matière,
    /// comme `activity.subjectMinutes[subject.name]` côté Expo.
    @Published private(set) var subjectMinutes: [String: Int] = [:]

    // MARK: Progression, défis et cote

    /// Avancement item par item, indexé par identifiant d'item.
    @Published private(set) var items: [String: ItemProgress] = [:]
    /// Défis joués et gagnés par matière (clé = nom affiché de la matière).
    @Published private(set) var duels: [String: DuelStat] = [:]
    /// Cote Elo par matière (clé = nom affiché de la matière).
    @Published private(set) var subjectElos: [String: Int] = [:]

    /// Cote de départ d'une matière jamais défiée (`INITIAL_SUBJECT_ELO`).
    static let initialElo = 1100

    private static let storageKey = "com.duello.ios.progress"

    init() {
        restore()
    }

    // MARK: Écriture

    /// Enregistre une tentative d'exercice ou de colle, puis persiste.
    ///
    /// La signature suit `recordOutcome` (Expo) : l'identifiant d'item suffit à
    /// tenir l'avancement. Une tentative compte pour un exercice terminé et
    /// marque la journée comme travaillée. La matière est facultative ; quand
    /// elle est fournie, les minutes rejoignent aussi son cumul, comme le fait
    /// une session d'entraînement côté Expo.
    func recordExercise(
        itemId: String,
        outcome: ItemOutcome,
        minutes: Int? = nil,
        subject: String? = nil
    ) {
        let id = itemId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }

        items[id] = Self.applyOutcome(items[id], outcome: outcome, minutes: minutes)
        exercisesCompleted += 1
        credit(minutes: minutes, to: subject)
        markActiveDay()
        persist()
    }

    /// Enregistre un défi joué, gagné ou perdu, puis persiste : le compteur
    /// global, le bilan de la matière et la journée travaillée
    /// (voir `applySession` d'`activity.ts`).
    func recordDuel(subject: String, won: Bool, minutes: Int = 0) {
        challengesCompleted += 1
        if won { challengesWon += 1 }

        if let name = Self.subjectKey(subject) {
            var stat = duels[name] ?? DuelStat()
            stat.played += 1
            if won { stat.won += 1 }
            duels[name] = stat
        }

        credit(minutes: minutes, to: subject)
        markActiveDay()
        persist()
    }

    /// Crédite une question réussie (voir `recordCorrectQuestionXp` d'Expo).
    func recordCorrectQuestion() {
        correctQuestions += 1
        markActiveDay()
        persist()
    }

    /// Fixe la cote d'une matière. Le déplacement est calculé par l'arbitrage
    /// des défis (`developmentEloDelta` côté Expo) ; le store ne fait que la
    /// retenir pour l'affichage, par matière et par compte.
    func recordElo(subject: String, elo: Int) {
        guard let name = Self.subjectKey(subject) else { return }
        subjectElos[name] = max(0, elo)
        persist()
    }

    // MARK: Lecture

    /// Fraction de remplissage de la barre d'avancement d'un item, d'après son
    /// meilleur résultat (voir `progressFraction` d'`exerciseProgress.ts`) :
    /// 0,25 après un échec, 0,6 après une réussite partielle, 1 une fois réussi.
    func progressFraction(for itemId: String) -> Double {
        guard let best = items[itemId]?.bestOutcome else { return 0 }
        switch best {
        case .fail: return 0.25
        case .partial: return 0.6
        case .success: return 1
        }
    }

    /// Agrège l'entraînement d'une matière sur les items de sa banque servie.
    /// Seuls les items disponibles sont comptés, comme `trainingStats` (Expo).
    func trainingStat(forItemIds itemIds: [String]) -> TrainingStat {
        var stat = TrainingStat()
        stat.total = itemIds.count
        for itemId in itemIds {
            guard let item = items[itemId] else { continue }
            if item.attempts > 0 {
                stat.attempted += 1
                stat.attempts += item.attempts
            }
            if item.bestOutcome == .success {
                stat.mastered += 1
            }
        }
        return stat
    }

    /// Défis joués et gagnés dans une matière.
    func duelStat(for subject: String) -> DuelStat {
        duels[subject] ?? DuelStat()
    }

    /// Cote d'une matière : 1100 tant qu'aucun défi ne l'a déplacée
    /// (`getSubjectElo` d'`subjectElo.ts`).
    func subjectElo(for subject: String) -> Int {
        subjectElos[subject] ?? Self.initialElo
    }

    /// Nombre de journées travaillées (`activity.activeDays.length`).
    func activeDayCount() -> Int {
        activeDays.count
    }

    /// Temps d'entraînement cumulé, formaté (« 3 h 20 »).
    func formattedTrainingTime() -> String {
        Self.formatTrainingTime(minutes: exerciseMinutes)
    }

    /// Minutes formatées pour l'affichage, reprises de `formatTrainingTime` :
    /// « 45 min » sous l'heure, « 3 h » pile, « 3 h 20 » au-delà.
    static func formatTrainingTime(minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        guard safeMinutes >= 60 else { return "\(safeMinutes) min" }

        let hours = safeMinutes / 60
        let rest = safeMinutes % 60
        guard rest > 0 else { return "\(hours) h" }
        return "\(hours) h \(String(format: "%02d", rest))"
    }

    // MARK: Jour d'activité

    /// Jour local au format `AAAA-MM-JJ`, pour compter des journées et non des
    /// instants (voir `dayKey` d'`activity.ts`).
    static func dayKey(at date: Date = Date()) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    /// Ajoute la journée locale à la série d'activité, au plus une fois par jour
    /// (voir `applyActiveDay` d'`activity.ts`).
    private func markActiveDay(at date: Date = Date()) {
        let day = Self.dayKey(at: date)
        guard !activeDays.contains(day) else { return }
        activeDays.append(day)
    }

    // MARK: Outils internes

    /// Applique un résultat à l'état d'un item et renvoie le nouvel état
    /// (voir `applyOutcome` d'`exerciseProgress.ts`). Le temps n'est capturé
    /// qu'à la toute première réussite complète.
    static func applyOutcome(
        _ current: ItemProgress?,
        outcome: ItemOutcome,
        minutes: Int?
    ) -> ItemProgress {
        var next = current ?? ItemProgress()
        next.attempts += 1
        if outcome == .success { next.successes += 1 }
        if outcome == .partial { next.partials += 1 }

        // Le meilleur résultat ne redescend jamais ; -1 place un item encore
        // jamais tenté sous le pire des résultats.
        if outcome.rank > (next.bestOutcome?.rank ?? -1) {
            next.bestOutcome = outcome
        }

        if outcome == .success, next.firstSuccessMinutes == nil, let minutes = minutes {
            next.firstSuccessMinutes = minutes
        }
        return next
    }

    /// Ajoute des minutes au total et, quand la matière est connue, à son cumul.
    private func credit(minutes: Int?, to subject: String?) {
        let spent = max(0, minutes ?? 0)
        guard spent > 0 else { return }

        exerciseMinutes += spent
        guard let name = Self.subjectKey(subject) else { return }
        subjectMinutes[name, default: 0] += spent
    }

    /// Nom de matière utilisable comme clé, `nil` quand il est vide.
    private static func subjectKey(_ subject: String?) -> String? {
        let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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
    }

    private func persist() {
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

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
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

    enum CodingKeys: String, CodingKey {
        case exercisesCompleted, challengesCompleted, challengesWon, correctQuestions
        case exerciseMinutes, activeDays, subjectMinutes, items, duels, subjectElos
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
