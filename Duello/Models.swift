import Foundation

// MARK: - Profil

/// Profil élève, aligné sur `UserProfile` de `src/types.ts` côté Expo.
/// Seuls les champs affichés ou envoyés au serveur sont portés ici.
struct UserProfile: Codable, Equatable {
    var displayName: String = ""
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var prepName: String = ""
    var prepCity: String = ""
    var holidayZone: String = ""
    var prepType: String? = nil
    var className: String = ""
    var track: String = ""
    var year: String = ""
    var specialty: String = ""
    var targetSchool: String = ""
    var personalGoal: String = ""
    var isPublic: Bool = false
    var photoUri: String? = nil

    enum CodingKeys: String, CodingKey {
        case displayName, firstName, lastName, email
        case prepName, prepCity, holidayZone, prepType
        case className = "class"
        case track, year, specialty, targetSchool
        case personalGoal, isPublic, photoUri
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = Self.string(c, .displayName)
        firstName = Self.string(c, .firstName)
        lastName = Self.string(c, .lastName)
        email = Self.string(c, .email)
        prepName = Self.string(c, .prepName)
        prepCity = Self.string(c, .prepCity)
        holidayZone = Self.string(c, .holidayZone)
        prepType = try? c.decodeIfPresent(String.self, forKey: .prepType)
        className = Self.string(c, .className)
        track = Self.string(c, .track)
        year = Self.string(c, .year)
        specialty = Self.string(c, .specialty)
        targetSchool = Self.string(c, .targetSchool)
        personalGoal = Self.string(c, .personalGoal)
        isPublic = (try? c.decodeIfPresent(Bool.self, forKey: .isPublic)) ?? false
        photoUri = try? c.decodeIfPresent(String.self, forKey: .photoUri)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(firstName, forKey: .firstName)
        try c.encode(lastName, forKey: .lastName)
        try c.encode(email, forKey: .email)
        try c.encode(prepName, forKey: .prepName)
        try c.encode(prepCity, forKey: .prepCity)
        try c.encode(holidayZone, forKey: .holidayZone)
        try c.encodeIfPresent(prepType, forKey: .prepType)
        try c.encode(className, forKey: .className)
        try c.encode(track, forKey: .track)
        try c.encode(year, forKey: .year)
        try c.encode(specialty, forKey: .specialty)
        try c.encode(targetSchool, forKey: .targetSchool)
        try c.encode(personalGoal, forKey: .personalGoal)
        try c.encode(isPublic, forKey: .isPublic)
        try c.encodeIfPresent(photoUri, forKey: .photoUri)
    }

    /// Le serveur envoie parfois `null` ou un nombre là où on attend du texte.
    private static func string(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String {
        (try? c.decode(String.self, forKey: key)) ?? ""
    }

    var initial: String {
        let source = firstName.trimmingCharacters(in: .whitespaces)
            .isEmpty ? displayName : firstName
        return String(source.prefix(1)).uppercased()
    }
}

// MARK: - Classements

/// Ligne d'un classement de matière ou d'XP hebdomadaire.
struct LeaderboardEntry: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let prepName: String
    var track: String?
    var specialty: String?
    var year: String?
    var elo: Int?
    var xp: Double?
    var isAnonymous: Bool?

    enum CodingKeys: String, CodingKey {
        case id, displayName, prepName, track, specialty, year, elo, xp
        case isAnonymous = "isAnonymous"
    }

    init(id: String, displayName: String, prepName: String,
         track: String? = nil, specialty: String? = nil, year: String? = nil,
         elo: Int? = nil, xp: Double? = nil, isAnonymous: Bool? = nil) {
        self.id = id
        self.displayName = displayName
        self.prepName = prepName
        self.track = track
        self.specialty = specialty
        self.year = year
        self.elo = elo
        self.xp = xp
        self.isAnonymous = isAnonymous
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        prepName = (try? c.decode(String.self, forKey: .prepName)) ?? ""
        track = try? c.decodeIfPresent(String.self, forKey: .track)
        specialty = try? c.decodeIfPresent(String.self, forKey: .specialty)
        year = try? c.decodeIfPresent(String.self, forKey: .year)
        elo = (try? c.decodeIfPresent(Int.self, forKey: .elo)) ?? nil
        xp = (try? c.decodeIfPresent(Double.self, forKey: .xp)) ?? nil
        isAnonymous = (try? c.decodeIfPresent(Bool.self, forKey: .isAnonymous)) ?? nil
    }
}

// MARK: - Programmes

/// Chapitre d'un programme de matière (voir `src/data/tracks.ts`).
struct TrackChapter: Identifiable, Hashable {
    let id: String
    let name: String
    let domain: String?
}

/// Matière d'un parcours, avec son programme découpé en chapitres.
struct TrackSubject: Identifiable, Hashable {
    let id: String
    let name: String
    let fullName: String?
    let icon: String
    let chapters: [TrackChapter]
}

// MARK: - Défis (matchmaking)

/// Ce qu'un joueur dépose dans la file en cherchant un adversaire
/// (voir `QueueRequest` de `src/utils/matchmaking.ts`).
struct QueueRequest: Codable, Equatable {
    var userId: String
    var displayName: String
    var prepName: String
    var track: String
    var year: String
    var specialty: String?
    var subject: String
    /// Clés des chapitres acceptés ; vide = toute la matière.
    var chapters: [String]
    var exercisePools: [String: [String]]
    var startedExerciseIds: [String]
    var allowStartedExercises: Bool
    var maxExercises: Int?
    var elo: Int
}

/// Note d'une copie par le correcteur (`ProductionAssessment` de
/// `utils/duel.ts` côté Expo) : le correcteur IA comme le barème local de
/// secours rendent cette même forme.
struct ProductionAssessment: Codable, Equatable {
    /// Note sur 100.
    var score: Int
    /// Commentaire court sur la copie.
    var note: String
}

/// Un défi formé par le serveur (voir `MatchView`).
struct MatchView: Codable, Equatable, Identifiable {
    struct Opponent: Codable, Equatable {
        /// Absent du payload réel du serveur : le serveur n'envoie pas
        /// l'identifiant de l'adversaire (voir `matchViewFor`), seulement son
        /// nom et sa prépa. Optional pour tolérer cette absence.
        var userId: String?
        var displayName: String
        var prepName: String
        var elo: Int?
        /// Vrai pour l'adversaire d'entraînement, jamais présenté comme un
        /// joueur réel (`MatchOpponent.training`).
        var training: Bool?
    }

    var id: String
    var seed: Int
    var subject: String
    var chapterKey: String
    var exerciseId: String
    var durationMinutes: Int
    var startedAt: Double
    var opponent: Opponent
}

/// État de la file, tel que le serveur le décrit au téléphone.
enum QueueState: Equatable {
    case waiting(ticket: String, waitedMs: Double, eloWindow: Int, queued: Int)
    case matched(ticket: String, match: MatchView)
    case expired
}

/// Copie remise à la fin d'un défi (voir `DuelSubmission`).
struct DuelSubmission: Codable, Equatable {
    /// Note sur 100.
    var score: Int
    /// Commentaire d'une phrase sur cette copie.
    var note: String
    /// La copie a bien été notée par l'IA.
    var graded: Bool
    /// Réponses rédigées, indexées par question.
    var answers: [String: String]
}

/// Résultat d'un défi, tel que le serveur le décrit à un joueur
/// (`DuelResultState` de `utils/matchmaking.ts`). Les enveloppes plates
/// `opponentScore`/`opponentNote` n'existent pas côté serveur : l'état réel est
/// `{state, deadline}` en attente, `{state, opponent, reason?, elo?}` tranché,
/// ou `{state: "expired"}.
enum DuelResultState: Equatable {
    /// Copie enregistrée ; l'adversaire n'a pas encore rendu la sienne.
    /// La date limite de remise arrive en millisecondes.
    case waiting(deadline: Double)
    /// Défi tranché. `opponent` vaut `null` quand l'adversaire a déclaré forfait.
    case settled(opponent: DuelSubmission?, reason: String?, elo: EloResult?)
    /// Partie inconnue du serveur : trop ancienne, ou serveur redémarré.
    case expired
}

// MARK: - Semaine XP

/// Clé de semaine : le lundi de la semaine contenant `at`, au format AAAA-MM-JJ
/// (aligné sur `weekKey` de `src/utils/subjectXp.ts`).
enum WeeklyXP {
    static func weekKey(at date: Date = Date()) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        // getDay() côté JS : dimanche = 0, qui termine la semaine.
        let daysSinceMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: start) ?? start
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: monday)
    }
}
