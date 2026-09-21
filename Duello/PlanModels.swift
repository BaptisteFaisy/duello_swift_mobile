//
//  PlanModels.swift
//  Duello
//
//  Écran « Plan » — modèles : priorité, tâche, séance, jour, créneau de cours, rythme quotidien, réglages IA, visuels de matière.
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
