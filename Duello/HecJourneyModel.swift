import Foundation

/// Modèle du parcours HEC : types de blocs, blocs de scène, entrées persistées
/// et constantes de la frise.
///
/// Porté de :
/// - `src/utils/hecJourneyTimeline.ts` — `HEC_JOURNEY_BLOCK_TYPES`,
///   `HEC_JOURNEY_ASSESSMENT_TYPES`, `HEC_JOURNEY_BLOCK_LABELS`,
///   `HecJourneyBlockType`, `HecJourneyEntry`, `HecJourneyTimelineState`,
///   `HEC_JOURNEY_NEUTRAL_BLOCK_COUNT`, `HEC_JOURNEY_NEUTRAL_SEED_VERSION`,
///   `HEC_JOURNEY_SECOND_YEAR_FINAL_POSITION`,
///   `HEC_JOURNEY_SECOND_YEAR_MAXIMUM_BLOCK_GAP`, `MINIMUM_BLOCK_GAP`,
///   `HEC_JOURNEY_SCHOOL_HOLIDAYS`, `HecJourneySchoolZone`,
///   `isHecJourneyAssessmentType` ;
/// - `src/components/HecJourneyScene.tsx` — `HecJourneySceneBlock` (bloc de
///   scène : statut de cours, blason d'admission) ;
/// - `src/components/HecJourney.tsx` — `HecJourneyChapter`,
///   `ADDABLE_BLOCK_TYPES`, `BLOCK_TYPE_ICONS`, `journeyBlockTypeLabel`,
///   `SUMMER_BREAK_BLOCK_ID`, `ADMISSION_BLOCK_ID` ;
/// - `src/data/tracks.ts` — `toProgramYear` (via `HecJourneyProfile`).
///
/// Le statut de cours d'un chapitre réutilise `TrainCourseStatus`
/// (`TrainCourseStatus.swift`, avec le magasin `TrainCourseStatusStore`) :
/// mêmes valeurs `not-started` / `in-progress` / `completed` que la source
/// Expo, pour ne pas dupliquer le magasin de statuts déjà partagé avec le
/// catalogue d'entraînement.

// MARK: - Types de blocs

/// `HecJourneyBlockType` : jalons principaux, repères d'évaluation et
/// emplacements neutres.
enum HecJourneyBlockType: String, CaseIterable, Hashable, Encodable {
    case chapter
    case holiday
    case mockExam = "mock-exam"
    case writtenExams = "written-exams"
    case oralExams = "oral-exams"
    case colle
    case ds
    case interrogation
    case neutral
}

/// Tables et règles attachées aux types de blocs.
///
/// `HEC_JOURNEY_BLOCK_TYPES` — les jalons posés sur la piste : chapitre,
/// vacances, CB, épreuves écrites, épreuves orales — est porté par les cas de
/// `HecJourneyBlockType` eux-mêmes : seuls les repères latéraux
/// (`HEC_JOURNEY_ASSESSMENT_TYPES`) et l'ordre de la grille d'ajout
/// (`ADDABLE_BLOCK_TYPES`) demandent une table.
enum HecJourneyBlocks {
    /// `HEC_JOURNEY_ASSESSMENT_TYPES` : les repères latéraux.
    static let assessments: [HecJourneyBlockType] = [.colle, .ds, .interrogation]

    /// `ADDABLE_BLOCK_TYPES` : ordre de la grille « NOUVEAU BLOC ».
    static let addable: [HecJourneyBlockType] = [
        .chapter, .mockExam, .interrogation, .writtenExams, .colle, .oralExams,
        .ds, .holiday,
    ]

    /// `HEC_JOURNEY_BLOCK_LABELS`, mot pour mot.
    static func label(_ type: HecJourneyBlockType) -> String {
        switch type {
        case .chapter: return "Chapitre"
        case .holiday: return "Vacances"
        case .mockExam: return "CB"
        case .writtenExams: return "Épreuves écrites"
        case .oralExams: return "Épreuves orales"
        case .colle: return "Colle"
        case .ds: return "DS"
        case .interrogation: return "Interrogation"
        case .neutral: return "Bloc neutre"
        }
    }

    /// `BLOCK_TYPE_ICONS`, transposées en SF Symbols (la source utilise
    /// Ionicons).
    static func icon(_ type: HecJourneyBlockType) -> String {
        switch type {
        case .chapter: return "book"
        case .holiday: return "sun.max"
        case .mockExam: return "graduationcap"
        case .writtenExams: return "doc.text"
        case .oralExams: return "mic"
        case .colle: return "person.2"
        case .ds: return "square.and.pencil"
        case .interrogation: return "questionmark.circle"
        case .neutral: return "plus"
        }
    }

    /// Libellé de la grille d'ajout : « DS » et « CB » gardent leurs
    /// capitales, les autres passent en bas de casse (`toLocaleLowerCase`).
    static func optionLabel(_ type: HecJourneyBlockType) -> String {
        switch type {
        case .ds, .mockExam: return label(type)
        default: return label(type).lowercased()
        }
    }

    static func isAssessment(_ type: HecJourneyBlockType) -> Bool {
        assessments.contains(type)
    }
}

// MARK: - Blocs de scène

/// Type d'un bloc affiché sur la frise : un jalon, un repère, ou les deux
/// bornes fixes du parcours.
enum HecJourneySceneBlockType: Hashable {
    case registration
    case admission
    case block(HecJourneyBlockType)

    /// `journeyBlockTypeLabel`.
    var label: String {
        switch self {
        case .registration: return "Inscription"
        case .admission: return "Admission"
        case .block(let type): return HecJourneyBlocks.label(type)
        }
    }

    var isAssessment: Bool {
        if case .block(let type) = self { return HecJourneyBlocks.isAssessment(type) }
        return false
    }

    var blockType: HecJourneyBlockType? {
        if case .block(let type) = self { return type }
        return nil
    }
}

/// `HecJourneySceneBlock` : ce que la frise dessine pour chaque bloc.
struct HecJourneySceneBlock: Identifiable, Hashable {
    let id: String
    let type: HecJourneySceneBlockType
    let title: String
    let createdAt: Date
    var courseStatus: TrainCourseStatus = .notStarted
    var chapterId: String?
    /// Blason de la dernière étape (admission), tel que `crestLabel`,
    /// `crestColor` et `crestSchoolId` côté Expo.
    var crestLabel: String?
    var crestColorHex: Int?
    var crestSchoolId: String?

    init(
        id: String,
        type: HecJourneySceneBlockType,
        title: String,
        createdAt: Date,
        courseStatus: TrainCourseStatus = .notStarted,
        chapterId: String? = nil,
        crestLabel: String? = nil,
        crestColorHex: Int? = nil,
        crestSchoolId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.createdAt = createdAt
        self.courseStatus = courseStatus
        self.chapterId = chapterId
        self.crestLabel = crestLabel
        self.crestColorHex = crestColorHex
        self.crestSchoolId = crestSchoolId
    }
}

// MARK: - Entrées persistées

/// `HecJourneyEntry` : un emplacement daté de la frise.
///
/// L'encodage reprend exactement la forme de `serializeHecJourneyTimeline` :
/// `createdAt` est un nombre de millisecondes depuis l'époque Unix, pour rester
/// lisible par l'app Expo si les deux cohabitent sur un même appareil.
struct HecJourneyEntry: Identifiable, Hashable, Encodable {
    let id: String
    let type: HecJourneyBlockType
    let title: String
    let createdAt: Date
    let chapterId: String?

    init(
        id: String,
        type: HecJourneyBlockType,
        title: String,
        createdAt: Date,
        chapterId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.createdAt = createdAt
        self.chapterId = chapterId
    }

    enum CodingKeys: String, CodingKey {
        case id, type, title, createdAt, chapterId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt.timeIntervalSince1970 * 1000, forKey: .createdAt)
        try container.encodeIfPresent(chapterId, forKey: .chapterId)
    }
}

/// `HecJourneyTimelineState` : l'enveloppe écrite dans le stockage local.
struct HecJourneyTimelineState: Encodable {
    var schemaVersion: Int = 1
    var entries: [HecJourneyEntry] = []
    var neutralBlocksSeeded: Bool = true
    var neutralBlocksSeedVersion: Int = HecJourneyTimelineConstants.neutralSeedVersion

    init(
        schemaVersion: Int = 1,
        entries: [HecJourneyEntry] = [],
        neutralBlocksSeeded: Bool = true,
        neutralBlocksSeedVersion: Int = HecJourneyTimelineConstants.neutralSeedVersion
    ) {
        self.schemaVersion = schemaVersion
        self.entries = entries
        self.neutralBlocksSeeded = neutralBlocksSeeded
        self.neutralBlocksSeedVersion = neutralBlocksSeedVersion
    }
}

// MARK: - Chapitres et vacances

/// `HecJourneyChapter` : chapitre proposé à l'ajout sur la frise.
struct HecJourneyChapter: Identifiable, Hashable {
    let id: String
    let name: String
}

/// `HEC_JOURNEY_SCHOOL_HOLIDAYS`.
enum HecJourneySchoolHoliday: String, CaseIterable, Hashable {
    case toussaint = "Toussaint"
    case noel = "Noël"
    case hiver = "Hiver"
    case printemps = "Printemps"
    case ete = "Été"
    case toutes = "Toutes"

    /// `SCHOOL_HOLIDAY_TITLES` et `SCHOOL_HOLIDAY_OPTION_LABELS` (identiques).
    var label: String {
        switch self {
        case .toussaint: return "Vacances de la Toussaint"
        case .noel: return "Vacances de Noël"
        case .hiver: return "Vacances d’hiver"
        case .printemps: return "Vacances de printemps"
        case .ete: return "Vacances d’été"
        case .toutes: return "Toutes"
        }
    }

    /// Les cinq vacances individuelles, sans l'entrée « Toutes ».
    static let individual: [HecJourneySchoolHoliday] = allCases.filter { $0 != .toutes }
}

/// `HecJourneySchoolZone`.
enum HecJourneySchoolZone: String, CaseIterable, Hashable {
    case a = "A"
    case b = "B"
    case c = "C"
}

// MARK: - Constantes de la frise

/// Constantes de disposition et de versionnage de la frise
/// (`src/utils/hecJourneyTimeline.ts`).
enum HecJourneyTimelineConstants {
    /// `MINIMUM_BLOCK_GAP` : deux blocs posés le même jour restent espacés.
    static let minimumBlockGap: Double = 0.62
    /// `HEC_JOURNEY_NEUTRAL_BLOCK_COUNT`.
    static let neutralBlockCount = 32
    /// `HEC_JOURNEY_NEUTRAL_SEED_VERSION`.
    static let neutralSeedVersion = 4
    /// `HEC_JOURNEY_NEUTRAL_V1_COUNT` / `HEC_JOURNEY_NEUTRAL_V2_COUNT`.
    static let neutralV1Count = 8
    static let neutralV2Count = 32
    /// `HEC_JOURNEY_SECOND_YEAR_FINAL_POSITION` : le blason occupe le cran
    /// suivant les 32 emplacements de 2e année.
    static let secondYearFinalPosition: Double = Double(neutralBlockCount + 1)
    /// `HEC_JOURNEY_SECOND_YEAR_MAXIMUM_BLOCK_GAP`.
    static let secondYearMaximumBlockGap: Double = 1
    static let summerBreakBlockId = "summer-break-between-years"
    static let admissionBlockId = "journey-final-admission"
    static let registrationBlockId = "registration"
}

// MARK: - Intégration au profil

/// Chapitres et année du parcours, dérivés du profil de l'élève.
///
/// La source Expo reçoit ces valeurs du parent (`chapters`, `programYear`,
/// `admissionTrack`) ; ici elles sont déduites du profil, comme le fait
/// `MainTabView` pour les autres écrans.
enum HecJourneyProfile {
    /// `toProgramYear` de `data/tracks.ts` : seule « 1re année » vaut 1.
    static func programYear(from year: String) -> Int {
        year == "1re année" ? 1 : 2
    }

    /// Libellé d'année attendu par `DuelloProgram.subjects`.
    static func yearLabel(_ year: Int) -> String {
        year == 1 ? "1re année" : "2e année"
    }

    /// Chapitres de mathématiques du parcours : l'écran Expo reçoit les
    /// chapitres de la matière Maths (le bouton d'en-tête ouvre « le classement
    /// XP de mathématiques »).
    static func mathsChapters(profile: UserProfile, year: Int) -> [HecJourneyChapter] {
        let subjects = DuelloProgram.subjects(
            track: profile.track,
            specialty: profile.specialty,
            year: yearLabel(year)
        )
        guard let maths = subjects.first(where: { $0.id == "maths" }) else { return [] }
        return maths.chapters.map { HecJourneyChapter(id: $0.id, name: $0.name) }
    }
}
