//
//  ReportModels.swift
//  Duello
//
//  Lot « Report » — modèles des signalements et de la sécurité du profil :
//  raisons d'un signalement d'utilisateur, cible d'un signalement de contenu
//  scolaire, état de sécurité (comptes bloqués), profil public publié et
//  résultat de publication.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/UserReportModal.tsx      (REPORT_REASONS, UserReportReason)
//    - src/components/ExerciseReportButton.tsx (TARGET_LABELS,
//                                               TARGET_LABELS_WITH_ARTICLE)
//    - src/utils/socialApi.ts                  (UserReportReason,
//                                               ExerciseReportTarget,
//                                               ExerciseReportSource,
//                                               ExerciseReportSubmission,
//                                               BlockedSocialProfile,
//                                               UserSafetyState,
//                                               DirectoryPublication)
//    - src/utils/socialProfileSanitize.ts      (FALLBACK_PUBLIC_PERFORMANCE)
//    - src/utils/socialVisibility.ts           (VisibleProfile, resolveViewedProfile)
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

// MARK: - Signalement d'un utilisateur

/// Raison d'un signalement (`UserReportReason` de `utils/socialApi.ts`), avec
/// le libellé et l'icône du menu (`REPORT_REASONS` de `UserReportModal.tsx`).
enum ReportReason: String, CaseIterable, Identifiable {
    case harassment
    case spam
    case impersonation
    case inappropriateContent = "inappropriate-content"
    case other

    var id: String { rawValue }

    /// Libellé du choix, mot pour mot de la source Expo.
    var label: String {
        switch self {
        case .harassment: return "Harcèlement ou menace"
        case .spam: return "Spam ou faux compte"
        case .impersonation: return "Usurpation d’identité"
        case .inappropriateContent: return "Contenu inapproprié"
        case .other: return "Autre raison"
        }
    }

    /// Icône SF Symbol équivalente au glyphe Ionicons de la source.
    var icon: String {
        switch self {
        case .harassment: return "exclamationmark.triangle"
        case .spam: return "megaphone"
        case .impersonation: return "person.2"
        case .inappropriateContent: return "eye.slash"
        case .other: return "ellipsis"
        }
    }
}

// MARK: - Signalement d'un contenu scolaire

/// Cible d'un signalement de contenu (`ExerciseReportTarget`). `Encodable` pour
/// être transmise telle quelle dans le corps du signalement (valeur brute).
enum ReportExerciseTarget: String, CaseIterable, Identifiable, Encodable {
    case statement
    case correction

    var id: String { rawValue }

    /// Libellé court (`TARGET_LABELS`), employé dans les étiquettes d'action.
    var label: String {
        switch self {
        case .statement: return "énoncé"
        case .correction: return "corrigé"
        }
    }

    /// Libellé avec article (`TARGET_LABELS_WITH_ARTICLE`).
    var labelWithArticle: String {
        switch self {
        case .statement: return "l’énoncé"
        case .correction: return "le corrigé"
        }
    }

    /// En-tête de la carte de contexte, mot pour mot.
    var contextType: String {
        switch self {
        case .statement: return "ÉNONCÉ À VÉRIFIER"
        case .correction: return "CORRIGÉ À VÉRIFIER"
        }
    }
}

/// Origine d'un signalement de contenu (`ExerciseReportSource`).
enum ReportExerciseSource: String, CaseIterable, Encodable {
    case training
    case challenge
}

/// Corps d'un signalement de contenu (`ExerciseReportSubmission`).
struct ReportExerciseSubmission: Encodable {
    var target: ReportExerciseTarget
    var source: ReportExerciseSource
    var exerciseId: String
    var exerciseTitle: String
    var subject: String
    var message: String
}

// MARK: - Sécurité du profil

/// Profil bloqué renvoyé par le serveur (`BlockedSocialProfile`).
struct ReportBlockedProfile: Identifiable, Decodable, Equatable {
    var id: String
    var displayName: String
    var photoUri: String?
    var blockedAt: String

    enum CodingKeys: String, CodingKey { case id, displayName, photoUri, blockedAt }

    init(id: String, displayName: String, photoUri: String? = nil, blockedAt: String = "") {
        self.id = id
        self.displayName = displayName
        self.photoUri = photoUri
        self.blockedAt = blockedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        photoUri = try? c.decodeIfPresent(String.self, forKey: .photoUri)
        blockedAt = (try? c.decode(String.self, forKey: .blockedAt)) ?? ""
    }
}

/// Liste privée des comptes bloqués (`UserSafetyState`).
struct ReportSafetyState: Decodable {
    var blockedProfiles: [ReportBlockedProfile]

    enum CodingKeys: String, CodingKey { case blockedProfiles }

    init(blockedProfiles: [ReportBlockedProfile] = []) {
        self.blockedProfiles = blockedProfiles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blockedProfiles = (try? c.decode([ReportBlockedProfile].self, forKey: .blockedProfiles)) ?? []
    }
}

// MARK: - Profil public

/// Statistiques publiques (`PublicPerformance`), avec repli sûr.
struct ReportPublicPerformance: Codable, Equatable {
    var average: String
    var trend: String
    var gradeCount: Int
    var completion: Double
    var streak: Int
    var xp: Double

    enum CodingKeys: String, CodingKey { case average, trend, gradeCount, completion, streak, xp }

    /// Repli employé partout où un profil serveur n'apporte rien
    /// (`FALLBACK_PUBLIC_PERFORMANCE` de `socialProfileSanitize.ts`).
    static let fallback = ReportPublicPerformance(
        average: "—", trend: "—", gradeCount: 0, completion: 0, streak: 0, xp: 0
    )

    init(average: String, trend: String, gradeCount: Int, completion: Double, streak: Int, xp: Double) {
        self.average = average
        self.trend = trend
        self.gradeCount = gradeCount
        self.completion = completion
        self.streak = streak
        self.xp = xp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        average = (try? c.decode(String.self, forKey: .average)) ?? "—"
        trend = (try? c.decode(String.self, forKey: .trend)) ?? "—"
        gradeCount = (try? c.decode(Int.self, forKey: .gradeCount)) ?? 0
        completion = (try? c.decode(Double.self, forKey: .completion)) ?? 0
        streak = (try? c.decode(Int.self, forKey: .streak)) ?? 0
        xp = (try? c.decode(Double.self, forKey: .xp)) ?? 0
    }
}

/// Profil public d'un membre (`SocialProfile`), réduit aux champs que les
/// surfaces de signalement et de visibilité exploitent.
///
/// Distinct de `SocSocialProfile` (lot « Social ») : celui-ci porte aussi
/// `performance`, nécessaire au repli de `sanitize`, et les champs d'identité
/// rendus en tête de fiche (`resolveViewedProfile`).
struct ReportSocialProfile: Identifiable, Decodable, Equatable {
    var id: String
    var displayName: String
    var photoUri: String?
    var prepName: String
    var track: String
    var year: String
    var targetSchool: String
    var specialty: String
    var personalGoal: String
    var isPublic: Bool
    var isPremium: Bool
    var performance: ReportPublicPerformance?

    enum CodingKeys: String, CodingKey {
        case id, displayName, photoUri, prepName, track, year, targetSchool
        case isPublic, isPremium, performance, details
    }

    enum DetailsKeys: String, CodingKey { case specialty, personalGoal }

    init(
        id: String,
        displayName: String,
        photoUri: String? = nil,
        prepName: String = "",
        track: String = "",
        year: String = "",
        targetSchool: String = "",
        specialty: String = "",
        personalGoal: String = "",
        isPublic: Bool = true,
        isPremium: Bool = false,
        performance: ReportPublicPerformance? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.photoUri = photoUri
        self.prepName = prepName
        self.track = track
        self.year = year
        self.targetSchool = targetSchool
        self.specialty = specialty
        self.personalGoal = personalGoal
        self.isPublic = isPublic
        self.isPremium = isPremium
        self.performance = performance
    }

    /// Décodage tolérant, comme `Models.swift` : le serveur omet parfois un
    /// champ, et une ancienne version ne publie ni détails ni statistiques.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        photoUri = try? c.decodeIfPresent(String.self, forKey: .photoUri)
        prepName = (try? c.decode(String.self, forKey: .prepName)) ?? ""
        track = (try? c.decode(String.self, forKey: .track)) ?? ""
        year = (try? c.decode(String.self, forKey: .year)) ?? ""
        targetSchool = (try? c.decode(String.self, forKey: .targetSchool)) ?? ""
        isPublic = (try? c.decode(Bool.self, forKey: .isPublic)) ?? false
        isPremium = (try? c.decode(Bool.self, forKey: .isPremium)) ?? false
        performance = try? c.decodeIfPresent(ReportPublicPerformance.self, forKey: .performance)
        if let details = try? c.nestedContainer(keyedBy: DetailsKeys.self, forKey: .details) {
            specialty = (try? details.decodeIfPresent(String.self, forKey: .specialty)) ?? ""
            personalGoal = (try? details.decodeIfPresent(String.self, forKey: .personalGoal)) ?? ""
        } else {
            specialty = ""
            personalGoal = ""
        }
    }
}

/// Identité rendue en tête de profil (`resolveViewedProfile`).
struct ReportViewedIdentity: Equatable {
    var name: String
    var photoUri: String?
    var prepName: String
    var track: String
    var year: String
    var targetSchool: String
    var specialty: String
    var personalGoal: String
}

// MARK: - Publication

/// Résultat d'une publication d'annuaire (`DirectoryPublication`).
enum ReportDirectoryPublication {
    case published(at: Date, profile: ReportSocialProfile?)
    case incomplete
    case rejected(message: String, authenticationRequired: Bool)
    case unreachable(message: String)
}
