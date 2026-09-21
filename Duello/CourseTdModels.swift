import Foundation

/// Types du panneau « Mon TD » d'un chapitre : feuille importée, analyse IA,
/// indexation concours.
///
/// Porté de `src/utils/courseTd.ts` et `src/utils/courseDocument.ts` de
/// l'application Expo. Tous les types portent le préfixe `Ctd` (cours et TD) :
/// aucun n'existe ailleurs dans le projet Swift. Les nombres restent des
/// `Double`, comme côté JavaScript — les horodatages sont des millisecondes
/// (`Date.now()`).

// MARK: - Format de document

/// Format accepté pour un document de cours ou de TD
/// (`CourseDocumentMimeType`).
enum CtdMimeType: String, Codable, CaseIterable {
    case pdf = "application/pdf"
    case jpeg = "image/jpeg"
    case png = "image/png"

    /// Extension du fichier copié dans le dossier local, alignée sur le
    /// nommage d'Expo (le JPEG s'écrit `.jpg`).
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .jpeg: return "jpg"
        case .png: return "png"
        }
    }

    /// Vrai pour une photo de feuille (JPEG ou PNG).
    var isImage: Bool { self != .pdf }

    /// `courseDocumentMimeType` : type déduit du type déclaré par le
    /// sélecteur, sinon de l'extension du nom de fichier.
    init?(declared: String?, fileName: String = "") {
        if let declared, let known = CtdMimeType.allCases.first(where: { $0.rawValue == declared }) {
            self = known
            return
        }
        let name = fileName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.hasSuffix(".pdf") {
            self = .pdf
        } else if name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") {
            self = .jpeg
        } else if name.hasSuffix(".png") {
            self = .png
        } else {
            return nil
        }
    }
}

// MARK: - Document de cours du chapitre

/// Document de cours importé pour un chapitre (`StoredCourseDocument`).
///
/// `CourseTdView` le reçoit de l'écran du chapitre : c'est la référence que
/// l'IA utilise pour identifier les théorèmes et les hypothèses du TD.
struct CtdStoredCourseDocument: Codable, Equatable, Identifiable {
    /// Position du cours atteinte en classe, entre le début (0) et la fin (1).
    struct ClassProgress: Codable, Equatable {
        var position: Double
        var updatedAt: Double
    }

    var uri: String
    var name: String
    var mimeType: CtdMimeType
    var size: Double?
    var uploadedAt: Double
    var classProgress: ClassProgress?

    /// Un document est identifié par son emplacement et sa date d'import :
    /// le remplacer change `uploadedAt` et périme les analyses qui s'y
    /// rapportent.
    var id: String { "\(uri)#\(uploadedAt)" }
}

// MARK: - Feuille de TD

/// Feuille de TD importée par l'élève (`CourseTdSource`).
struct CtdSource: Codable, Equatable {
    var uri: String
    var name: String
    var mimeType: CtdMimeType
    var size: Double?
    var importedAt: Double
}

/// Question d'un exercice, indexée par l'IA (`CourseTdQuestion`).
struct CtdQuestion: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var text: String
    /// Difficulté de 1 à 5 (`difficulty`), bornée à la lecture.
    var difficulty: Int
    /// Théorèmes du cours convoqués par la question.
    var theorems: [String]
    /// Hypothèses à repérer dans l'énoncé.
    var hypotheses: [String]
}

/// Exercice découpé dans la feuille de TD (`CourseTdExercise`).
struct CtdExercise: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var statement: String
    var questions: [CtdQuestion]
}

/// Rapprochement entre le chapitre identifié par l'IA et le chapitre ouvert
/// (`CourseTdChapterMatch`).
enum CtdChapterMatch: String, Codable, CaseIterable {
    case exact
    case related
    case uncertain

    /// `CHAPTER_MATCH_LABEL` de `CourseTdPanel.tsx`, mot pour mot.
    var label: String {
        switch self {
        case .exact: return "Chapitre confirmé"
        case .related: return "Chapitre associé"
        case .uncertain: return "Chapitre à vérifier"
        }
    }
}

/// Résultat d'analyse d'une feuille de TD (`CourseTdAnalysis`).
struct CtdAnalysis: Codable, Equatable {
    /// Date de l'analyse, en millisecondes.
    var analyzedAt: Double
    /// `uploadedAt` du cours utilisé : une différence rend l'analyse périmée.
    var courseUploadedAt: Double
    var identifiedChapter: String
    var chapterMatch: CtdChapterMatch
    var exercises: [CtdExercise]
}

/// Contenu persisté du panneau (`CourseTdDocument`).
struct CtdDocument: Codable, Equatable {
    var version: Int
    var source: CtdSource?
    var analysis: CtdAnalysis?

    /// `EMPTY_COURSE_TD`.
    static let empty = CtdDocument(version: 1, source: nil, analysis: nil)

    /// `courseTdQuestionCount` : total des questions indexées.
    var questionCount: Int {
        (analysis?.exercises ?? []).reduce(0) { $0 + $1.questions.count }
    }

    /// `staleAnalysis` : l'analyse porte sur une version antérieure du cours.
    func isStale(comparedTo courseDocument: CtdStoredCourseDocument?) -> Bool {
        guard let analysis, let courseDocument else { return false }
        return analysis.courseUploadedAt != courseDocument.uploadedAt
    }
}

// MARK: - Lecture et écriture

/// `parseCourseTd` et `serializeCourseTd` : la feuille vit dans les
/// préférences locales, sérialisée en JSON.
enum CtdDocumentCodec {
    /// Relit la feuille d'un chapitre. Toute donnée illisible ou incomplète
    /// retombe sur le document vide, comme côté Expo.
    static func parse(_ raw: String?) -> CtdDocument {
        guard let raw,
              let data = raw.data(using: .utf8),
              let document = try? JSONDecoder().decode(CtdDocument.self, from: data),
              document.version == 1,
              document.source != nil
        else { return .empty }
        return document
    }

    /// Écrit la feuille d'un chapitre ; `nil` si l'encodage échoue.
    static func encode(_ document: CtdDocument) -> String? {
        guard let data = try? JSONEncoder().encode(document) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Mesures et emplacements

/// `formatCourseFileSize` : taille de fichier telle que l'affiche le panneau.
enum CtdFormatters {
    static func fileSize(_ size: Double?) -> String {
        guard let size else { return "Taille inconnue" }
        if size < 1024 * 1024 {
            return "\(max(1, Int((size / 1024).rounded()))) Ko"
        }
        return String(format: "%.1f Mo", size / (1024 * 1024))
    }
}

/// Emplacements locaux de la feuille de TD.
enum CtdStorage {
    /// `courseTdStorageKey(chapterId)` de `src/storage/keys.ts` : la clé
    /// logique est conservée à l'identique dans les préférences.
    static func documentKey(chapterId: String) -> String {
        "prepapp-course-td:v1:\(chapterId)"
    }

    /// Dossier des feuilles importées (`new Directory(Paths.document,
    /// 'duello-td')`). Créé au premier import.
    static func importsDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("duello-td", isDirectory: true)
    }
}
