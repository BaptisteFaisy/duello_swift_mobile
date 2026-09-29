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
    /// Parcours détaillé (`academicPath` de `src/types.ts:72-76`), ajouté après
    /// le format historique `track`/`year`/`specialty`. Irrégulièrement présent
    /// (comptes existants) : `normalizeAcademicPath` le reconstruit alors.
    var academicPath: AcademicPath? = nil
    var targetSchool: String = ""
    var personalGoal: String = ""
    /// Rythme quotidien (`src/types.ts:80-84`, défauts de `src/data.ts:28-32`) :
    /// évité automatiquement par la répartition du plan
    /// (`EnhancedPlanScreen.tsx:574-576`). Absents des comptes historiques : les
    /// valeurs par défaut de la source s'appliquent alors.
    var dinnerDurationMinutes: Int = 30
    var showerDurationMinutes: Int = 15
    var dinnerTime: String = "19:30"
    var showerTime: String = "21:30"
    var bedtime: String = "23:00"
    var isPublic: Bool = false
    var photoUri: String? = nil

    enum CodingKeys: String, CodingKey {
        case displayName, firstName, lastName, email
        case prepName, prepCity, holidayZone, prepType
        case className = "class"
        case track, year, specialty, academicPath, targetSchool
        case personalGoal, isPublic, photoUri
        case dinnerDurationMinutes, showerDurationMinutes
        case dinnerTime, showerTime, bedtime
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
        academicPath = try? c.decodeIfPresent(AcademicPath.self, forKey: .academicPath)
        targetSchool = Self.string(c, .targetSchool)
        personalGoal = Self.string(c, .personalGoal)
        // Comptes historiques : la clé peut manquer ou valoir vide, on garde le
        // défaut de la source plutôt que de repartir d'une valeur nulle.
        if let value = try? c.decode(String.self, forKey: .dinnerTime), !value.isEmpty { dinnerTime = value }
        if let value = try? c.decode(Int.self, forKey: .dinnerDurationMinutes) { dinnerDurationMinutes = value }
        if let value = try? c.decode(String.self, forKey: .showerTime), !value.isEmpty { showerTime = value }
        if let value = try? c.decode(Int.self, forKey: .showerDurationMinutes) { showerDurationMinutes = value }
        if let value = try? c.decode(String.self, forKey: .bedtime), !value.isEmpty { bedtime = value }
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
        try c.encodeIfPresent(academicPath, forKey: .academicPath)
        try c.encode(targetSchool, forKey: .targetSchool)
        try c.encode(personalGoal, forKey: .personalGoal)
        try c.encode(dinnerDurationMinutes, forKey: .dinnerDurationMinutes)
        try c.encode(showerDurationMinutes, forKey: .showerDurationMinutes)
        try c.encode(dinnerTime, forKey: .dinnerTime)
        try c.encode(showerTime, forKey: .showerTime)
        try c.encode(bedtime, forKey: .bedtime)
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

    /// Filière réellement suivie (`currentTrackForProfile`) : normalisée, elle
    /// remplace le champ historique `track`, qui perd BCPST et B/L derrière
    /// MPSI (`RankingsScreen.tsx:403-407`).
    var followedTrack: String {
        AcademicPathNormalization.currentTrackForProfile(self)
    }
}

// MARK: - Parcours scolaire (filière suivie)

/// Parcours détaillé du compte (`AcademicPath` de `src/types.ts:32-41`).
/// Ajouté après le format historique `track`/`year`/`specialty` ; optionnel
/// pour les comptes existants, que `normalizeAcademicPath` reconstruit.
struct AcademicPath: Codable, Equatable {
    /// Filière réellement suivie pendant l'année indiquée dans le profil.
    var currentTrack: String
    /// Filière suivie en 1re année, conservée pour les révisions cumulatives.
    var firstYearTrack: String
    /// Option de 1re année lorsqu'elle modifie le programme étudié.
    var firstYearOption: String
    /// Option actuelle lorsqu'elle modifie le programme étudié.
    var currentOption: String
}

/// Filière suivie **normalisée** du compte (`normalizeAcademicPath` /
/// `currentTrackForProfile` de `src/utils/academicPath.ts`).
///
/// La filière normalisée remplace le champ historique `track`, qui perd BCPST
/// et B/L derrière MPSI : un élève BCPST a `track == "MPSI"`. Les ligues Elo
/// doivent donc suivre la filière suivie (`RankingsScreen.tsx:403-407`).
enum AcademicPathNormalization {
    /// `FIRST_YEAR_TRACKS` (`academicPath.ts:8-16`).
    static let firstYearTracks = ["MPSI", "MP2I", "PCSI", "PTSI", "BCPST", "B/L", "ECG"]
    /// `SECOND_YEAR_TRACKS` (`academicPath.ts:17-26`).
    static let secondYearTracks = ["MP", "MPI", "PC", "PT", "PSI", "BCPST", "B/L", "ECG"]
    /// `LYCEE_YEARS` (`academicPath.ts:207`).
    static let lyceeYears = ["2de", "1re", "Terminale"]
    /// `LYCEE_TRACKS` (`academicPath.ts:215`).
    static let lyceeTracks = ["Lycée"]

    /// `currentTrackChoices` : filières proposées selon l'année du profil.
    static func currentTrackChoices(year: String) -> [String] {
        if lyceeYears.contains(year) { return lyceeTracks }
        return year == "1re année" ? firstYearTracks : secondYearTracks
    }

    /// `defaultCurrentTrack` : filière de repli d'un profil enregistré.
    static func defaultCurrentTrack(track: String, year: String) -> String {
        if track == "ECG" { return "ECG" }
        if track == "Lycée" { return "Lycée" }
        return year == "1re année" ? "MPSI" : "MP"
    }

    /// `currentTrackForProfile` : filière réellement suivie.
    ///
    /// `academicPath.currentTrack` prime lorsqu'il appartient aux filières de
    /// l'année ; sinon repli sur `defaultCurrentTrack(track:year:)`, puis sur la
    /// première filière autorisée (résolution de `normalizeAcademicPath`).
    static func currentTrackForProfile(_ profile: UserProfile) -> String {
        let allowed = currentTrackChoices(year: profile.year)
        if let saved = profile.academicPath?.currentTrack, allowed.contains(saved) {
            return saved
        }
        let fallback = defaultCurrentTrack(track: profile.track, year: profile.year)
        return allowed.contains(fallback) ? fallback : (allowed.first ?? "")
    }
}

// MARK: - Classements

/// Ligne d'un classement de matière ou d'XP hebdomadaire.
struct LeaderboardEntry: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let prepName: String
    var track: String?
    /// Filière réellement suivie renvoyée par le serveur (`currentTrack` de
    /// `SubjectLeaderboardEntry` / `WeeklyXpEntry`) : rejoue le filtre de
    /// cohorte côté client et l'étiquette académique des lignes XP.
    var currentTrack: String?
    var specialty: String?
    var year: String?
    var elo: Int?
    var xp: Double?
    var isAnonymous: Bool?

    enum CodingKeys: String, CodingKey {
        case id, displayName, prepName, track, currentTrack, specialty, year, elo, xp
        case isAnonymous = "isAnonymous"
    }

    init(id: String, displayName: String, prepName: String,
         track: String? = nil, currentTrack: String? = nil,
         specialty: String? = nil, year: String? = nil,
         elo: Int? = nil, xp: Double? = nil, isAnonymous: Bool? = nil) {
        self.id = id
        self.displayName = displayName
        self.prepName = prepName
        self.track = track
        self.currentTrack = currentTrack
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
        currentTrack = try? c.decodeIfPresent(String.self, forKey: .currentTrack)
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
    /// Défi planifié visé, quand l'entrée en file vient d'un rendez-vous
    /// (`request.scheduledChallengeId`, cf. `ChalQueue.enter`). Absent sinon.
    var scheduledChallengeId: String?
    /// Départ prévu du défi planifié, en millisecondes
    /// (`request.scheduledStartAt`). Absent hors défi planifié.
    var scheduledStartAt: Double?
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
        /// Filière de l'adversaire (`MatchOpponent.track`) ; le serveur ne
        /// l'envoie pas toujours, d'où l'optionnel.
        var track: String?
        /// Année de l'adversaire (`MatchOpponent.year`) ; optionnelle pour la
        /// même raison.
        var year: String?
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
    /// Série commune tirée pour ce défi (`match.exerciseSequence`) ; le premier
    /// élément reprend `chapterKey` et `exerciseId`. Le serveur peut l'omettre
    /// (défaut `[]`, cf. `init(from:)` ci-dessous).
    var exerciseSequence: [ChalExerciseRef] = []
    /// Vrai si ce joueur avait déjà ouvert l'exercice avant ce défi.
    var exercisePreviouslyStarted: Bool = false
    /// Vrai si l'adversaire avait déjà ouvert l'exercice.
    var opponentPreviouslyStarted: Bool = false
    var durationMinutes: Int
    var startedAt: Double
    var opponent: Opponent
}

extension MatchView {
    /// Décodage tolérant : les trois champs de série/avis ci-dessus ne sont pas
    /// garantis par le payload serveur (le serveur peut les omettre) — on
    /// retombe alors sur leurs valeurs par défaut. Les autres clés restent
    /// requises, comme pour la conformance synthétisée. L'initialiseur
    /// membre-à-membre reste synthétisé (l'extension ne le supprime pas).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        seed = try container.decode(Int.self, forKey: .seed)
        subject = try container.decode(String.self, forKey: .subject)
        chapterKey = try container.decode(String.self, forKey: .chapterKey)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        exerciseSequence = try container
            .decodeIfPresent([ChalExerciseRef].self, forKey: .exerciseSequence) ?? []
        exercisePreviouslyStarted = try container
            .decodeIfPresent(Bool.self, forKey: .exercisePreviouslyStarted) ?? false
        opponentPreviouslyStarted = try container
            .decodeIfPresent(Bool.self, forKey: .opponentPreviouslyStarted) ?? false
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        startedAt = try container.decode(Double.self, forKey: .startedAt)
        opponent = try container.decode(Opponent.self, forKey: .opponent)
    }
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
