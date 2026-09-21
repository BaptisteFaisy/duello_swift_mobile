//
//  CollCompletionModels.swift
//  Duello
//
//  Modèles et codec de la « colle » d'un chapitre : énoncé PDF importé, position
//  atteinte pendant la colle et questions restantes corrigées par l'IA.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/colleCompletion.ts
//        `ColleCompletion`, `ColleStatementDocument`, `ColleRemainingQuestion`,
//        `emptyColleCompletion`, `parseColleCompletion`,
//        `serializeColleCompletion`, `normalizedPosition`.
//    - src/utils/gradingScore.ts
//        `VERDICT_SCORE_COEFFICIENT` (coefficient par verdict).
//
//  Cible : iOS 16, aucune API iOS 17. Aucune dépendance externe.
//  Les horodatages sont des millisecondes (`Date.now()`), comme côté Expo.
//
import Foundation

/// Verdict d'une réponse corrigée (`MathAnswerGrade['verdict']`).
enum CollVerdict: String, Codable, CaseIterable {
    case perfect
    case correct
    case partial
    case incorrect

    /// `VERDICT_LABELS` de `ColleCompletionPanel.tsx`, mot pour mot.
    var label: String {
        switch self {
        case .perfect: return "Réponse parfaite"
        case .correct: return "Réponse correcte"
        case .partial: return "Réponse partielle"
        case .incorrect: return "Réponse incorrecte"
        }
    }

    /// `VERDICT_SCORE_COEFFICIENT` de `utils/gradingScore.ts` : parfait 1,
    /// correct 0,8, partiel 0,4, incorrect 0.
    var scoreCoefficient: Double {
        switch self {
        case .perfect: return 1
        case .correct: return 0.8
        case .partial: return 0.4
        case .incorrect: return 0
        }
    }
}

/// Correction d'une question (`MathAnswerGrade & { reviewedAt }`).
struct CollMathGrade: Codable, Equatable {
    var verdict: CollVerdict
    var feedback: String
    var correction: String
    /// Instant de la correction, en millisecondes (`Date.now()`).
    var reviewedAt: Double
}

/// Énoncé PDF importé (`ColleStatementDocument`).
struct CollStatementDocument: Codable, Equatable {
    var uri: String
    var name: String
    /// Toujours `application/pdf` : seul format accepté pour l'énoncé.
    var mimeType: String
    var size: Double?
    var importedAt: Double
    /// Position relative jusqu'à laquelle l'élève a réussi pendant la colle.
    var reachedPosition: Double?
}

/// Question restante d'une colle (`ColleRemainingQuestion`).
struct CollRemainingQuestion: Codable, Equatable, Identifiable {
    var id: String
    var prompt: String
    var answer: String
    /// Barème facultatif ; une question sans barème vaut un point.
    var points: Double?
    var grade: CollMathGrade?
}

/// Contenu persisté d'une colle (`ColleCompletion`).
struct CollCompletionDocument: Codable, Equatable {
    var version: Int
    var statement: CollStatementDocument?
    var questions: [CollRemainingQuestion]
    var updatedAt: Double
}

/// `emptyColleCompletion`, `parseColleCompletion` et `serializeColleCompletion`.
enum CollCompletion {
    /// MIME unique accepté pour l'énoncé (`'application/pdf'`).
    static let pdfMimeType = "application/pdf"

    /// `Date.now()` en millisecondes.
    static func now() -> Double { Date().timeIntervalSince1970 * 1000 }

    /// `emptyColleCompletion()`.
    static func empty(now: Double = CollCompletion.now()) -> CollCompletionDocument {
        CollCompletionDocument(version: 1, statement: nil, questions: [], updatedAt: now)
    }

    /// `normalizedPosition` : position bornée `[0, 1]`, ou `nil` si absente.
    static func normalizedPosition(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(1, max(0, value))
    }

    /// `serializeColleCompletion` : encodage JSON, `nil` si l'encodage échoue.
    static func serialize(_ value: CollCompletionDocument) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `parseColleCompletion` : validation tolérante. Toute donnée illisible ou
    /// incomplète retombe sur la colle vide, comme côté Expo ; les questions
    /// invalides sont écartées une à une.
    static func parse(_ raw: String?) -> CollCompletionDocument {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let value = object as? [String: Any]
        else { return empty() }
        return CollCompletionDocument(
            version: 1,
            statement: statement(from: value["statement"]),
            questions: questions(from: value["questions"]),
            updatedAt: (value["updatedAt"] as? Double) ?? now()
        )
    }

    // MARK: - Lecture des champs

    /// Énoncé valide : URI, nom, MIME PDF et date d'import présents.
    private static func statement(from raw: Any?) -> CollStatementDocument? {
        guard let document = raw as? [String: Any],
              let uri = document["uri"] as? String, !uri.isEmpty,
              let name = document["name"] as? String,
              document["mimeType"] as? String == pdfMimeType,
              let importedAt = document["importedAt"] as? Double
        else { return nil }
        let size = (document["size"] as? Double).flatMap { $0 >= 0 ? $0 : nil }
        return CollStatementDocument(
            uri: uri,
            name: name,
            mimeType: pdfMimeType,
            size: size,
            importedAt: importedAt,
            reachedPosition: normalizedPosition(document["reachedPosition"] as? Double)
        )
    }

    /// Questions valides, dans l'ordre reçu (`flatMap` de la source).
    private static func questions(from raw: Any?) -> [CollRemainingQuestion] {
        guard let list = raw as? [Any] else { return [] }
        return list.compactMap { candidate in
            guard let question = candidate as? [String: Any],
                  let id = question["id"] as? String,
                  let prompt = question["prompt"] as? String,
                  let answer = question["answer"] as? String
            else { return nil }
            let points = (question["points"] as? Double)
                .flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            return CollRemainingQuestion(
                id: id,
                prompt: prompt,
                answer: answer,
                points: points,
                grade: grade(from: question["grade"])
            )
        }
    }

    /// Correction valide (`validGrade` de la source).
    private static func grade(from raw: Any?) -> CollMathGrade? {
        guard let grade = raw as? [String: Any],
              let verdict = CollVerdict(rawValue: grade["verdict"] as? String ?? ""),
              let feedback = grade["feedback"] as? String,
              let correction = grade["correction"] as? String,
              let reviewedAt = grade["reviewedAt"] as? Double
        else { return nil }
        return CollMathGrade(
            verdict: verdict,
            feedback: feedback,
            correction: correction,
            reviewedAt: reviewedAt
        )
    }
}

/// Emplacements locaux de la colle d'un chapitre.
enum CollStorage {
    /// `colleCompletionStorageKey(chapterId)` de `src/storage/keys.ts` : la clé
    /// logique (`prepapp-colle-completion:v1:`) est conservée à l'identique dans
    /// les préférences, comme `CtdStorage`.
    static func completionKey(chapterId: String) -> String {
        "prepapp-colle-completion:v1:\(chapterId)"
    }

    /// Dossier des énoncés importés (`new Directory(Paths.document,
    /// 'duello-colles')`). Créé au premier import.
    static func importsDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("duello-colles", isDirectory: true)
    }
}
