//
//  PlanView.swift
//  Duello
//
//  Écran « Plan » : planning journalier par blocs horaires (grille 00:00 → 00:00),
//  saisie de tâches en langage naturel, répartition automatique des tâches sur
//  les jours du programme, coche et report d'une tâche.
//
//  Sources Expo portées (lecture seule) :
//   • expo_ref/src/screens/EnhancedPlanScreen.tsx   — écran principal (677 lignes)
//   • expo_ref/src/components/TaskCaptureCard.tsx   — carte « AJOUT RAPIDE »
//   • expo_ref/src/utils/taskParser.ts              — analyseur local + urgence
//   • expo_ref/src/utils/date.ts                    — jours du programme, clés
//   • expo_ref/src/utils/ollamaClient.ts            — analyse IA locale + repli
//   • premium_extract/01_EnhancedPlanScreen.md      — spécification de portage
//
//  Limites assumées, documentées au fil du fichier :
//   • la dictée vocale de `TaskCaptureCard` (hook `useDictation` + garde premium)
//     n'est pas portée : saisie au clavier uniquement ;
//   • `UserProfile` Swift ne porte pas encore dîner / douche / coucher : les
//     valeurs par défaut de `expo_ref/src/data.ts` sont reprises (`PlanRoutine`) ;
//   • le repli IA locale (`ollamaClient`) est porté mais dormant : réglages
//     désactivés par défaut et URL `http://` sur le réseau local (ATS peut la
//     refuser) — l'analyseur local prend toujours le relais ;
//   • l'éditeur d'horaires de cours (`ScheduleEditor.tsx`) n'appartient à aucun
//     lot : la grille lit les créneaux persistés s'ils existent, sinon le rappel
//     « Ajoute tes horaires de cours… » s'affiche, comme dans la source ;
//   • le `console.log` de repli (EnhancedPlanScreen ligne 168) n'est pas porté :
//     aucun `print` dans ce fichier.
//
//  Extensions locales exigées par le contrat du lot, absentes de l'écran Expo :
//  coche d'une tâche (`isDone`), report d'un jour (`postponedDays`), liste des
//  tâches et repère hebdomadaire. S'y ajoutent, pour tenir l'écran sur iOS :
//  la section « Objectifs du jour » (pendant accessible de la grille), la touche
//  « Terminé » du clavier numérique (la source validait au `onBlur`), et les
//  mentions « Prévue … », « Sans échéance » et « reportée de n jour(s) » des
//  lignes de tâche.
//

import Foundation
import SwiftUI

// MARK: - Modèle

/// Priorité d'une tâche (`TaskPriority` de `expo_ref/src/types.ts`).
enum PlanPriority: String, Codable, CaseIterable {
    case haute
    case moyenne
    case basse

    /// `priorityLabels` (EnhancedPlanScreen.tsx, ligne 292).
    var label: String {
        switch self {
        case .haute: return "Haute"
        case .moyenne: return "Moyenne"
        case .basse: return "Basse"
        }
    }

    /// `taskUrgencyScore` (taskParser.ts, ligne 70) : le poids porte la priorité.
    var weight: Int {
        switch self {
        case .haute: return 300
        case .moyenne: return 200
        case .basse: return 100
        }
    }
}

/// Tâche saisie en langage naturel (`ParsedTask` de `expo_ref/src/types.ts`),
/// augmentée de l'état local de coche et de report.
struct PlanTask: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var subject: String
    var priority: PlanPriority
    var deadline: String?
    var estimatedDuration: Int?
    /// Coche locale : une tâche faite reste listée, mais sort de l'avancement.
    var isDone: Bool
    /// Report local, en jours : l'échéance est repoussée d'autant.
    var postponedDays: Int

    init(
        id: String,
        title: String,
        subject: String,
        priority: PlanPriority,
        deadline: String? = nil,
        estimatedDuration: Int? = nil,
        isDone: Bool = false,
        postponedDays: Int = 0
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.priority = priority
        self.deadline = deadline
        self.estimatedDuration = estimatedDuration
        self.isDone = isDone
        self.postponedDays = postponedDays
    }

    enum CodingKeys: String, CodingKey {
        case id, title, subject, priority, deadline, estimatedDuration, isDone, postponedDays
    }

    /// Décodage tolérant : une donnée partielle ou d'une version antérieure ne
    /// doit jamais faire échouer le chargement du programme.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        subject = (try? container.decode(String.self, forKey: .subject)) ?? "Général"
        priority = (try? container.decode(PlanPriority.self, forKey: .priority)) ?? .moyenne
        deadline = try? container.decodeIfPresent(String.self, forKey: .deadline)
        estimatedDuration = try? container.decodeIfPresent(Int.self, forKey: .estimatedDuration)
        isDone = (try? container.decode(Bool.self, forKey: .isDone)) ?? false
        postponedDays = (try? container.decode(Int.self, forKey: .postponedDays)) ?? 0
    }

    /// `starterTasks` (EnhancedPlanScreen.tsx, lignes 24-30) : les cinq tâches de
    /// démonstration qui peuplent l'écran au premier lancement.
    static let starters: [PlanTask] = [
        PlanTask(id: "maths-annales", title: "Annales — fonctions polynomiales", subject: "Mathématiques", priority: .haute, deadline: "Aujourd'hui", estimatedDuration: 80),
        PlanTask(id: "physics-colle", title: "Reprendre la dernière colle de mécanique", subject: "Physique", priority: .haute, deadline: "Demain", estimatedDuration: 60),
        PlanTask(id: "english-vocabulary", title: "Réviser vingt mots de vocabulaire", subject: "Anglais", priority: .moyenne, deadline: "Vendredi", estimatedDuration: 40),
        PlanTask(id: "philosophy-plan", title: "Construire un plan détaillé", subject: "Français-philo", priority: .moyenne, deadline: "Mercredi", estimatedDuration: 60),
        PlanTask(id: "weekly-review", title: "Faire le bilan des résultats et priorités", subject: "Général", priority: .basse, deadline: "Vendredi", estimatedDuration: 45),
    ]
}

/// Séance placée dans la grille (`PlanningSession` de `expo_ref/src/types.ts`).
/// `taskId` et `isDone` sont des ajouts locaux : ils relient le bloc à sa tâche
/// pour la coche et l'avancement du jour.
struct PlanSession: Identifiable {
    let id: String
    let taskId: String
    let dayOffset: Int
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    /// Matière (`title` de la source).
    let title: String
    /// Intitulé de la tâche (`subtitle` de la source).
    let subtitle: String
    let priority: PlanPriority?
    let deadline: String?
    /// Couleur du bloc, issue de `subjectVisuals` (teintes de `src/theme.ts`).
    let colorHex: Int
    let icon: String
    let isDone: Bool

    var color: Color { colorHex.color }
}

/// Un jour du programme (`ProgramDay`, dérivé de `getProgramDays` de date.ts).
struct PlanDay: Identifiable, Hashable {
    let dateKey: String
    let date: Date
    let dayOffset: Int
    /// Libellé court du jour (« lun », date.ts ligne 43).
    let dayLabel: String
    let dayNumber: Int
    /// Libellé long du jour (« 21 septembre », date.ts ligne 45).
    let fullLabel: String

    var id: String { dateKey }
}

/// Créneau de cours (`ClassSlot` de `expo_ref/src/components/ScheduleEditor.tsx`).
struct PlanScheduleSlot: Codable, Identifiable, Equatable {
    var id: String
    var day: String
    var startTime: String
    var endTime: String
    var subject: String
    var room: String?

    enum CodingKeys: String, CodingKey {
        case id, day, startTime, endTime, subject, room
    }

    init(id: String, day: String, startTime: String, endTime: String, subject: String, room: String? = nil) {
        self.id = id
        self.day = day
        self.startTime = startTime
        self.endTime = endTime
        self.subject = subject
        self.room = room
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        day = (try? container.decode(String.self, forKey: .day)) ?? "Lundi"
        startTime = (try? container.decode(String.self, forKey: .startTime)) ?? "08:00"
        endTime = (try? container.decode(String.self, forKey: .endTime)) ?? "10:00"
        subject = (try? container.decode(String.self, forKey: .subject)) ?? ""
        room = try? container.decodeIfPresent(String.self, forKey: .room)
    }
}

/// Rythme quotidien évité par la répartition (dîner, douche, nuit).
///
/// `UserProfile` (Models.swift) ne porte pas encore ces champs : les valeurs par
/// défaut sont celles de `expo_ref/src/data.ts` (19:30 / 30 min, 21:30 / 15 min,
/// coucher 23:00). Le jour où le profil les portera, ce type deviendra un
/// simple adaptateur — le reste du fichier n'aura pas à bouger.
struct PlanRoutine: Equatable {
    var dinnerTime: String = "19:30"
    var dinnerDurationMinutes: Int = 30
    var showerTime: String = "21:30"
    var showerDurationMinutes: Int = 15
    var bedtime: String = "23:00"
}

/// Réglages de l'IA locale (`OllamaSettings` de `ollamaClient.ts`).
struct PlanOllamaSettings: Codable, Equatable {
    var enabled: Bool = false
    var baseUrl: String = "http://192.168.1.10:11434"
    var model: String = "qwen2.5:3b"
}

/// Visuel d'une matière : teinte de bloc et icône.
struct PlanSubjectVisual: Equatable {
    let colorHex: Int
    let icon: String
}

/// `subjectVisuals` (EnhancedPlanScreen.tsx, lignes 32-42).
///
/// Dans `expo_ref/src/theme.ts`, `accent`, `accentLight` et `lavender` valent
/// respectivement l'encre, son gris clair et le gris de surface : l'écran reste
/// monochrome, la couleur d'un bloc ne distingue que les matières.
enum PlanSubjects {
    static let names: [String] = [
        "Mathématiques",
        "Physique",
        "Chimie",
        "Informatique",
        "Anglais",
        "Français-philo",
        "Histoire-géographie",
        "Biologie",
        "Général",
    ]

    /// Icônes SF Symbols les plus proches des `Ionicons` de la source : certains
    /// glyphes n'ont pas d'équivalent exact (« calculator-outline » → `function`,
    /// « language-outline » → `globe`), la teinte du bloc reste identique.
    static let general = PlanSubjectVisual(colorHex: Theme.primaryLightHex, icon: "briefcase")

    static let visuals: [String: PlanSubjectVisual] = [
        "Mathématiques": PlanSubjectVisual(colorHex: Theme.primaryLightHex, icon: "function"),
        "Physique": PlanSubjectVisual(colorHex: Theme.surfaceMutedHex, icon: "flask"),
        "Chimie": PlanSubjectVisual(colorHex: Theme.surfaceMutedHex, icon: "flask"),
        "Informatique": PlanSubjectVisual(colorHex: Theme.primaryLightHex, icon: "laptopcomputer"),
        "Anglais": PlanSubjectVisual(colorHex: Theme.surfaceMutedHex, icon: "globe"),
        "Français-philo": PlanSubjectVisual(colorHex: Theme.primaryLightHex, icon: "book"),
        "Histoire-géographie": PlanSubjectVisual(colorHex: Theme.surfaceMutedHex, icon: "book"),
        "Biologie": PlanSubjectVisual(colorHex: Theme.primaryLightHex, icon: "flask"),
        "Général": PlanSubjectVisual(colorHex: Theme.primaryLightHex, icon: "briefcase"),
    ]

    /// Repli `subjectVisuals[task.subject] ?? subjectVisuals.Général` (ligne 540).
    static func visual(for subject: String) -> PlanSubjectVisual {
        visuals[subject] ?? general
    }
}

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

// MARK: - Moteur de dates (`utils/date.ts`)

/// Portage des utilitaires de date utilisés par l'écran : jours du programme,
/// clé de date locale, formatage français et lecture de la saisie `JJ/MM/AAAA`.
enum PlanDateEngine {
    static let frenchLocale = Locale(identifier: "fr_FR")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = frenchLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = format
        return formatter
    }

    /// `longDateFormatter` (EnhancedPlanScreen ligne 18) : « 21 septembre 2026 ».
    private static let longFormatter = makeFormatter("d MMMM yyyy")
    /// `monthDayFormatter` (date.ts ligne 11) : « 21 septembre ».
    private static let monthDayFormatter = makeFormatter("d MMMM")
    /// `shortWeekdayFormatter` (date.ts ligne 7) : « lun. » → « lun ».
    private static let shortWeekdayFormatter = makeFormatter("EEE")
    /// `toLocalDateKey` (date.ts ligne 71) : AAAA-MM-JJ.
    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    /// `formatDateInput` (EnhancedPlanScreen lignes 467-471).
    private static let inputFormatter = makeFormatter("dd/MM/yyyy")

    static var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = frenchLocale
        calendar.timeZone = TimeZone.current
        return calendar
    }

    /// Toutes les dates de l'écran sont construites à **12:00**, comme la source :
    /// un passage d'heure d'été ne peut pas faire basculer une date de jour.
    static func noonDate(for date: Date) -> Date {
        let calendar = gregorian
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let noon = DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 12,
            minute: 0,
            second: 0
        )
        return calendar.date(from: noon) ?? date
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        let calendar = gregorian
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let shifted = DateComponents(
            year: components.year,
            month: components.month,
            day: (components.day ?? 1) + days,
            hour: 12,
            minute: 0,
            second: 0
        )
        return calendar.date(from: shifted) ?? date
    }

    /// `getProgramHorizonDate` (date.ts lignes 57-61) : 21 septembre, reporté à
    /// l'année suivante une fois la date passée.
    static func programHorizon(today: Date) -> Date {
        let calendar = gregorian
        let year = calendar.component(.year, from: today)
        let thisYear = DateComponents(year: year, month: 9, day: 21, hour: 12)
        let horizon = calendar.date(from: thisYear) ?? today
        guard today > horizon else { return horizon }
        let nextYear = DateComponents(year: year + 1, month: 9, day: 21, hour: 12)
        return calendar.date(from: nextYear) ?? horizon
    }

    /// `toLocalDateKey` (date.ts lignes 71-76).
    static func localDateKey(_ date: Date) -> String {
        keyFormatter.string(from: date)
    }

    /// `getDayName` (EnhancedPlanScreen lignes 605-608) : `getDay()` JS place
    /// dimanche à 0, d'où la chaîne vide en tête du tableau.
    static func dayName(offset: Int, today: Date) -> String {
        let names = ["", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
        let index = ((jsWeekday(today) + offset) % 7 + 7) % 7
        return names[index]
    }

    /// `isWeekend` (lignes 610-613).
    static func isWeekend(offset: Int, today: Date) -> Bool {
        let day = ((jsWeekday(today) + offset) % 7 + 7) % 7
        return day == 0 || day == 6
    }

    /// `new Date().getDay()` : dimanche = 0 … samedi = 6.
    static func jsWeekday(_ date: Date) -> Int {
        let weekday = gregorian.component(.weekday, from: date)
        return (weekday + 6) % 7
    }

    /// `getNextSevenDays` (date.ts lignes 35-50), jour par jour.
    static func day(for date: Date, offset: Int) -> PlanDay {
        let noon = noonDate(for: date)
        let short = shortWeekdayFormatter.string(from: noon).replacingOccurrences(of: ".", with: "")
        return PlanDay(
            dateKey: localDateKey(noon),
            date: noon,
            dayOffset: offset,
            dayLabel: String(short.prefix(3)),
            dayNumber: gregorian.component(.day, from: noon),
            fullLabel: PlanTaskAnalyzer.capitalize(monthDayFormatter.string(from: noon))
        )
    }

    /// Le jour 0 seul, sans construire tout l'horizon (premier rendu).
    static func firstDay(today: Date = Date()) -> PlanDay {
        day(for: today, offset: 0)
    }

    /// `getProgramDays` (date.ts lignes 63-69).
    static func programDays(today: Date = Date()) -> [PlanDay] {
        let start = noonDate(for: today)
        let horizon = programHorizon(today: start)
        let dayCount = max(1, Int((horizon.timeIntervalSince(start) / 86_400).rounded()) + 1)
        return (0..<dayCount).map { offset in
            day(for: addDays(offset, to: start), offset: offset)
        }
    }

    /// `longDateFormatter` : « 21 septembre 2026 » (affichage hors saisie).
    static func longDate(_ date: Date) -> String {
        longFormatter.string(from: date)
    }

    /// `formatDateInput` : « 21/09/2026 ».
    static func inputDate(_ date: Date) -> String {
        inputFormatter.string(from: date)
    }

    /// `maskDateInput` (lignes 474-478) : séparateurs insérés à la place de
    /// l'élève, 8 chiffres au plus.
    static func maskInput(_ value: String) -> String {
        let digits = String(value.filter { $0.isNumber }.prefix(8))
        var parts: [String] = []
        if digits.count > 0 { parts.append(String(digits.prefix(2))) }
        if digits.count > 2 { parts.append(String(digits.dropFirst(2).prefix(2))) }
        if digits.count > 4 { parts.append(String(digits.dropFirst(4).prefix(4))) }
        return parts.joined(separator: "/")
    }

    /// `parseDateInput` (lignes 481-496) : accepte JJ/MM, JJ/MM/AA et
    /// JJ/MM/AAAA ; l'année omise se déduit du programme en cours et bascule sur
    /// l'année suivante si la date est déjà passée.
    static func parseDate(_ value: String, reference: Date) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^(\\d{1,2})/(\\d{1,2})(?:/(\\d{2}|\\d{4}))?$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)) else {
            return nil
        }
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: trimmed) else { return nil }
            return String(trimmed[range])
        }
        guard let dayText = group(1), let monthText = group(2),
              let day = Int(dayText), let month = Int(monthText) else { return nil }

        let rawYear = group(3)
        let year: Int
        if let rawYear, let parsedYear = Int(rawYear) {
            year = parsedYear < 100 ? 2000 + parsedYear : parsedYear
        } else {
            year = gregorian.component(.year, from: reference)
        }

        let calendar = gregorian
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else { return nil }
        let check = calendar.dateComponents([.day, .month], from: date)
        guard check.day == day, check.month == month else { return nil }
        if rawYear == nil && date < reference {
            return calendar.date(from: DateComponents(year: year + 1, month: month, day: day, hour: 12)) ?? date
        }
        return date
    }

    /// `findDayForInput` (lignes 498-503).
    static func findDay(for value: String, in days: [PlanDay]) -> PlanDay? {
        guard let reference = days.first?.date else { return nil }
        guard let parsed = parseDate(value, reference: reference) else { return nil }
        let key = localDateKey(parsed)
        return days.first { $0.dateKey == key }
    }

    /// `timeToMinutes` (lignes 615-618).
    static func timeToMinutes(_ time: String) -> Int {
        let parts = time.split(separator: ":").map { Int($0) ?? 0 }
        let hours = parts.first ?? 0
        let minutes = parts.count > 1 ? parts[1] : 0
        return hours * 60 + minutes
    }

    /// `minutesToTime` (lignes 620-623), borné à 23:59.
    static func minutesToTime(_ minutes: Int) -> String {
        let safe = max(0, min(minutes, 23 * 60 + 59))
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }

    /// `formatDuration` (lignes 368-374) : « 1 h 05 », « 2 h », « 45 min ».
    static func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours) h \(String(format: "%02d", mins))" }
        if hours > 0 { return "\(hours) h" }
        return "\(mins) min"
    }
}

// MARK: - Répartition (`distributeTasks`, `nextAvailableMinute`)

/// Portage de `distributeTasks` (EnhancedPlanScreen lignes 505-559) et de
/// `nextAvailableMinute` (lignes 561-582) : chaque tâche est posée au plus tôt,
/// en évitant cours, séances déjà placées, dîner, douche et nuit.
enum PlanScheduler {
    static func distribute(
        tasks: [PlanTask],
        schedule: [PlanScheduleSlot],
        dayCount: Int,
        routine: PlanRoutine,
        today: Date = Date()
    ) -> [PlanSession] {
        guard dayCount > 0 else { return [] }

        // Curseurs initiaux : aujourd'hui 17:00, week-end 09:00, semaine 17:00.
        var cursors: [Int] = (0..<dayCount).map { day in
            if day == 0 { return 17 * 60 }
            return PlanDateEngine.isWeekend(offset: day, today: today) ? 9 * 60 : 17 * 60
        }

        var sessions: [PlanSession] = []

        for task in tasks {
            let latestDay = min(
                deadlineOffset(task.deadline, dayCount: dayCount, postponedDays: task.postponedDays, today: today),
                dayCount - 1
            )
            let duration = min(120, max(25, task.estimatedDuration ?? 45))

            var chosenDay = max(0, latestDay)
            var chosenStart = Int.max

            if latestDay >= 0 {
                for day in 0...latestDay {
                    let candidate = nextAvailableMinute(
                        start: cursors[day],
                        duration: duration,
                        dayOffset: day,
                        schedule: schedule,
                        sessions: sessions,
                        routine: routine,
                        today: today
                    )
                    if candidate < chosenStart {
                        chosenStart = candidate
                        chosenDay = day
                    }
                }
            }

            // Aucun créneau avant 21:00 : la tâche glisse au jour suivant, 09:00
            // le week-end et 17:00 en semaine.
            if chosenStart == Int.max || chosenStart + duration > 21 * 60 {
                chosenDay = min(latestDay + 1, dayCount - 1)
                chosenStart = nextAvailableMinute(
                    start: PlanDateEngine.isWeekend(offset: chosenDay, today: today) ? 9 * 60 : 17 * 60,
                    duration: duration,
                    dayOffset: chosenDay,
                    schedule: schedule,
                    sessions: sessions,
                    routine: routine,
                    today: today
                )
            }

            let visual = PlanSubjects.visual(for: task.subject)
            let end = chosenStart + duration
            sessions.append(
                PlanSession(
                    id: "scheduled-\(task.id)",
                    taskId: task.id,
                    dayOffset: chosenDay,
                    startTime: PlanDateEngine.minutesToTime(chosenStart),
                    endTime: PlanDateEngine.minutesToTime(end),
                    durationMinutes: duration,
                    title: task.subject,
                    subtitle: task.title,
                    priority: task.priority,
                    deadline: task.deadline,
                    colorHex: visual.colorHex,
                    icon: visual.icon,
                    isDone: task.isDone
                )
            )
            cursors[chosenDay] = end + PlanMetrics.blockGapMinutes
        }

        return sessions.sorted { left, right in
            left.dayOffset == right.dayOffset ? left.startTime < right.startTime : left.dayOffset < right.dayOffset
        }
    }

    /// `nextAvailableMinute` (lignes 561-582) : décale le candidat de 15 minutes
    /// après chaque chevauchement, dans l'ordre des blocages.
    static func nextAvailableMinute(
        start: Int,
        duration: Int,
        dayOffset: Int,
        schedule: [PlanScheduleSlot],
        sessions: [PlanSession],
        routine: PlanRoutine,
        today: Date
    ) -> Int {
        var candidate = start
        let dayName = PlanDateEngine.dayName(offset: dayOffset, today: today)

        var blocked: [(start: Int, end: Int)] = []
        blocked += schedule
            .filter { $0.day == dayName }
            .map { (PlanDateEngine.timeToMinutes($0.startTime), PlanDateEngine.timeToMinutes($0.endTime)) }
        blocked += sessions
            .filter { $0.dayOffset == dayOffset }
            .map { (PlanDateEngine.timeToMinutes($0.startTime), PlanDateEngine.timeToMinutes($0.endTime)) }
        blocked.append((PlanDateEngine.timeToMinutes(routine.dinnerTime), PlanDateEngine.timeToMinutes(routine.dinnerTime) + routine.dinnerDurationMinutes))
        blocked.append((PlanDateEngine.timeToMinutes(routine.showerTime), PlanDateEngine.timeToMinutes(routine.showerTime) + routine.showerDurationMinutes))
        blocked.append((PlanDateEngine.timeToMinutes(routine.bedtime), 24 * 60))

        for interval in blocked.sorted(by: { $0.start < $1.start }) where candidate < interval.end && candidate + duration > interval.start {
            candidate = interval.end + PlanMetrics.blockGapMinutes
        }
        return candidate
    }

    /// `deadlineOffset` (lignes 584-603), augmenté du report local
    /// (`postponedDays`), borné aux jours du programme.
    static func deadlineOffset(
        _ deadline: String?,
        dayCount: Int,
        postponedDays: Int = 0,
        today: Date = Date()
    ) -> Int {
        guard let deadline, !deadline.isEmpty else {
            return clamp(min(6, dayCount - 1) + postponedDays, dayCount: dayCount)
        }

        let normalized = PlanTaskAnalyzer.normalize(deadline)
        var base: Int

        if normalized.contains("aujourd'hui") || normalized.contains("ce soir") {
            base = 0
        } else if normalized.contains("apres-demain") {
            base = 2
        } else if normalized.contains("demain") {
            base = 1
        } else if let numeric = numericOffset(normalized, dayCount: dayCount, today: today) {
            base = numeric
        } else if let weekday = weekdayOffset(normalized, today: today) {
            base = weekday
        } else {
            base = min(6, dayCount - 1)
        }

        return clamp(base + postponedDays, dayCount: dayCount)
    }

    /// `/(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?/` (ligne 590).
    private static func numericOffset(_ normalized: String, dayCount: Int, today: Date) -> Int? {
        let pattern = "(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, options: [], range: NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)) else {
            return nil
        }
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: normalized) else { return nil }
            return String(normalized[range])
        }
        guard let dayText = group(1), let monthText = group(2),
              let day = Int(dayText), let month = Int(monthText) else { return nil }

        let calendar = PlanDateEngine.gregorian
        let noon = PlanDateEngine.noonDate(for: today)
        let suppliedYear = group(3).flatMap { Int($0) } ?? calendar.component(.year, from: noon)
        let fullYear = suppliedYear < 100 ? 2000 + suppliedYear : suppliedYear
        guard var target = calendar.date(from: DateComponents(year: fullYear, month: month, day: day, hour: 12)) else { return nil }
        if group(3) == nil && target < noon {
            target = calendar.date(from: DateComponents(year: fullYear + 1, month: month, day: day, hour: 12)) ?? target
        }
        let days = Int((target.timeIntervalSince(noon) / 86_400).rounded())
        return max(0, min(dayCount - 1, days))
    }

    /// `['dimanche', 'lundi', …].findIndex` (ligne 600) : prochain jour nommé.
    private static func weekdayOffset(_ normalized: String, today: Date) -> Int? {
        let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        guard let target = names.firstIndex(where: { normalized.contains($0) }) else { return nil }
        return (target - PlanDateEngine.jsWeekday(today) + 7) % 7
    }

    private static func clamp(_ value: Int, dayCount: Int) -> Int {
        max(0, min(dayCount - 1, value))
    }
}

// MARK: - Persistance locale

/// Équivalents iOS de `ACCOUNT_STORAGE_KEYS.programTasks`, `.classSchedule` et
/// `.ollamaSettings` (`prepapp-…` côté Expo). Les clés sont suffixées par
/// l'identifiant public du compte : deux élèves sur le même appareil ne
/// partagent pas leur programme.
enum PlanStorage {
    static func tasksKey(_ accountKey: String) -> String { "com.duello.ios.plan.tasks.\(accountKey)" }
    static func scheduleKey(_ accountKey: String) -> String { "com.duello.ios.plan.schedule.\(accountKey)" }
    static func ollamaKey(_ accountKey: String) -> String { "com.duello.ios.plan.ollama.\(accountKey)" }

    static func loadTasks(accountKey: String) -> [PlanTask]? {
        guard let data = UserDefaults.standard.data(forKey: tasksKey(accountKey)) else { return nil }
        return try? JSONDecoder().decode([PlanTask].self, from: data)
    }

    static func saveTasks(_ tasks: [PlanTask], accountKey: String) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: tasksKey(accountKey))
    }

    static func loadSchedule(accountKey: String) -> [PlanScheduleSlot]? {
        guard let data = UserDefaults.standard.data(forKey: scheduleKey(accountKey)) else { return nil }
        return try? JSONDecoder().decode([PlanScheduleSlot].self, from: data)
    }

    static func saveSchedule(_ slots: [PlanScheduleSlot], accountKey: String) {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        UserDefaults.standard.set(data, forKey: scheduleKey(accountKey))
    }

    static func loadOllamaSettings(accountKey: String) -> PlanOllamaSettings? {
        guard let data = UserDefaults.standard.data(forKey: ollamaKey(accountKey)) else { return nil }
        return try? JSONDecoder().decode(PlanOllamaSettings.self, from: data)
    }

    static func saveOllamaSettings(_ settings: PlanOllamaSettings, accountKey: String) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: ollamaKey(accountKey))
    }
}

// MARK: - Analyse IA locale (`ollamaClient.ts`)

/// Portage de `parseTaskDumpWithOllama` (ollamaClient.ts lignes 131-183).
///
/// L'appel vise le serveur Ollama **de l'élève** (réseau local), pas l'API
/// Duello : il n'entre donc pas dans `DuelloAPI.request`. Deux limites
/// assumées : l'URL est en `http://` (ATS peut la refuser) et les réglages sont
/// désactivés par défaut — l'analyseur local reste le chemin normal.
enum PlanOllamaClient {
    enum PlanOllamaError: Error {
        case badURL
        case status(Int)
        case malformedResponse
    }

    /// `SYSTEM_PROMPT` (lignes 33-44), verbatim.
    static let systemPrompt = """
    Tu es l'assistant de planification de Duello. Tu transformes la dictée en vrac d'un étudiant de classe préparatoire en une liste de tâches structurées, en JSON uniquement.

    Règles :
    - Une tâche par action distincte mentionnée dans le texte.
    - "subject" doit être choisi parmi exactement ces valeurs : Mathématiques, Physique, Chimie, Informatique, Anglais, Français-philo, Histoire-géographie, Biologie, Général. Utilise "Général" si aucune ne correspond clairement.
    - "priority" vaut "haute" si l'étudiant dit urgent / impératif / très important / absolument, "basse" si secondaire / pas urgent / si j'ai le temps, sinon "moyenne".
    - "deadline" est une échéance courte en français ("Aujourd'hui", "Demain", "Vendredi", "Avant le 12/05"...) ou null si rien n'est précisé.
    - "estimatedDuration" est une durée en minutes (entier). Si rien n'est précisé, estime une durée raisonnable pour la tâche (45 par défaut).
    - Convertis systématiquement toute expression mathématique dictée en notation symbolique correcte dans "title", avec ces équivalences et toute autre notation standard équivalente :
      "x carré" -> x², "x cube" -> x³, "puissance n" -> ^n, "racine de" / "racine carrée de" -> √(), "pi" -> π, "plus ou moins" -> ±, "infini" -> ∞, "intégrale de a à b" -> ∫[a,b], "somme" -> ∑, "appartient à" -> ∈, "inclus dans" -> ⊂, "inférieur ou égal" -> ≤, "supérieur ou égal" -> ≥, "différent de" -> ≠, "dérivée de f" -> f'(), "a sur b" (fraction) -> a/b, "fois" -> ×, "divisé par" -> ÷, "delta" -> Δ, "theta" -> θ, "lambda" -> λ.
      Exemple : "réviser x carré plus deux x moins trois égal zéro" devient le titre "Réviser x² + 2x − 3 = 0".
    - Garde les titres courts et lisibles, en français, sans texte ni commentaire en dehors du JSON demandé.
    """

    /// `TASK_RESPONSE_SCHEMA` (lignes 46-65), transmis tel quel à Ollama.
    private static let responseSchema = """
    {"type":"object","properties":{"tasks":{"type":"array","items":{"type":"object","properties":{"title":{"type":"string"},"subject":{"type":"string"},"priority":{"type":"string","enum":["haute","moyenne","basse"]},"deadline":{"type":["string","null"]},"estimatedDuration":{"type":"integer"}},"required":["title","subject","priority"]}}},"required":["tasks"]}
    """

    /// `trimBaseUrl` (lignes 112-114).
    private static func trimmed(_ baseUrl: String) -> String {
        var value = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    /// `clampDuration` (lignes 116-120) : 10 à 240 minutes, 45 par défaut.
    private static func clampDuration(_ value: Any?) -> Int {
        let parsed: Double
        if let number = value as? Double {
            parsed = number
        } else if let number = value as? Int {
            parsed = Double(number)
        } else if let text = value as? String, let number = Double(text) {
            parsed = number
        } else {
            return 45
        }
        guard parsed.isFinite else { return 45 }
        return min(240, max(10, Int(parsed.rounded())))
    }

    /// `normalizePriority` (lignes 122-124).
    private static func normalizePriority(_ value: Any?) -> PlanPriority {
        guard let text = value as? String else { return .moyenne }
        return PlanPriority(rawValue: text.lowercased()) ?? .moyenne
    }

    /// `normalizeSubject` (lignes 126-129).
    private static func normalizeSubject(_ value: Any?) -> String {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return "Général"
        }
        return PlanSubjects.names.first { $0.lowercased() == text.lowercased() } ?? "Général"
    }

    /// `parseTaskDumpWithOllama` : `POST <baseUrl>/api/chat`, réponse JSON
    /// stricte, une tâche vide est ignorée.
    static func parse(transcript: String, settings: PlanOllamaSettings) async throws -> [PlanTask] {
        let base = trimmed(settings.baseUrl)
        guard let url = URL(string: base + "/api/chat") else { throw PlanOllamaError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": settings.model,
            "stream": false,
            "options": ["temperature": 0.2],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript],
            ],
        ]
        if let schema = try? JSONSerialization.jsonObject(with: Data(responseSchema.utf8)) {
            body["format"] = schema
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlanOllamaError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw PlanOllamaError.status(http.statusCode) }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = root["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
              let rawTasks = parsed["tasks"] as? [[String: Any]] else {
            throw PlanOllamaError.malformedResponse
        }

        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        return rawTasks.enumerated().compactMap { index, raw in
            let title = (raw["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { return nil }
            let deadline = (raw["deadline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return PlanTask(
                id: "task-ollama-\(stamp)-\(index)",
                title: title,
                subject: normalizeSubject(raw["subject"]),
                priority: normalizePriority(raw["priority"]),
                deadline: (deadline?.isEmpty ?? true) ? nil : deadline,
                estimatedDuration: clampDuration(raw["estimatedDuration"])
            )
        }
    }
}

// MARK: - Mesures figées

/// Constantes de la grille et de l'écran, reprises de la source (lignes 360-366,
/// 386-432 et 95). Elles ne sont pas paramétrables : la journée entière doit
/// tenir dans la page, sans défilement interne.
enum PlanMetrics {
    /// `DAY_MINUTES` (ligne 360).
    static let dayMinutes = 24 * 60
    /// `HOURS` (ligne 362) : 25 graduations, la dernière fermant la journée.
    static let hours: [Int] = Array(0...24)
    /// `DAY_HEADER_HEIGHT` (ligne 364).
    static let dayHeaderHeight: CGFloat = 30
    /// `TIMELINE_BOTTOM_PADDING` (ligne 366).
    static let timelineBottomPadding: CGFloat = 10
    /// Plancher de hauteur de grille (ligne 386).
    static let minimumTimelineHeight: CGFloat = 240
    /// Hauteur du carrousel de jours. L'écran Expo mesurait la hauteur restante
    /// (`onLayout`) ; dans un `ScrollView` SwiftUI, une valeur fixe garde la
    /// grille lisible et le défilement vertical prévisible.
    static let dayAreaHeight: CGFloat = 560
    /// Effacement automatique du bandeau d'ajout (ligne 95).
    static let bannerDismissDelay: TimeInterval = 3.5
    /// Seuils de contenu des blocs (lignes 431-432).
    static let compactBlockThreshold: CGFloat = 42
    static let tinyBlockThreshold: CGFloat = 24
    /// Hauteur minimale d'un bloc (ligne 428).
    static let minimumBlockHeight: CGFloat = 14
    /// Décalage entre deux blocs d'un même jour (lignes 555 et 579).
    static let blockGapMinutes = 15
}

// MARK: - Écran

/// Planning journalier : carrousel de jours, grille horaire 00:00 → 00:00,
/// saisie de tâches en langage naturel, coche et report.
struct PlanView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var selectedDayOffset = 0
    @State private var days: [PlanDay] = [PlanDateEngine.firstDay()]
    @State private var tasks: [PlanTask] = PlanTask.starters
    @State private var schedule: [PlanScheduleSlot] = []
    @State private var hasLoaded = false
    @State private var lastAddedCount = 0
    @State private var isAnalyzing = false
    @State private var ollamaFallbackNotice = false
    @State private var ollamaSettings = PlanOllamaSettings()
    @State private var selectedSession: PlanSession?
    @State private var dateInput: String = PlanDateEngine.longDate(Date())
    @State private var dateError: String?
    @State private var isEditingDate = false
    @State private var composerText = ""
    @FocusState private var dateFieldFocused: Bool

    private let routine = PlanRoutine()

    // MARK: Clés et dérivés

    private var accountKey: String {
        let email = session.profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty ? "local" : DuelloAPI.publicProfileId(email: email)
    }

    private var selectedDay: PlanDay {
        day(for: selectedDayOffset)
    }

    private func day(for offset: Int) -> PlanDay {
        if let match = days.first(where: { $0.dayOffset == offset }) { return match }
        if let first = days.first { return first }
        return PlanDateEngine.firstDay()
    }

    private func sessions(for day: PlanDay) -> [PlanSession] {
        distributedSessions.filter { $0.dayOffset == day.dayOffset }
    }

    /// `distributeTasks` de la source, rejoué à chaque changement de tâche : la
    /// grille reste le reflet exact de la liste.
    private var distributedSessions: [PlanSession] {
        PlanScheduler.distribute(
            tasks: tasks,
            schedule: schedule,
            dayCount: max(1, days.count),
            routine: routine
        )
    }

    private var doneCount: Int { tasks.filter { $0.isDone }.count }

    private var plannedLabels: [String: String] {
        var labels: [String: String] = [:]
        for session in distributedSessions {
            let target = day(for: session.dayOffset)
            labels[session.taskId] = "\(PlanTaskAnalyzer.capitalize(target.dayLabel)) \(target.dayNumber) · \(session.startTime)"
        }
        return labels
    }

    // MARK: Corps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                banners
                dateJumpBar
                if schedule.isEmpty { scheduleHint }
                weekStrip
                dayPager
                PlanObjectivesCard(
                    day: selectedDay,
                    sessions: sessions(for: selectedDay),
                    onSelect: { selectedSession = $0 }
                )
                .padding(.horizontal, 20)
                PlanTaskComposerCard(text: $composerText, isAnalyzing: isAnalyzing) {
                    addTasks(from: composerText)
                }
                PlanTaskListCard(
                    tasks: tasks,
                    plannedLabels: plannedLabels,
                    doneCount: doneCount,
                    onToggle: { toggle($0) },
                    onReport: { report($0) }
                )
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            // Le clavier numérique n'a pas de touche de retour : ce bouton
            // déclenche la validation de la date (comportement `onBlur` de la
            // source), sinon la saisie resterait ouverte sans issue.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Terminé") { dateFieldFocused = false }
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
        }
        .onAppear {
            refreshProgramIfNeeded()
            loadProgramIfNeeded()
        }
        .onChange(of: selectedDayOffset) { offset in
            guard !isEditingDate else { return }
            dateError = nil
            dateInput = PlanDateEngine.longDate(day(for: offset).date)
        }
        .onChange(of: dateFieldFocused) { focused in
            if focused {
                startEditingDate()
            } else {
                submitDateInput()
            }
        }
        .onChange(of: dateInput) { value in
            handleDateInput(value)
        }
        .sheet(item: $selectedSession) { session in
            PlanSessionSheet(session: session)
        }
    }

    // MARK: Bandeaux (B1, B2, B3 de la source)

    @ViewBuilder
    private var banners: some View {
        if isAnalyzing {
            PlanBanner(
                tone: .info,
                icon: nil,
                text: "Qwen analyse tes tâches et tes formules…",
                showsSpinner: true
            )
        }
        if !isAnalyzing && ollamaFallbackNotice {
            PlanBanner(
                tone: .warning,
                icon: "exclamationmark.triangle",
                text: "Assistant IA local injoignable, tâches ajoutées avec l’analyseur standard."
            )
        }
        if !isAnalyzing && lastAddedCount > 0 {
            PlanBanner(
                tone: .success,
                icon: "checkmark.circle.fill",
                text: "\(lastAddedCount) \(lastAddedCount > 1 ? "tâches ajoutées et planifiées" : "tâche ajoutée et planifiée")."
            )
        }
    }

    // MARK: Bloc date

    private var dateJumpBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)

                TextField("JJ/MM/AAAA", text: $dateInput)
                    .keyboardType(.numberPad)
                    .submitLabel(.go)
                    .focused($dateFieldFocused)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Aller à une date")

                if selectedDayOffset != 0 {
                    Button {
                        goToToday()
                    } label: {
                        Text("Aujourd’hui")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Theme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Revenir à aujourd’hui")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )

            if let dateError {
                Text(dateError)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Rappel horaires (B5)

    private var scheduleHint: some View {
        HStack(spacing: 9) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Ajoute tes horaires de cours dans ton profil pour éviter automatiquement ces créneaux.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.horizontal, 20)
    }

    // MARK: Repère hebdomadaire

    /// La source balaye tout l'horizon du programme ; ici la semaine du jour
    /// sélectionné est rappelée en puces, pour se repérer sans balayer.
    private var weekStrip: some View {
        let weekStart = (selectedDayOffset / 7) * 7
        let week = days.filter { $0.dayOffset >= weekStart && $0.dayOffset < weekStart + 7 }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(week) { entry in
                    DuelloChip(
                        title: "\(PlanTaskAnalyzer.capitalize(entry.dayLabel)) \(entry.dayNumber)",
                        selected: entry.dayOffset == selectedDayOffset
                    ) {
                        goToDay(entry.dayOffset)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Carrousel de jours (B6)

    private var dayPager: some View {
        TabView(selection: $selectedDayOffset) {
            ForEach(days) { entry in
                PlanDayPage(
                    day: entry,
                    sessions: sessions(for: entry),
                    areaHeight: PlanMetrics.dayAreaHeight,
                    onSelect: { selectedSession = $0 }
                )
                .tag(entry.dayOffset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: PlanMetrics.dayAreaHeight)
    }

    // MARK: Chargement et écriture

    /// `hasLoaded` n'affiche aucun écran de chargement : il garde seulement
    /// l'écriture, pour ne pas écraser le programme avant de l'avoir lu
    /// (EnhancedPlanScreen lignes 66-91).
    private func loadProgramIfNeeded() {
        guard !hasLoaded else { return }
        let key = accountKey
        if let stored = PlanStorage.loadTasks(accountKey: key) { tasks = stored }
        if let stored = PlanStorage.loadSchedule(accountKey: key) { schedule = stored }
        if let stored = PlanStorage.loadOllamaSettings(accountKey: key) { ollamaSettings = stored }
        hasLoaded = true
    }

    private func refreshProgramIfNeeded() {
        let fresh = PlanDateEngine.programDays()
        if days.count != fresh.count || days.first?.dateKey != fresh.first?.dateKey {
            days = fresh
        }
        if selectedDayOffset >= days.count { selectedDayOffset = max(0, days.count - 1) }
    }

    private func persistTasks(_ value: [PlanTask]) {
        guard hasLoaded else { return }
        PlanStorage.saveTasks(value, accountKey: accountKey)
    }

    // MARK: Navigation interne

    /// `selectDay` (lignes 107-113) : le champ de date suit le jour affiché.
    private func goToDay(_ offset: Int) {
        selectedDayOffset = max(0, min(max(0, days.count - 1), offset))
    }

    private func goToToday() {
        dateInput = PlanDateEngine.longDate(day(for: 0).date)
        dateError = nil
        goToDay(0)
    }

    private func startEditingDate() {
        dateInput = PlanDateEngine.inputDate(selectedDay.date)
        isEditingDate = true
    }

    /// `handleDateInput` (lignes 120-128) : masque la saisie, et dès qu'une date
    /// du programme est reconnue, y conduit.
    private func handleDateInput(_ value: String) {
        guard isEditingDate else { return }
        let masked = PlanDateEngine.maskInput(value)
        if masked != value {
            dateInput = masked
            return
        }
        if let target = PlanDateEngine.findDay(for: masked, in: days) {
            dateError = nil
            goToDay(target.dayOffset)
        }
    }

    /// `submitDateInput` (lignes 136-150) : seule la validation explicite signale
    /// une saisie inutilisable.
    private func submitDateInput() {
        isEditingDate = false
        if let target = PlanDateEngine.findDay(for: dateInput, in: days) {
            dateError = nil
            dateInput = PlanDateEngine.longDate(target.date)
            goToDay(target.dayOffset)
            return
        }
        let reference = days.first?.date ?? Date()
        dateError = PlanDateEngine.parseDate(dateInput, reference: reference) == nil
            ? "Format attendu : JJ/MM/AAAA."
            : "Cette date est en dehors de ton programme."
        dateInput = PlanDateEngine.longDate(selectedDay.date)
    }

    // MARK: Ajout, coche, report

    /// `handleTranscript` (lignes 158-183) : analyse IA locale si elle est
    /// réglée, repli sur l'analyseur standard, tri par urgence décroissante.
    private func addTasks(from transcript: String) {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        composerText = ""
        ollamaFallbackNotice = false

        let useOllama = ollamaSettings.enabled
            && !ollamaSettings.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard useOllama else {
            append(PlanTaskAnalyzer.parse(transcript: clean))
            return
        }

        isAnalyzing = true
        let settings = ollamaSettings
        Task {
            do {
                let parsed = try await PlanOllamaClient.parse(transcript: clean, settings: settings)
                DispatchQueue.main.async {
                    isAnalyzing = false
                    append(parsed)
                }
            } catch {
                let fallback = PlanTaskAnalyzer.parse(transcript: clean)
                DispatchQueue.main.async {
                    isAnalyzing = false
                    ollamaFallbackNotice = true
                    append(fallback)
                }
            }
        }
    }

    private func append(_ added: [PlanTask]) {
        guard !added.isEmpty else { return }
        var next = tasks + added
        next.sort { PlanTaskAnalyzer.urgencyScore($0) > PlanTaskAnalyzer.urgencyScore($1) }
        tasks = next
        persistTasks(next)

        lastAddedCount = added.count
        let count = added.count
        // Le bandeau d'ajout s'efface tout seul après 3 500 ms (ligne 95).
        DispatchQueue.main.asyncAfter(deadline: .now() + PlanMetrics.bannerDismissDelay) {
            if lastAddedCount == count { lastAddedCount = 0 }
        }
    }

    private func updateTasks(_ transform: (inout [PlanTask]) -> Void) {
        var next = tasks
        transform(&next)
        tasks = next
        persistTasks(next)
    }

    /// Coche locale : la tâche faite sort de l'avancement et s'affiche en grisé.
    private func toggle(_ task: PlanTask) {
        updateTasks { items in
            guard let index = items.firstIndex(where: { $0.id == task.id }) else { return }
            items[index].isDone.toggle()
        }
    }

    /// Report local d'un jour : l'échéance glisse, la tâche redevient à faire.
    private func report(_ task: PlanTask) {
        updateTasks { items in
            guard let index = items.firstIndex(where: { $0.id == task.id }) else { return }
            items[index].postponedDays += 1
            items[index].isDone = false
        }
    }
}

// MARK: - Bandeau

/// Bandeau de retour, motif `successBanner` / `scheduleHint` de la source
/// (fond `primaryLight` dans les deux cas, `accentLight` valant ce même gris).
struct PlanBanner: View {
    enum Tone {
        case info
        case warning
        case success
    }

    let tone: Tone
    let icon: String?
    let text: String
    var showsSpinner: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if showsSpinner {
                ProgressView()
                    .scaleEffect(0.8)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(tone == .warning ? Theme.inkSoft : Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.horizontal, 20)
    }
}

// MARK: - Grille horaire

/// Graduation d'heure : étiquette à gauche, trait à partir de 38 pt, renforcé
/// toutes les 6 heures (lignes 405-410).
struct PlanHourTick: View {
    let hour: Int
    let strong: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text(String(format: "%02d:00", hour % 24))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 36, alignment: .leading)
            Rectangle()
                .fill(strong ? Theme.inkFaint : Theme.border)
                .frame(height: strong ? 1 : 0.5)
        }
        .frame(height: 1)
    }
}

/// Bloc d'une séance : accent d'encre à gauche, contenu qui se réduit quand le
/// bloc devient court (`compact < 42`, `tiny < 24`, lignes 426-461).
struct PlanTimelineBlock: View {
    let session: PlanSession
    let pxPerMinute: CGFloat
    let onSelect: (PlanSession) -> Void

    var body: some View {
        let top = CGFloat(PlanDateEngine.timeToMinutes(session.startTime)) * pxPerMinute
        let blockHeight = max(CGFloat(session.durationMinutes) * pxPerMinute - 2, PlanMetrics.minimumBlockHeight)
        let compact = blockHeight < PlanMetrics.compactBlockThreshold
        let tiny = blockHeight < PlanMetrics.tinyBlockThreshold

        Button {
            onSelect(session)
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(compact ? "\(session.startTime) · \(session.title)" : session.title)
                        .font(.system(size: tiny ? 9 : 12, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if !compact {
                        Text(session.subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                        Text("\(session.startTime)–\(session.endTime) · \(PlanDateEngine.formatDuration(session.durationMinutes))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.inkFaint)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, tiny ? 0 : 4)
                .padding(.horizontal, tiny ? 6 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                if session.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.trailing, 6)
                }
            }
            .frame(height: blockHeight)
            .background(session.color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .clipped()
            .opacity(session.isDone ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .padding(.leading, 42)
        .offset(y: top)
        .accessibilityLabel("\(session.startTime) \(session.title) — \(session.subtitle), \(PlanDateEngine.formatDuration(session.durationMinutes))")
    }
}

/// Une page-jour : bandeau de date + grille 00:00 → 00:00 (lignes 378-465).
struct PlanDayPage: View {
    let day: PlanDay
    let sessions: [PlanSession]
    let areaHeight: CGFloat
    let onSelect: (PlanSession) -> Void

    private var isToday: Bool { day.dayOffset == 0 }

    var body: some View {
        let timelineHeight = max(
            areaHeight - PlanMetrics.dayHeaderHeight - PlanMetrics.timelineBottomPadding,
            PlanMetrics.minimumTimelineHeight
        )
        let pxPerMinute = timelineHeight / CGFloat(PlanMetrics.dayMinutes)
        let plannedMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let nowMinutes = isToday ? PlanDayPage.minutesNow() : nil

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(isToday ? "Aujourd'hui" : "\(PlanTaskAnalyzer.capitalize(day.dayLabel)) \(day.fullLabel)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(sessions.isEmpty
                     ? "Rien de prévu"
                     : "\(sessions.count) \(sessions.count > 1 ? "blocs" : "bloc") · \(PlanDateEngine.formatDuration(plannedMinutes))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(height: PlanMetrics.dayHeaderHeight)

            ZStack(alignment: .topLeading) {
                ForEach(PlanMetrics.hours, id: \.self) { hour in
                    PlanHourTick(hour: hour, strong: hour % 6 == 0)
                        .offset(y: CGFloat(hour) * 60 * pxPerMinute)
                }

                // Ligne « maintenant », aujourd'hui seulement (ligne 412).
                if let nowMinutes {
                    HStack(spacing: 0) {
                        Circle()
                            .fill(Theme.ink)
                            .frame(width: 7, height: 7)
                            .offset(x: -3)
                        Rectangle()
                            .fill(Theme.ink)
                            .frame(height: 1.5)
                    }
                    .padding(.leading, 36)
                    .offset(y: CGFloat(nowMinutes) * pxPerMinute)
                }

                if sessions.isEmpty {
                    HStack(spacing: 7) {
                        Image(systemName: "leaf")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                        Text("Journée libre")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.leading, 42)
                }

                ForEach(sessions) { session in
                    PlanTimelineBlock(session: session, pxPerMinute: pxPerMinute, onSelect: onSelect)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: timelineHeight, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// `now.getHours() * 60 + now.getMinutes()` (ligne 389).
    private static func minutesNow() -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

// MARK: - Détail d'une séance

/// `SessionDetailModal` (lignes 294-358) : feuille du bas, fermable au geste,
/// par le bouton « Fermer » ou en touchant l'arrière-plan.
struct PlanSessionSheet: View {
    let session: PlanSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(session.color)
                        .frame(width: 44, height: 44)
                    Image(systemName: session.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("\(session.startTime) – \(session.endTime) · \(PlanDateEngine.formatDuration(session.durationMinutes))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 8)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer")
            }
            .padding(.bottom, 18)

            Text("À faire pendant la séance")
                .font(.system(size: 9, weight: .black))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(Theme.inkFaint)

            Text(session.subtitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 6)

            PlanFlowLayout(spacing: 8, lineSpacing: 8) {
                if let priority = session.priority {
                    PlanMetaChip(icon: "flag", text: "Priorité \(priority.label)")
                }
                if let deadline = session.deadline, !deadline.isEmpty {
                    PlanMetaChip(icon: "alarm", text: "Pour \(deadline)")
                }
                PlanMetaChip(
                    icon: "hourglass",
                    text: "\(PlanDateEngine.formatDuration(session.durationMinutes)) de travail"
                )
            }
            .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Theme.surface)
    }
}

/// Pastille d'information du détail (`modalMetaChip`, lignes 334-351).
struct PlanMetaChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Theme.inkSoft)
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Disposition en lignes successives, comme le `flexWrap` des pastilles de la
/// source (`Layout` est disponible depuis iOS 16, cible de ce portage).
struct PlanFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        let width = maxWidth.isFinite ? maxWidth : max(0, x - spacing)
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Objectifs du jour

/// Récapitulatif du jour affiché : blocs, temps prévu, avancement, puis la
/// liste des séances. La grille seule ne se lit pas au lecteur d'écran : cette
/// liste est le pendant accessible de `renderDayPage`.
struct PlanObjectivesCard: View {
    let day: PlanDay
    let sessions: [PlanSession]
    let onSelect: (PlanSession) -> Void

    private var plannedMinutes: Int { sessions.reduce(0) { $0 + $1.durationMinutes } }
    private var doneCount: Int { sessions.filter { $0.isDone }.count }

    var body: some View {
        let fraction: Double? = sessions.isEmpty ? nil : Double(doneCount) / Double(sessions.count)

        VStack(alignment: .leading, spacing: 12) {
            DuelloSectionHeader(
                title: "Objectifs du jour",
                subtitle: day.dayOffset == 0
                    ? "Aujourd'hui"
                    : "\(PlanTaskAnalyzer.capitalize(day.dayLabel)) \(day.fullLabel)"
            )

            HStack(spacing: 10) {
                DuelloStatTile(label: "Blocs", value: "\(sessions.count)")
                DuelloStatTile(label: "Temps prévu", value: PlanDateEngine.formatDuration(plannedMinutes))
                DuelloStatTile(
                    label: "Faites",
                    value: "\(doneCount)/\(sessions.count)",
                    fraction: fraction
                )
            }

            if sessions.isEmpty {
                DuelloEmptyState(
                    icon: "calendar",
                    title: "Rien de prévu",
                    message: "Ajoute une tâche : elle sera placée sur un créneau libre de la journée."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        Button {
                            onSelect(session)
                        } label: {
                            DuelloListRow(
                                title: session.title,
                                subtitle: "\(session.startTime)–\(session.endTime) · \(session.subtitle)",
                                icon: session.icon,
                                trailing: PlanDateEngine.formatDuration(session.durationMinutes),
                                showsChevron: true
                            )
                            .opacity(session.isDone ? 0.5 : 1)
                        }
                        .buttonStyle(.plain)
                        if session.id != sessions.last?.id {
                            Divider().background(Theme.border)
                        }
                    }
                }
            }
        }
        .duelloCard()
    }
}

// MARK: - Saisie des tâches

/// `TaskCaptureCard` (TaskCaptureCard.tsx) : mêmes libellés, saisie au clavier.
/// La dictée vocale et la garde premium du composant d'origine ne sont pas
/// portées par ce lot.
struct PlanTaskComposerCard: View {
    @Binding var text: String
    let isAnalyzing: Bool
    let onValidate: () -> Void

    private var canValidate: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Theme.primaryLight)
                        .frame(width: 38, height: 38)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AJOUT RAPIDE")
                        .font(.system(size: 8, weight: .black))
                        .kerning(1.1)
                        .foregroundStyle(Theme.ink)
                    Text("Dis tout ce que tu as à faire")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 0)
            }

            Text("Une phrase par tâche, même en vrac. Pour bien la placer, indique si possible :")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 15)

            PlanFlowLayout(spacing: 7, lineSpacing: 7) {
                PlanRequirementChip(icon: "flag", label: "Priorité")
                PlanRequirementChip(icon: "calendar", label: "Échéance")
                PlanRequirementChip(icon: "book", label: "Matière")
                PlanRequirementChip(icon: "timer", label: "Durée", optional: true)
            }
            .padding(.top, 11)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Ex. Demain, finir le DM de maths — urgent, environ 1 h. Puis apprendre le vocabulaire d’anglais pour vendredi, 30 min.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .accessibilityLabel("Tâches à ajouter")
            }
            .padding(13)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1.5)
            )
            .padding(.top, 15)

            Button(action: onValidate) {
                HStack(spacing: 8) {
                    Text("Organiser dans mon programme")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(!canValidate)
            .opacity(canValidate ? 1 : 0.35)
            .padding(.top, 14)
        }
        .duelloCard()
    }
}

/// `Requirement` (TaskCaptureCard.tsx lignes 169-185).
struct PlanRequirementChip: View {
    let icon: String
    let label: String
    var optional: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.ink)
            if optional {
                Text("optionnel")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(Theme.primaryLight)
        .clipShape(Capsule())
    }
}

// MARK: - Liste des tâches

/// Une tâche : coche, contenu, report d'un jour.
struct PlanTaskRow: View {
    let task: PlanTask
    let plannedLabel: String?
    let onToggle: () -> Void
    let onReport: () -> Void

    private var deadlineText: String {
        var parts: [String] = [task.subject]
        if let deadline = task.deadline, !deadline.isEmpty {
            parts.append("Pour \(deadline)")
        } else {
            parts.append("Sans échéance")
        }
        if task.postponedDays > 0 {
            parts.append(task.postponedDays > 1 ? "reportée de \(task.postponedDays) jours" : "reportée d'un jour")
        }
        return parts.joined(separator: " · ")
    }

    private var durationText: String {
        PlanDateEngine.formatDuration(task.estimatedDuration ?? 45)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(task.isDone ? Theme.progress : Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone ? "Marquer comme à faire" : "Marquer comme faite")

                DuelloListRow(
                    title: task.title,
                    subtitle: deadlineText,
                    icon: PlanSubjects.visual(for: task.subject).icon,
                    trailing: durationText,
                    showsChevron: false
                )

                if task.isDone {
                    DuelloPill(text: "Fait", tone: .success, icon: "checkmark")
                } else {
                    Button(action: onReport) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(6)
                            .background(Theme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reporter d'un jour")
                }
            }

            if let plannedLabel {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Prévue \(plannedLabel)")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.inkFaint)
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 4)
        .opacity(task.isDone ? 0.75 : 1)
    }
}

/// Liste des tâches, triée par urgence comme à l'ajout (ligne 180).
struct PlanTaskListCard: View {
    let tasks: [PlanTask]
    let plannedLabels: [String: String]
    let doneCount: Int
    let onToggle: (PlanTask) -> Void
    let onReport: (PlanTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DuelloSectionHeader(
                title: "Tâches",
                subtitle: "\(tasks.count) tâche(s) · \(doneCount) faite(s)"
            )

            if tasks.isEmpty {
                DuelloEmptyState(
                    icon: "checklist",
                    title: "Aucune tâche",
                    message: "Écris tes tâches en vrac : elles sont réparties automatiquement sur les jours du programme."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        PlanTaskRow(
                            task: task,
                            plannedLabel: plannedLabels[task.id],
                            onToggle: { onToggle(task) },
                            onReport: { onReport(task) }
                        )
                        if task.id != tasks.last?.id {
                            Divider().background(Theme.border)
                        }
                    }
                }
            }
        }
        .duelloCard()
    }
}
