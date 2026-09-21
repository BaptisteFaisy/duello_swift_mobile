//
//  PlanTaskAnalyzer.swift
//  Duello
//
//  Écran « Plan » — analyseur local des tâches dictées en vrac (portage de taskParser.ts).
//
import Foundation

// MARK: - Analyseur local (`taskParser.ts`)

/// Portage de `expo_ref/src/utils/taskParser.ts` : découpe une dictée en vrac en
/// tâches, devine matière, priorité, échéance et durée, puis note l'urgence.
enum PlanTaskAnalyzer {
    /// `normalize` (ligne 14) : minuscules, sans accents. L'apostrophe
    /// typographique est ramenée à l'apostrophe droite pour que les motifs de la
    /// source (« aujourd'hui », « si j'ai le temps ») s'appliquent aussi aux
    /// textes saisis sur iOS.
    static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// `SUBJECT_ALIASES` (lignes 3-12).
    private static let subjectAliases: [(subject: String, aliases: [String])] = [
        ("Mathématiques", ["math", "maths", "mathematique", "algèbre", "algebre", "analyse"]),
        ("Physique", ["physique", "mécanique", "mecanique", "électricité", "electricite"]),
        ("Chimie", ["chimie", "thermochimie"]),
        ("Informatique", ["informatique", "info", "python", "sql"]),
        ("Anglais", ["anglais", "english", "vocabulaire"]),
        ("Français-philo", ["français", "francais", "philo", "philosophie", "dissertation"]),
        ("Histoire-géographie", ["histoire", "géographie", "geographie", "géopo", "geopo"]),
        ("Biologie", ["biologie", "bio", "svt"]),
    ]

    /// `inferSubject` (lignes 18-25) : première matière dont un alias apparaît.
    static func subject(for text: String) -> String {
        let normalized = normalize(text)
        for entry in subjectAliases where entry.aliases.contains(where: { normalized.contains(normalize($0)) }) {
            return entry.subject
        }
        return "Général"
    }

    /// `inferPriority` (lignes 27-32).
    static func priority(for text: String) -> PlanPriority {
        let normalized = normalize(text)
        if matches("urgent|priorite haute|tres important|imperatif|absolument", in: normalized) { return .haute }
        if matches("pas urgent|priorite basse|si j'ai le temps|secondaire", in: normalized) { return .basse }
        return .moyenne
    }

    /// `inferDeadline` (lignes 34-41) : l'expression est rendue capitalisée.
    static func deadline(for text: String) -> String? {
        let pattern = "(aujourd'hui|demain|apres-demain|ce soir|lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|cette semaine|ce week-end|week-end|avant (?:le )?\\d{1,2}(?:/\\d{1,2})?)"
        guard let captured = firstCapture(pattern, in: normalize(text)) else { return nil }
        return capitalize(captured)
    }

    /// `inferDuration` (lignes 43-49) : heures → minutes, sinon minutes, sinon 45.
    static func duration(for text: String) -> Int {
        let normalized = normalize(text)
        if let hours = firstCapture("(\\d+(?:[.,]\\d+)?)\\s*(?:h|heure)", in: normalized) {
            let value = Double(hours.replacingOccurrences(of: ",", with: ".")) ?? 0
            return Int((value * 60).rounded())
        }
        if let minutes = firstCapture("(\\d+)\\s*(?:min|minute)", in: normalized) {
            return Int(minutes) ?? 45
        }
        return 45
    }

    /// `parseTaskDump` (lignes 51-67).
    static func parse(transcript: String) -> [PlanTask] {
        let flattened = transcript
            .replacingOccurrences(
                of: "\\s+(?:et ensuite|ensuite|puis|et aussi|aussi)\\s+",
                with: ". ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: ",\\s+(?=(?:faire|finir|réviser|reviser|lire|apprendre|préparer|preparer|reprendre|travailler)\\b)",
                with: ". ",
                options: [.regularExpression, .caseInsensitive]
            )

        let chunks = flattened
            .components(separatedBy: CharacterSet(charactersIn: "\n.;"))
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n,\u{2013}-")) }
            .filter { $0.count >= 4 }

        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        return chunks.enumerated().map { index, chunk in
            PlanTask(
                id: "task-\(stamp)-\(index)",
                title: capitalize(chunk),
                subject: subject(for: chunk),
                priority: priority(for: chunk),
                deadline: deadline(for: chunk),
                estimatedDuration: duration(for: chunk)
            )
        }
    }

    /// `taskUrgencyScore` (lignes 69-82) : priorité + urgence de l'échéance.
    static func urgencyScore(_ task: PlanTask) -> Int {
        let normalized = normalize(task.deadline ?? "")
        let deadlineScore: Int
        if normalized.contains("aujourd'hui") || normalized.contains("ce soir") {
            deadlineScore = 60
        } else if normalized.contains("demain") {
            deadlineScore = 50
        } else if matches("lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche", in: normalized) {
            deadlineScore = 30
        } else if !normalized.isEmpty {
            deadlineScore = 15
        } else {
            deadlineScore = 0
        }
        return task.priority.weight + deadlineScore
    }

    /// `capitalize` de `utils/date.ts` (ligne 16).
    static func capitalize(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).uppercased() + value.dropFirst()
    }

    // MARK: Outils de motif

    private static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let captured = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captured])
    }
}
