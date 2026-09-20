import Foundation
import SwiftUI

/// Écran « Plan » : planning journalier par blocs horaires (grille 00:00 → 00:00),
/// saisie de tâches en langage naturel et affectation automatique des tâches sur les
/// jours du programme.
///
/// Portage fidèle de `src/screens/EnhancedPlanScreen.tsx` (677 lignes) vers SwiftUI
/// natif iOS 16, d'après `premium_extract/01_EnhancedPlanScreen.md` et les
/// conventions de `PORTING.md`.
///
/// Correspondances avec la source :
/// - `profile: UserProfile` (unique prop) → `SessionStore.profile`
///   (`@EnvironmentObject`, convention du projet).
/// - `ElasticScrollView` → `VStack` : la zone « journée » reste l'enfant flexible
///   (`flex: 1`), ce que la source décrit comme « toute la hauteur restante ».
/// - `FlatList horizontal pagingEnabled` → `TabView` en style `.page`
///   (`scrollTargetBehavior(.paging)` est iOS 17 : hors cible).
/// - `onLayout` → `GeometryReader` ; `useWindowDimensions()` → `geometry.size`.
/// - Ionicons → SF Symbols (équivalents donnés en commentaire à chaque appel).
/// - `useMemo(() => getProgramDays(), [])` → `@State` figé au montage.
/// - `cardShadow` → `.shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)`.
///
/// absent: TOUT le contenu Premium / paywall (formules, prix, essai gratuit,
/// RevenueCat, codes promo). La source n'en contient pas une seule ligne (voir §8 de
/// la spec d'extraction) : ce contenu vit dans `PaywallContent.tsx` /
/// `PaywallModal.tsx`, hors de ce lot. Le fichier est donc un écran de planification,
/// pas un écran d'offre.
/// absent: `AccountStorage` / `ACCOUNT_STORAGE_KEYS` (stockage scopé par compte) →
/// `PremiumStorage` (UserDefaults, clés logiques littérales de `storage/keys.ts`).
/// absent: `profile.dinnerTime`, `profile.dinnerDurationMinutes`, `profile.showerTime`,
/// `profile.showerDurationMinutes`, `profile.bedtime` — ces champs n'existent pas dans
/// `UserProfile` (`Models.swift`, non modifiable dans ce lot) : les blocages
/// dîner / douche / nuit de `nextAvailableMinute` ne sont donc pas portés.
/// absent: `lineHeight` (RN) — sans équivalent direct en SwiftUI.
/// absent: `console.log` (l. 168), `statusBarTranslucent`, `navigationBarTranslucent`,
/// `onRequestClose` (retour Android), `pointerEvents="box-none"`,
/// `initialNumToRender` / `windowSize` / `getItemLayout` / `decelerationRate`
/// (virtualisation du FlatList, sans objet avec `TabView`).
/// absent: `TaskCaptureCard` : la dictée vocale (`useDictation`) et le portail premium
/// (`usePremiumToolGate`) ne sont pas portés — seul le panneau de saisie l'est.

// MARK: - Types métier (repli local)

// `ParsedTask`, `PlanningSession` et `ClassSlot` vivent dans `src/types.ts` et
// `src/components/ScheduleEditor.tsx` côté Expo ; ils n'ont pas encore d'équivalent
// dans `Models.swift`, que ce lot ne modifie pas. Redéclarations locales limitées
// strictement aux champs consommés par l'écran — à déplacer dans `Models.swift`
// quand le socle les portera.

/// `TaskPriority` de `src/types.ts`.
private enum TaskPriority: String, Codable, CaseIterable {
    case haute, moyenne, basse
}

/// `ParsedTask` de `src/types.ts`.
private struct ParsedTask: Identifiable, Equatable, Codable {
    var id: String
    var title: String
    var subject: String
    var priority: TaskPriority
    var deadline: String?
    var estimatedDuration: Int?
}

/// `ClassSlot` de `src/components/ScheduleEditor.tsx` (`day` : `'Lundi'` … `'Samedi'`).
private struct ClassSlot: Identifiable, Equatable, Codable {
    var id: String
    var day: String
    var startTime: String
    var endTime: String
    var subject: String
    var room: String?
}

/// `PlanningSession` de `src/types.ts`. La couleur est conservée en hexadécimal
/// (`color` de la source, produite par `subjectVisuals`) et l'icône en nom de
/// symbole SF (`icon`, nom Ionicons dans la source).
private struct PlanningSession: Identifiable, Equatable {
    var id: String
    var dayOffset: Int
    var startTime: String
    var endTime: String
    var durationMinutes: Int
    var title: String
    var subtitle: String
    var priority: TaskPriority?
    var deadline: String?
    var colorHex: Int
    var icon: String
}

/// Un jour du programme (`ProgramDay` de la source, dérivé de `getProgramDays()`).
private struct ProgramDay: Identifiable, Equatable {
    var dayOffset: Int
    var dayLabel: String   // « sam » : 3 lettres minuscules, sans point
    var dayNumber: Int
    var fullLabel: String  // « 21 septembre »
    var date: Date
    var dateKey: String    // AAAA-MM-JJ

    var id: Int { dayOffset }
}

/// `OllamaSettings` de `src/utils/ollamaClient.ts`.
private struct OllamaSettings: Codable, Equatable {
    var enabled: Bool
    var baseUrl: String
    var model: String

    /// `DEFAULT_OLLAMA_SETTINGS` (l. 13-17).
    static let `default` = OllamaSettings(
        enabled: false,
        baseUrl: "http://192.168.1.10:11434",
        model: "qwen2.5:3b"
    )
}

// MARK: - Stockage local

/// Stockage de l'écran.
///
/// absent: `AccountStorage` / `ACCOUNT_STORAGE_KEYS` — le scoping par compte réel
/// n'est pas porté. Clés logiques littérales de `src/storage/keys.ts`
/// (`prepapp-program-tasks`, `prepapp-class-schedule`, `prepapp-ollama-settings`),
/// préfixées comme le fait le stockage de compte Expo.
private enum PremiumStorage {
    private static let prefix = "@prepapp/account-data:v1"

    private static func key(_ account: String, _ logicalKey: String) -> String {
        "\(prefix):\(account):\(logicalKey)"
    }

    /// `ACCOUNT_STORAGE_KEYS.programTasks` = `'prepapp-program-tasks'`.
    static func loadTasks(account: String) -> [ParsedTask]? {
        decode([ParsedTask].self, key(account, "prepapp-program-tasks"))
    }

    static func saveTasks(_ tasks: [ParsedTask], account: String) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: key(account, "prepapp-program-tasks"))
    }

    /// `ACCOUNT_STORAGE_KEYS.classSchedule` = `'prepapp-class-schedule'`.
    static func loadSchedule(account: String) -> [ClassSlot]? {
        decode([ClassSlot].self, key(account, "prepapp-class-schedule"))
    }

    /// `loadOllamaSettings` (l. 67-77) : fusion superficielle avec les valeurs par
    /// défaut ; toute lecture ou tout décodage en échec rend les valeurs par défaut.
    static func loadOllamaSettings(account: String) -> OllamaSettings {
        guard let data = UserDefaults.standard.data(forKey: key(account, "prepapp-ollama-settings")),
              let stored = try? JSONDecoder().decode(StoredOllamaSettings.self, from: data)
        else { return .default }
        return OllamaSettings(
            enabled: stored.enabled ?? OllamaSettings.default.enabled,
            baseUrl: stored.baseUrl ?? OllamaSettings.default.baseUrl,
            model: stored.model ?? OllamaSettings.default.model
        )
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Réglages partiellement stockés (la fusion de la source tolère les champs absents).
    private struct StoredOllamaSettings: Decodable {
        var enabled: Bool?
        var baseUrl: String?
        var model: String?
    }
}

// MARK: - Dates, heures et durées

/// Utilitaires transposés de `src/utils/date.ts` et des fonctions pures de
/// `EnhancedPlanScreen.tsx` (l. 360-623).
private enum PremiumDates {
    // MARK: Constantes de la grille (l. 360-366)

    /// `DAY_MINUTES = 24 * 60`.
    static let dayMinutes = 24 * 60
    /// `DAY_HEADER_HEIGHT = 30`.
    static let dayHeaderHeight: CGFloat = 30
    /// `TIMELINE_BOTTOM_PADDING = 10`.
    static let timelineBottomPadding: CGFloat = 10

    // MARK: Formats

    /// `longDateFormatter` (l. 18-22) : fr-FR, jour numérique, mois long, année.
    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    /// `shortWeekdayFormatter` de `date.ts` (`weekday: 'short'`, fr-FR).
    private static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    /// `monthDayFormatter` de `date.ts` (`day: 'numeric', month: 'long'`).
    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    /// `capitalize` de `date.ts` : seule la première lettre est mise en majuscule.
    static func capitalize(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    /// Date longue de l'en-tête de saisie (« 21 septembre 2026 »).
    static func longDate(_ date: Date) -> String {
        longDateFormatter.string(from: date)
    }

    /// `formatDateInput` (l. 467-471) : `JJ/MM/AAAA`.
    static func formatDateInput(_ date: Date) -> String {
        let calendar = Calendar.current
        return String(
            format: "%02d/%02d/%04d",
            calendar.component(.day, from: date),
            calendar.component(.month, from: date),
            calendar.component(.year, from: date)
        )
    }

    /// `maskDateInput` (l. 474-478) : insère les `/` à la place de l'utilisateur.
    /// Le masque plafonne à 8 chiffres, soit les 10 caractères du `maxLength` de la
    /// source en édition.
    static func maskDateInput(_ value: String) -> String {
        let digits = Array(value.filter { $0 >= "0" && $0 <= "9" }.prefix(8))
        var parts: [String] = []
        let day = String(digits.prefix(2))
        if !day.isEmpty { parts.append(day) }
        if digits.count > 2 { parts.append(String(digits[2..<min(4, digits.count)])) }
        if digits.count > 4 { parts.append(String(digits[4..<min(8, digits.count)])) }
        return parts.joined(separator: "/")
    }

    /// `parseDateInput` (l. 481-496) : accepte `JJ/MM`, `JJ/MM/AA` et `JJ/MM/AAAA` ;
    /// l'année omise se déduit du programme en cours (et bascule sur l'année suivante
    /// si la date calculée est déjà passée).
    static func parseDateInput(_ value: String, reference: Date) -> Date? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        guard parts[0].count <= 2, parts[1].count <= 2,
              let day = Int(parts[0]), let month = Int(parts[1]) else { return nil }

        let calendar = Calendar.current
        let year: Int
        if parts.count == 3 {
            let rawYear = parts[2]
            guard rawYear.count == 2 || rawYear.count == 4, let parsed = Int(rawYear) else { return nil }
            year = rawYear.count == 2 ? 2000 + parsed : parsed
        } else {
            year = calendar.component(.year, from: reference)
        }

        guard var date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else {
            return nil
        }
        // Validation stricte : `new Date(y, m-1, d, 12)` reporte les jours inexistants,
        // la source compare donc le jour et le mois obtenus à ceux demandés.
        guard calendar.component(.day, from: date) == day,
              calendar.component(.month, from: date) == month else { return nil }
        if parts.count == 2, date < reference {
            date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
        return date
    }

    /// `findDayForInput` (l. 498-503).
    static func findDay(for value: String, in days: [ProgramDay]) -> ProgramDay? {
        guard let reference = days.first?.date,
              let parsed = parseDateInput(value, reference: reference) else { return nil }
        let key = toLocalDateKey(parsed)
        return days.first { $0.dateKey == key }
    }

    /// `toLocalDateKey` de `date.ts` : `AAAA-MM-JJ`, composants locaux.
    static func toLocalDateKey(_ date: Date) -> String {
        let calendar = Calendar.current
        return String(
            format: "%04d-%02d-%02d",
            calendar.component(.year, from: date),
            calendar.component(.month, from: date),
            calendar.component(.day, from: date)
        )
    }

    /// `getProgramDays()` de `date.ts` : d'aujourd'hui (jour 0, midi) jusqu'au
    /// 21 septembre de l'année courante — ou de la suivante s'il est déjà passé —,
    /// borne incluse. Le jour 0 est bien aujourd'hui.
    static func programDays(today: Date = Date()) -> [ProgramDay] {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today
        let horizon = programHorizon(from: start)
        let span = calendar.dateComponents([.day], from: start, to: horizon).day ?? 0
        let dayCount = max(1, span + 1)

        return (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            // `replace('.', '')` de JS ne retire que le premier point (« sam. » → « sam »).
            let short = shortWeekdayFormatter.string(from: date)
                .replacingOccurrences(of: ".", with: "")
            return ProgramDay(
                dayOffset: offset,
                dayLabel: String(short.prefix(3)),
                dayNumber: calendar.component(.day, from: date),
                fullLabel: capitalize(monthDayFormatter.string(from: date)),
                date: date,
                dateKey: toLocalDateKey(date)
            )
        }
    }

    /// `getProgramHorizonDate` de `date.ts` : 21 septembre à midi, année suivante si
    /// la date de référence est déjà au-delà.
    static func programHorizon(from date: Date) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let current = calendar.date(from: DateComponents(year: year, month: 9, day: 21, hour: 12)) ?? date
        if date > current {
            return calendar.date(from: DateComponents(year: year + 1, month: 9, day: 21, hour: 12)) ?? current
        }
        return current
    }

    // MARK: Heures

    /// `new Date().getDay()` : dimanche = 0 … samedi = 6.
    static func jsWeekday(_ date: Date = Date()) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date) // dimanche = 1 … samedi = 7
        return (weekday + 6) % 7
    }

    /// `timeToMinutes` (l. 615-618). `nil` quand la chaîne n'est pas exploitable :
    /// JS rendrait `NaN`, dont toutes les comparaisons sont fausses — l'intervalle
    /// correspondant est alors ignoré.
    static func timeToMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
        return hours * 60 + minutes
    }

    /// `minutesToTime` (l. 620-623) : `HH:MM`, plafonné à 23:59.
    static func minutesToTime(_ minutes: Int) -> String {
        let safe = min(minutes, 23 * 60 + 59)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }

    /// `formatDuration` (l. 368-374) : « 1 h 05 », « 2 h », « 45 min ».
    static func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours != 0 && mins != 0 { return "\(hours) h \(String(format: "%02d", mins))" }
        if hours != 0 { return "\(hours) h" }
        return "\(mins) min"
    }
}

// MARK: - Plan : tâches, visuels, répartition

/// Constantes et calculs de l'écran, transposés de `EnhancedPlanScreen.tsx`.
private enum PremiumPlan {
    /// `starterTasks` (l. 24-30).
    static let starterTasks: [ParsedTask] = [
        ParsedTask(id: "maths-annales", title: "Annales — fonctions polynomiales",
                   subject: "Mathématiques", priority: .haute,
                   deadline: "Aujourd'hui", estimatedDuration: 80),
        ParsedTask(id: "physics-colle", title: "Reprendre la dernière colle de mécanique",
                   subject: "Physique", priority: .haute,
                   deadline: "Demain", estimatedDuration: 60),
        ParsedTask(id: "english-vocabulary", title: "Réviser vingt mots de vocabulaire",
                   subject: "Anglais", priority: .moyenne,
                   deadline: "Vendredi", estimatedDuration: 40),
        ParsedTask(id: "philosophy-plan", title: "Construire un plan détaillé",
                   subject: "Français-philo", priority: .moyenne,
                   deadline: "Mercredi", estimatedDuration: 60),
        ParsedTask(id: "weekly-review", title: "Faire le bilan des résultats et priorités",
                   subject: "Général", priority: .basse,
                   deadline: "Vendredi", estimatedDuration: 45),
    ]

    /// Visuel d'une matière : couleur (hex de `src/theme.ts`) et symbole SF.
    struct SubjectVisual {
        let colorHex: Int
        let icon: String
    }

    /// `subjectVisuals` (l. 32-42). Couleurs : `colors.primaryLight` = #ECEEED,
    /// `colors.lavender` = `colors.surfaceMuted` = #F4F5F4, `colors.accentLight`
    /// = #ECEEED. Icônes : nom Ionicons de la source → symbole SF équivalent.
    static let subjectVisuals: [String: SubjectVisual] = [
        "Mathématiques": SubjectVisual(colorHex: Theme.primaryLightHex, icon: "function"),
        "Physique": SubjectVisual(colorHex: Theme.surfaceMutedHex, icon: "flask"),
        "Chimie": SubjectVisual(colorHex: Theme.surfaceMutedHex, icon: "flask"),
        "Informatique": SubjectVisual(colorHex: Theme.primaryLightHex, icon: "laptopcomputer"),
        "Anglais": SubjectVisual(colorHex: Theme.surfaceMutedHex, icon: "globe"),
        "Français-philo": SubjectVisual(colorHex: Theme.primaryLightHex, icon: "book"),
        "Histoire-géographie": SubjectVisual(colorHex: Theme.surfaceMutedHex, icon: "book"),
        "Biologie": SubjectVisual(colorHex: Theme.primaryLightHex, icon: "flask"),
        "Général": SubjectVisual(colorHex: Theme.primaryLightHex, icon: "briefcase"),
    ]

    /// `priorityLabels` (l. 292).
    static func priorityLabel(_ priority: TaskPriority) -> String {
        switch priority {
        case .haute: return "Haute"
        case .moyenne: return "Moyenne"
        case .basse: return "Basse"
        }
    }

    /// `getDayName` (l. 605-608) : la chaîne vide correspond à dimanche (index 0).
    static func dayName(offset: Int) -> String {
        let names = ["", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
        return names[(PremiumDates.jsWeekday() + offset) % 7]
    }

    /// `isWeekend` (l. 610-613).
    static func isWeekend(offset: Int) -> Bool {
        let day = (PremiumDates.jsWeekday() + offset) % 7
        return day == 0 || day == 6
    }

    // MARK: Répartition des tâches

    /// `distributeTasks` (l. 505-559) : place chaque tâche au plus tôt, sur les jours
    /// qui précèdent sa deadline.
    static func distributeTasks(
        _ tasks: [ParsedTask],
        schedule: [ClassSlot],
        dayCount: Int,
        profile: UserProfile
    ) -> [PlanningSession] {
        guard dayCount > 0 else { return [] }
        // Curseurs : jour 0 → 17:00, week-end → 09:00, semaine → 17:00.
        var cursors = (0..<dayCount).map { day -> Int in
            if day == 0 { return 17 * 60 }
            return isWeekend(offset: day) ? 9 * 60 : 17 * 60
        }
        var sessions: [PlanningSession] = []

        for task in tasks {
            let latestDay = min(deadlineOffset(task.deadline, dayCount: dayCount), dayCount - 1)
            let duration = min(120, max(25, task.estimatedDuration ?? 45))
            var chosenDay = 0
            var chosenStart = Int.max

            for day in 0...max(0, latestDay) {
                let candidate = nextAvailableMinute(
                    start: cursors[day], duration: duration, dayOffset: day,
                    schedule: schedule, sessions: sessions, profile: profile
                )
                if candidate < chosenStart {
                    chosenStart = candidate
                    chosenDay = day
                }
            }

            // Aucun créneau retenu, ou dépassement de 21:00 : on bascule sur le jour
            // suivant la deadline.
            if chosenStart == Int.max || chosenStart + duration > 21 * 60 {
                chosenDay = min(latestDay + 1, dayCount - 1)
                chosenStart = nextAvailableMinute(
                    start: isWeekend(offset: chosenDay) ? 9 * 60 : 17 * 60,
                    duration: duration, dayOffset: chosenDay,
                    schedule: schedule, sessions: sessions, profile: profile
                )
            }

            // Repli de la source : `subjectVisuals[task.subject] ?? subjectVisuals.Général`.
            let visual = subjectVisuals[task.subject]
                ?? subjectVisuals["Général"]
                ?? SubjectVisual(colorHex: Theme.primaryLightHex, icon: "briefcase")
            let end = chosenStart + duration
            sessions.append(PlanningSession(
                id: "scheduled-\(task.id)",
                dayOffset: chosenDay,
                startTime: PremiumDates.minutesToTime(chosenStart),
                endTime: PremiumDates.minutesToTime(end),
                durationMinutes: duration,
                title: task.subject,
                subtitle: task.title,
                priority: task.priority,
                deadline: task.deadline,
                colorHex: visual.colorHex,
                icon: visual.icon
            ))
            cursors[chosenDay] = end + 15
        }

        // Tri : jour croissant, puis heure de début (`localeCompare` sur « HH:MM »).
        return sessions.sorted {
            $0.dayOffset == $1.dayOffset
                ? $0.startTime < $1.startTime
                : $0.dayOffset < $1.dayOffset
        }
    }

    /// `nextAvailableMinute` (l. 561-582) : évite les cours du jour, les séances déjà
    /// placées, puis décale de 15 min après chaque chevauchement — un seul passage,
    /// comme dans la source.
    ///
    /// absent: les trois autres intervalles bloqués de la source — dîner
    /// (`profile.dinnerTime` + `dinnerDurationMinutes`), douche (`profile.showerTime`
    /// + `showerDurationMinutes`) et nuit (`profile.bedtime` → minuit) — ne sont pas
    /// portés : ces champs n'existent pas dans `UserProfile`.
    static func nextAvailableMinute(
        start: Int,
        duration: Int,
        dayOffset: Int,
        schedule: [ClassSlot],
        sessions: [PlanningSession],
        profile: UserProfile
    ) -> Int {
        var candidate = start
        let dayName = self.dayName(offset: dayOffset)

        var blocked: [(Int, Int)] = []
        blocked += schedule
            .filter { $0.day == dayName }
            .compactMap { slot in
                guard let from = PremiumDates.timeToMinutes(slot.startTime),
                      let to = PremiumDates.timeToMinutes(slot.endTime) else { return nil }
                return (from, to)
            }
        blocked += sessions
            .filter { $0.dayOffset == dayOffset }
            .compactMap { session in
                guard let from = PremiumDates.timeToMinutes(session.startTime),
                      let to = PremiumDates.timeToMinutes(session.endTime) else { return nil }
                return (from, to)
            }
        blocked.sort { $0.0 < $1.0 }

        for (blockedStart, blockedEnd) in blocked {
            if candidate < blockedEnd && candidate + duration > blockedStart {
                candidate = blockedEnd + 15
            }
        }
        return candidate
    }

    /// `deadlineOffset` (l. 584-603) : échéance textuelle → décalage en jours.
    static func deadlineOffset(_ deadline: String?, dayCount: Int) -> Int {
        let fallback = min(6, dayCount - 1)
        guard let deadline, !deadline.isEmpty else { return fallback }
        // La source ne retire pas les accents ici, seulement la casse.
        let normalized = deadline.lowercased()
        if normalized.contains("aujourd'hui") || normalized.contains("ce soir") { return 0 }
        if normalized.contains("après-demain") || normalized.contains("apres-demain") { return 2 }
        if normalized.contains("demain") { return 1 }
        if let numeric = numericDeadlineOffset(normalized, dayCount: dayCount) { return numeric }
        let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        if let target = names.firstIndex(where: { normalized.contains($0) }) {
            return (target - PremiumDates.jsWeekday() + 7) % 7
        }
        return fallback
    }

    /// Branche « JJ/MM » ou « JJ/MM/AA(AA) » de `deadlineOffset` (l. 590-599).
    private static func numericDeadlineOffset(_ normalized: String, dayCount: Int) -> Int? {
        let pattern = "(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
        else { return nil }

        func group(_ index: Int) -> String? {
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: normalized) else { return nil }
            return String(normalized[swiftRange])
        }

        guard let dayText = group(1), let monthText = group(2),
              let day = Int(dayText), let month = Int(monthText) else { return nil }
        let yearText = group(3)

        let calendar = Calendar.current
        let today = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        let suppliedYear = yearText.flatMap { Int($0) } ?? calendar.component(.year, from: today)
        let fullYear = suppliedYear < 100 ? 2000 + suppliedYear : suppliedYear
        guard var target = calendar.date(from: DateComponents(year: fullYear, month: month, day: day, hour: 12)) else {
            return nil
        }
        if yearText == nil, target < today {
            target = calendar.date(byAdding: .year, value: 1, to: target) ?? target
        }
        let days = Int((target.timeIntervalSince(today) / 86_400).rounded())
        return max(0, min(dayCount - 1, days))
    }
}

// MARK: - Analyseur local de tâches

/// Transposition de `src/utils/taskParser.ts` (analyseur de repli, hors réseau).
private enum PremiumTaskParser {
    /// `SUBJECT_ALIASES` (l. 3-12), ordre de la source conservé.
    private static let subjectAliases: [(String, [String])] = [
        ("Mathématiques", ["math", "maths", "mathematique", "algèbre", "algebre", "analyse"]),
        ("Physique", ["physique", "mécanique", "mecanique", "électricité", "electricite"]),
        ("Chimie", ["chimie", "thermochimie"]),
        ("Informatique", ["informatique", "info", "python", "sql"]),
        ("Anglais", ["anglais", "english", "vocabulaire"]),
        ("Français-philo", ["français", "francais", "philo", "philosophie", "dissertation"]),
        ("Histoire-géographie", ["histoire", "géographie", "geographie", "géopo", "geopo"]),
        ("Biologie", ["biologie", "bio", "svt"]),
    ]

    /// `normalize` (l. 14-16) : minuscules puis suppression des diacritiques
    /// (JS : `.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')`).
    /// Décomposition canonique puis retrait des seules marques combinantes
    /// U+0300–U+036F, exactement comme la source — sans replier la ponctuation
    /// (une apostrophe typographique reste une apostrophe typographique).
    private static func normalize(_ value: String) -> String {
        let decomposed = value.lowercased().decomposedStringWithCanonicalMapping
        let stripped = decomposed.unicodeScalars.filter { !(0x0300...0x036F).contains($0.value) }
        return String(String.UnicodeScalarView(stripped))
    }

    /// `parseTaskDump` (l. 51-67).
    static func parseTaskDump(_ transcript: String) -> [ParsedTask] {
        var text = transcript
        text = replace(text, pattern: "\\s+(?:et ensuite|ensuite|puis|et aussi|aussi)\\s+", with: ". ")
        text = replace(
            text,
            pattern: ",\\s+(?=(?:faire|finir|réviser|reviser|lire|apprendre|préparer|preparer|reprendre|travailler)\\b)",
            with: ". "
        )

        return chunks(of: text).enumerated().map { index, chunk in
            ParsedTask(
                id: "task-\(nowMillis())-\(index)",
                title: capitalizeFirst(chunk),
                subject: inferSubject(chunk),
                priority: inferPriority(chunk),
                deadline: inferDeadline(chunk),
                estimatedDuration: inferDuration(chunk)
            )
        }
    }

    /// `taskUrgencyScore` (l. 69-82) : priorité (300/200/100) + échéance (60/50/30/15/0).
    static func urgencyScore(_ task: ParsedTask) -> Int {
        let priority: Int
        switch task.priority {
        case .haute: priority = 300
        case .moyenne: priority = 200
        case .basse: priority = 100
        }

        let deadline = normalize(task.deadline ?? "")
        let deadlineScore: Int
        if deadline.contains("aujourd'hui") || deadline.contains("ce soir") {
            deadlineScore = 60
        } else if deadline.contains("demain") {
            deadlineScore = 50
        } else if matches("lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche", in: deadline) {
            deadlineScore = 30
        } else if !deadline.isEmpty {
            deadlineScore = 15
        } else {
            deadlineScore = 0
        }
        return priority + deadlineScore
    }

    // MARK: Découpage (l. 52-57)

    /// `.split(/\n+|[.;]+/)` puis nettoyage des extrémités et filtre `length >= 4`.
    private static func chunks(of text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "\\n+|[.;]+") else { return [] }
        let source = text as NSString
        var raw: [String] = []
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            raw.append(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length
        }
        raw.append(source.substring(from: cursor))

        return raw
            .map { trimEdges($0) }
            .filter { $0.count >= 4 }
    }

    /// `replace(/^[\s,\-–]+|[\s,\-–]+$/g, '').trim()`.
    private static func trimEdges(_ value: String) -> String {
        let edges: Set<Character> = [" ", "\t", "\n", "\r", "\u{0B}", "\u{0C}", ",", "-", "–"]
        var characters = Array(value)
        while let first = characters.first, edges.contains(first) { characters.removeFirst() }
        while let last = characters.last, edges.contains(last) { characters.removeLast() }
        return String(characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `chunk.charAt(0).toUpperCase() + chunk.slice(1)`.
    private static func capitalizeFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    // MARK: Inférences (l. 18-49)

    /// `inferSubject` : premier libellé canonique dont un alias est contenu.
    private static func inferSubject(_ text: String) -> String {
        let normalized = normalize(text)
        for (subject, aliases) in subjectAliases
        where aliases.contains(where: { normalized.contains(normalize($0)) }) {
            return subject
        }
        return "Général"
    }

    /// `inferPriority` : l'ordre des tests est celui de la source (« pas urgent »
    /// contient « urgent » et ressort donc « haute »).
    private static func inferPriority(_ text: String) -> TaskPriority {
        let normalized = normalize(text)
        if matches("urgent|priorite haute|tres important|imperatif|absolument", in: normalized) {
            return .haute
        }
        if matches("pas urgent|priorite basse|si j.ai le temps|secondaire", in: normalized) {
            return .basse
        }
        return .moyenne
    }

    /// `inferDeadline` : première échéance reconnue, capitalisée sur son premier caractère.
    private static func inferDeadline(_ text: String) -> String? {
        let normalized = normalize(text)
        let pattern = "(aujourd'hui|demain|apres-demain|ce soir|lundi|mardi|mercredi|jeudi|vendredi"
            + "|samedi|dimanche|cette semaine|ce week-end|week-end|avant (?:le )?\\d{1,2}(?:/\\d{1,2})?)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              let range = Range(match.range(at: 1), in: normalized)
        else { return nil }
        return capitalizeFirst(String(normalized[range]))
    }

    /// `inferDuration` : heures (« 1 h », « 1,5 heure »), puis minutes, sinon 45.
    private static func inferDuration(_ text: String) -> Int {
        let normalized = normalize(text)
        if let hours = firstGroup("(\\d+(?:[.,]\\d+)?)\\s*(?:h|heure)", in: normalized) {
            let value = Double(hours.replacingOccurrences(of: ",", with: ".")) ?? 0
            return Int((value * 60).rounded())
        }
        if let minutes = firstGroup("(\\d+)\\s*(?:min|minute)", in: normalized) {
            return Int(minutes) ?? 45
        }
        return 45
    }

    // MARK: Expressions régulières

    private static func matches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func firstGroup(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func replace(_ text: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        return regex.stringByReplacingMatches(
            in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: template
        )
    }

    private static func nowMillis() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - Analyse IA locale (Ollama)

/// Transposition de `src/utils/ollamaClient.ts` — appel direct au serveur Ollama de
/// l'utilisateur, hors backend Duello.
///
/// absent: `DuelloAPI.request(...)` n'est pas utilisable ici : l'endpoint
/// `/api/chat` appartient au serveur Ollama local (`ollamaSettings.baseUrl`), pas à
/// l'API Duello. Helper local, appelé en direct par `URLSession`, comme la source.
/// absent: `saveOllamaSettings` et `testOllamaConnection` (non consommés par l'écran).
private enum OllamaClient {
    /// `REQUEST_TIMEOUT_MS = 30000`.
    private static let requestTimeout: TimeInterval = 30

    /// `KNOWN_SUBJECTS` (l. 21-31).
    private static let knownSubjects = [
        "Mathématiques", "Physique", "Chimie", "Informatique", "Anglais",
        "Français-philo", "Histoire-géographie", "Biologie", "Général",
    ]

    /// `VALID_PRIORITIES` (l. 20).
    private static let validPriorities = ["haute", "moyenne", "basse"]

    /// `SYSTEM_PROMPT` (l. 33-44), verbatim — apostrophes droites de la source.
    private static let systemPrompt = #"""
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
"""#

    /// `TASK_RESPONSE_SCHEMA` (l. 46-65), passé en `format` (sortie structurée).
    private static var responseSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "tasks": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string"],
                            "subject": ["type": "string"],
                            "priority": ["type": "string", "enum": validPriorities],
                            "deadline": ["type": ["string", "null"]],
                            "estimatedDuration": ["type": "integer"],
                        ],
                        "required": ["title", "subject", "priority"],
                    ],
                ],
            ],
            "required": ["tasks"],
        ]
    }

    enum OllamaError: LocalizedError {
        case invalidUrl
        case status(Int)
        case emptyResponse
        case unexpectedFormat

        var errorDescription: String? {
            switch self {
            case .invalidUrl: return "Adresse du serveur Ollama invalide."
            case .status(let code): return "Ollama a répondu avec le statut \(code)"
            case .emptyResponse: return "Réponse Ollama vide"
            case .unexpectedFormat: return "Format de réponse Ollama inattendu"
            }
        }
    }

    /// `parseTaskDumpWithOllama` (l. 131-183). Toute erreur est propagée : l'écran
    /// bascule alors sur `PremiumTaskParser.parseTaskDump`.
    static func parseTaskDumpWithOllama(
        _ transcript: String,
        settings: OllamaSettings
    ) async throws -> [ParsedTask] {
        guard let url = URL(string: trimBaseUrl(settings.baseUrl) + "/api/chat") else {
            throw OllamaError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // absent: `AbortController` + `setTimeout(30 s)` → `timeoutInterval`.
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": settings.model,
            "stream": false,
            "format": responseSchema,
            "options": ["temperature": 0.2],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript],
            ],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else { throw OllamaError.status(http.statusCode) }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = root["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty
        else { throw OllamaError.emptyResponse }

        guard let payload = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any],
              let rawTasks = payload["tasks"] as? [Any]
        else { throw OllamaError.unexpectedFormat }

        return rawTasks.enumerated().compactMap { index, entry in
            guard let task = entry as? [String: Any] else { return nil }
            let title = (task["title"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty else { return nil }
            let deadline = (task["deadline"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedTask(
                id: "task-ollama-\(PremiumTaskParser.nowMillis())-\(index)",
                title: title,
                subject: normalizeSubject(task["subject"]),
                priority: normalizePriority(task["priority"]),
                deadline: (deadline?.isEmpty ?? true) ? nil : deadline,
                estimatedDuration: clampDuration(task["estimatedDuration"])
            )
        }
    }

    /// `trimBaseUrl` (l. 112-114).
    private static func trimBaseUrl(_ baseUrl: String) -> String {
        var trimmed = baseUrl.trimmingCharacters(in: .whitespaces)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }

    /// `normalizeSubject` (l. 126-129) : correspondance exacte, insensible à la casse.
    private static func normalizeSubject(_ value: Any?) -> String {
        let text = ((value as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return knownSubjects.first { $0.lowercased() == text.lowercased() } ?? "Général"
    }

    /// `normalizePriority` (l. 122-124).
    private static func normalizePriority(_ value: Any?) -> TaskPriority {
        guard let text = value as? String, let priority = TaskPriority(rawValue: text) else { return .moyenne }
        return priority
    }

    /// `clampDuration` (l. 116-120) : 10 à 240 minutes, 45 par défaut.
    private static func clampDuration(_ value: Any?) -> Int {
        let parsed: Double?
        if value is NSNull {
            parsed = 0 // `Number(null) === 0` en JS
        } else if let number = value as? Double {
            parsed = number
        } else if let text = value as? String, let number = Double(text) {
            parsed = number
        } else {
            parsed = nil
        }
        guard let parsed, parsed.isFinite else { return 45 }
        return min(240, max(10, Int(parsed.rounded())))
    }
}

// MARK: - Écran

/// Racine de l'écran (voir la documentation de tête de fichier).
struct PremiumView: View {
    @EnvironmentObject private var session: SessionStore

    /// `useMemo(() => getProgramDays(), [])` : figé au montage.
    @State private var days: [ProgramDay] = PremiumDates.programDays()
    @State private var selectedDayOffset = 0
    /// `useState(() => formatDateInput(new Date()))`.
    @State private var dateInput = PremiumDates.formatDateInput(Date())
    @State private var dateError: String?
    /// Hors saisie, la date s'affiche en toutes lettres ; le format chiffré
    /// n'apparaît que pendant la frappe, où il est le plus rapide à taper.
    @State private var isEditingDate = false
    @State private var tasks: [ParsedTask] = PremiumPlan.starterTasks
    @State private var schedule: [ClassSlot] = []
    /// Garde d'écriture du stockage : tant qu'il vaut `false`, aucune tâche n'est
    /// écrite (le chargement initial ne doit jamais écraser les données).
    @State private var hasLoaded = false
    @State private var lastAddedCount = 0
    @State private var ollamaSettings: OllamaSettings = .default
    @State private var isAnalyzing = false
    @State private var ollamaFallbackNotice = false
    @State private var selectedSession: PlanningSession?
    /// Équivalent de `clearTimeout` : la remise à zéro de la bannière est annulable.
    @State private var bannerResetTask: Task<Void, Never>?

    @FocusState private var isDateFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isAnalyzing {
                analyzingBanner
            }
            if !isAnalyzing && ollamaFallbackNotice {
                fallbackBanner
            }
            if !isAnalyzing && lastAddedCount > 0 {
                addedBanner
            }

            dateJump

            if schedule.isEmpty {
                scheduleHint
            }

            dayArea
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            PremiumTaskCaptureCard { transcript in
                Task { await handleTranscript(transcript) }
            }
        }
        .overlay {
            if let selectedSession {
                PremiumSessionDetailModal(session: selectedSession) {
                    self.selectedSession = nil
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSession?.id)
        .onAppear(perform: loadProgram)
        .onChange(of: tasks) { _ in persistTasks() }
        .onChange(of: lastAddedCount) { value in scheduleBannerReset(value) }
        .onChange(of: selectedDayOffset) { value in selectDay(value) }
        .onChange(of: isDateFieldFocused) { focused in
            if focused {
                startEditingDate()
            } else {
                submitDateInput()
            }
        }
    }

    // MARK: Données dérivées

    /// Identifiant de compte servant au stockage.
    /// absent: `AccountStorage` — l'identifiant de compte réel n'est pas porté ;
    /// approximation sur l'e-mail du profil, normalisé.
    private var accountId: String {
        session.profile.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var selectedDay: ProgramDay {
        if days.indices.contains(selectedDayOffset) { return days[selectedDayOffset] }
        return days.first ?? ProgramDay(
            dayOffset: 0, dayLabel: "", dayNumber: 0, fullLabel: "", date: Date(), dateKey: ""
        )
    }

    /// `distributedSessions` (l. 100-103).
    private var distributedSessions: [PlanningSession] {
        PremiumPlan.distributeTasks(
            tasks, schedule: schedule, dayCount: days.count, profile: session.profile
        )
    }

    /// Valeur affichée par le champ date : toutes lettres hors édition, format
    /// chiffré pendant la frappe.
    private var dateFieldText: Binding<String> {
        Binding(
            get: { isEditingDate ? dateInput : PremiumDates.longDate(selectedDay.date) },
            set: { handleDateInput($0) }
        )
    }

    // MARK: Chargement et persistance (l. 66-97)

    /// Chargement initial. La source lance les trois lectures en parallèle
    /// (`Promise.all`) et pose `hasLoaded` dans un `finally` : le stockage local étant
    /// synchrone, la garde est posée inconditionnellement en fin de fonction.
    private func loadProgram() {
        if let stored = PremiumStorage.loadTasks(account: accountId) { tasks = stored }
        if let stored = PremiumStorage.loadSchedule(account: accountId) { schedule = stored }
        ollamaSettings = PremiumStorage.loadOllamaSettings(account: accountId)
        hasLoaded = true
    }

    private func persistTasks() {
        guard hasLoaded else { return }
        PremiumStorage.saveTasks(tasks, account: accountId)
    }

    /// Auto-effacement du feedback d'ajout après 3 500 ms (l. 93-97).
    private func scheduleBannerReset(_ count: Int) {
        bannerResetTask?.cancel()
        guard count != 0 else { return }
        bannerResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            lastAddedCount = 0
        }
    }

    // MARK: Sélection du jour (l. 106-156)

    /// Sélection déclenchée par le balayage horizontal : le champ suit le jour affiché.
    private func selectDay(_ dayOffset: Int) {
        guard days.indices.contains(dayOffset) else { return }
        let day = days[dayOffset]
        selectedDayOffset = dayOffset
        dateInput = PremiumDates.formatDateInput(day.date)
        dateError = nil
    }

    /// `setSelectedDayOffset` + `scrollToIndex` : la sélection du `TabView` fait
    /// défiler la page.
    private func goToDay(_ dayOffset: Int) {
        selectedDayOffset = dayOffset
    }

    private func handleDateInput(_ value: String) {
        let masked = PremiumDates.maskDateInput(value)
        dateInput = masked
        if let target = PremiumDates.findDay(for: masked, in: days) {
            dateError = nil
            goToDay(target.dayOffset)
        }
    }

    private func startEditingDate() {
        dateInput = PremiumDates.formatDateInput(selectedDay.date)
        isEditingDate = true
    }

    /// Validation explicite : c'est le seul moment où l'on signale une saisie inutilisable.
    private func submitDateInput() {
        isEditingDate = false
        guard let target = PremiumDates.findDay(for: dateInput, in: days) else {
            // Référence du parsing : `days[0].date`, comme `findDayForInput`.
            let reference = days.first?.date ?? selectedDay.date
            dateError = PremiumDates.parseDateInput(dateInput, reference: reference) != nil
                ? "Cette date est en dehors de ton programme."
                : "Format attendu : JJ/MM/AAAA."
            return
        }
        dateError = nil
        dateInput = PremiumDates.formatDateInput(target.date)
        goToDay(target.dayOffset)
    }

    private func goToToday() {
        dateInput = PremiumDates.formatDateInput(selectedDay.date)
        dateError = nil
        goToDay(0)
    }

    // MARK: Ajout de tâches (l. 158-183)

    @MainActor
    private func handleTranscript(_ transcript: String) async {
        ollamaFallbackNotice = false
        let useOllama = ollamaSettings.enabled
            && !ollamaSettings.baseUrl.trimmingCharacters(in: .whitespaces).isEmpty
        var addedTasks: [ParsedTask]

        if useOllama {
            isAnalyzing = true
            do {
                addedTasks = try await OllamaClient.parseTaskDumpWithOllama(transcript, settings: ollamaSettings)
            } catch {
                // absent: console.log('Analyse Ollama indisponible, repli sur l’analyseur local:', error)
                addedTasks = PremiumTaskParser.parseTaskDump(transcript)
                ollamaFallbackNotice = true
            }
            isAnalyzing = false // `finally` de la source
        } else {
            addedTasks = PremiumTaskParser.parseTaskDump(transcript)
        }

        if addedTasks.isEmpty { return }
        // Tri par urgence décroissante.
        tasks = (tasks + addedTasks).sorted {
            PremiumTaskParser.urgencyScore($0) > PremiumTaskParser.urgencyScore($1)
        }
        lastAddedCount = addedTasks.count
    }

    // MARK: Bannières (l. 191-214)

    /// B1 — analyse IA en cours (`successBanner` / `successText`).
    private var analyzingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(Theme.primary)
            Text("Qwen analyse tes tâches et tes formules…")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    /// B2 — repli sur l'analyseur local (`scheduleHint` / `scheduleHintText`).
    private var fallbackBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle") // Ionicons « warning-outline »
                .font(.system(size: 18))
                .foregroundStyle(Theme.ink) // colors.accent = #0A0D0C
            Text("Assistant IA local injoignable, tâches ajoutées avec l’analyseur standard.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Theme.primaryLight) // colors.accentLight = #ECEEED
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    /// B3 — ajout réussi, pluriel conditionnel, effacé après 3 500 ms.
    private var addedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle") // Ionicons « checkmark-circle »
                .font(.system(size: 19))
                .foregroundStyle(Theme.primary)
            Text("\(lastAddedCount) \(lastAddedCount > 1 ? "tâches ajoutées et planifiées" : "tâche ajoutée et planifiée").")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // MARK: Saut de date (l. 216-245)

    private var dateJump: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "calendar") // Ionicons « calendar-outline »
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.inkSoft)

                TextField("JJ/MM/AAAA", text: dateFieldText)
                    .focused($isDateFieldFocused)
                    .keyboardType(.numberPad)
                    .submitLabel(.go)
                    .onSubmit(submitDateInput)
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(0.5)
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Aller à une date")

                if selectedDayOffset != 0 {
                    Button(action: goToToday) {
                        Text("Aujourd’hui")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Theme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PremiumPressedButtonStyle(pressedOpacity: 0.7))
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
                    .foregroundStyle(Theme.ink) // colors.accent = #0A0D0C
                    .padding(.top, 6)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: Hint horaires (l. 247-254)

    private var scheduleHint: some View {
        HStack(spacing: 9) {
            Image(systemName: "clock") // Ionicons « time-outline »
                .font(.system(size: 18))
                .foregroundStyle(Theme.ink)
            Text("Ajoute tes horaires de cours dans ton profil pour éviter automatiquement ces créneaux.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: Journée (l. 256-285)

    /// `dayArea` : la journée occupe toute la largeur et toute la hauteur restante :
    /// aucun encadré, et la grille de 24 heures reste visible d'un seul coup d'œil.
    /// `onLayout` devient `GeometryReader` ; la `FlatList` n'est rendue que lorsque la
    /// hauteur est connue (`dayAreaHeight > 0`).
    private var dayArea: some View {
        GeometryReader { geometry in
            if geometry.size.height > 0 {
                TabView(selection: $selectedDayOffset) {
                    ForEach(days) { day in
                        dayPage(
                            day,
                            sessions: distributedSessions.filter { $0.dayOffset == day.dayOffset },
                            width: geometry.size.width,
                            areaHeight: geometry.size.height
                        )
                        .tag(day.dayOffset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .padding(.bottom, 66) // dayArea { flex: 1, marginBottom: 66 }
    }

    /// `renderDayPage` (l. 378-465).
    private func dayPage(
        _ day: ProgramDay,
        sessions daySessions: [PlanningSession],
        width: CGFloat,
        areaHeight: CGFloat
    ) -> some View {
        let isToday = day.dayOffset == 0
        let timelineHeight = max(
            areaHeight - PremiumDates.dayHeaderHeight - PremiumDates.timelineBottomPadding,
            240
        )
        let pxPerMinute = timelineHeight / CGFloat(PremiumDates.dayMinutes)
        let now = Date()
        let nowMinutes: Int? = isToday
            ? Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
            : nil
        let plannedMinutes = daySessions.reduce(0) { $0 + $1.durationMinutes }

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(isToday ? "Aujourd'hui" : "\(PremiumDates.capitalize(day.dayLabel)) \(day.fullLabel)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(daySessions.isEmpty
                     ? "Rien de prévu"
                     : "\(daySessions.count) \(daySessions.count > 1 ? "blocs" : "bloc") · \(PremiumDates.formatDuration(plannedMinutes))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }
            .frame(height: PremiumDates.dayHeaderHeight)

            ZStack(alignment: .topLeading) {
                ForEach(0..<25, id: \.self) { hour in
                    hourTick(hour, pxPerMinute: pxPerMinute)
                }

                if let nowMinutes {
                    nowLine(minutes: nowMinutes, pxPerMinute: pxPerMinute)
                }

                if daySessions.isEmpty {
                    freeSlot(timelineHeight: timelineHeight)
                }

                ForEach(daySessions) { session in
                    sessionBlock(session, pxPerMinute: pxPerMinute) {
                        selectedSession = session
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: timelineHeight, alignment: .top)
        }
        .padding(.horizontal, 16) // dayPage { paddingHorizontal: 16 }
        .frame(width: width, height: areaHeight, alignment: .top)
    }

    /// Une graduation horaire (`hourTick` + `hourLabel` + `hourLine`), placée à
    /// `hour * 60 * pxPerMinute` du haut de la grille.
    private func hourTick(_ hour: Int, pxPerMinute: CGFloat) -> some View {
        let isStrong = hour % 6 == 0
        return HStack(spacing: 0) {
            Color.clear.frame(width: 38) // hourLine { left: 38 }
            Rectangle()
                .fill(isStrong ? Theme.inkFaint : Theme.border)
                .frame(height: isStrong ? 1 : 0.5) // StyleSheet.hairlineWidth
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            Text(String(format: "%02d:00", hour % 24))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 36, alignment: .leading)
                .offset(y: -6) // hourLabel { top: -6 }
        }
        .offset(y: CGFloat(hour * 60) * pxPerMinute)
    }

    /// Ligne « maintenant », uniquement aujourd'hui (`nowLine` / `nowDot` / `nowLineBar`).
    private func nowLine(minutes: Int, pxPerMinute: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 33) // nowLine { left: 36 } + nowDot { marginLeft: -3 }
            Circle()
                .fill(Theme.ink)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(Theme.ink)
                .frame(height: 1.5)
        }
        .frame(maxWidth: .infinity)
        .offset(y: CGFloat(minutes) * pxPerMinute)
    }

    /// « Journée libre » (`freeSlot`), centré sur la grille.
    private func freeSlot(timelineHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 42) // freeSlot { left: 42 }
            HStack(spacing: 7) {
                Image(systemName: "leaf") // Ionicons « leaf-outline »
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkFaint)
                Text("Journée libre")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: timelineHeight)
    }

    /// Un bloc de séance (`timelineBlock`), de `top` à `top + blockHeight`.
    private func sessionBlock(
        _ session: PlanningSession,
        pxPerMinute: CGFloat,
        onSelect: @escaping () -> Void
    ) -> some View {
        let top = CGFloat(PremiumDates.timeToMinutes(session.startTime) ?? 0) * pxPerMinute
        let blockHeight = max(CGFloat(session.durationMinutes) * pxPerMinute - 2, 14)
        // La journée entière tenant dans la page, les blocs sont courts : le contenu
        // se réduit au fur et à mesure pour rester lisible sur une seule ligne.
        let compact = blockHeight < 42
        let tiny = blockHeight < 24

        return HStack(spacing: 0) {
            Color.clear.frame(width: 42) // timelineBlock { left: 42 }
            Button(action: onSelect) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.ink)
                        .frame(width: 3) // timelineAccent
                    VStack(alignment: .leading, spacing: 0) {
                        Text(compact ? "\(session.startTime) · \(session.title)" : session.title)
                            .font(.system(size: tiny ? 9 : 12, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        if !compact {
                            Text(session.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.inkSoft)
                                .lineLimit(1)
                                .padding(.top, 2)
                            Text("\(session.startTime)–\(session.endTime) · \(PremiumDates.formatDuration(session.durationMinutes))")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.inkFaint)
                                .padding(.top, 3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, tiny ? 0 : 4)
                    .padding(.horizontal, tiny ? 6 : 8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: blockHeight)
                .background(Color(hex: session.colorHex))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(PremiumPressedButtonStyle(pressedOpacity: 0.7))
            .accessibilityLabel("\(session.startTime) \(session.title) — \(session.subtitle), \(PremiumDates.formatDuration(session.durationMinutes))")
        }
        .frame(maxWidth: .infinity)
        .offset(y: top)
    }
}

// MARK: - Détail d'une séance (l. 294-358)

/// `SessionDetailModal` : feuille basse par-dessus l'écran, fermée par un appui sur le
/// fond ou sur le bouton « Fermer ».
///
/// absent: `Modal transparent animationType="fade"` → superposition + `transition(.opacity)` ;
/// `statusBarTranslucent`, `navigationBarTranslucent` et `onRequestClose` (retour
/// Android) n'existent pas sur iOS.
/// absent: `useSafeAreaInsets` — la carte respecte la zone sûre d'iOS par défaut.
private struct PremiumSessionDetailModal: View {
    let session: PlanningSession
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // modalBackdrop { backgroundColor: 'rgba(15, 23, 42, 0.45)' }
            Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
                .opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            card
                .padding(16)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: session.colorHex))
                        .frame(width: 44, height: 44)
                    Image(systemName: session.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.title)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("\(session.startTime) – \(session.endTime) · \(PremiumDates.formatDuration(session.durationMinutes))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onClose) {
                    Image(systemName: "xmark") // Ionicons « close »
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PremiumPressedButtonStyle(pressedOpacity: 0.7))
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

            PremiumFlowLayout(spacing: 8) {
                if let priority = session.priority {
                    metaChip(icon: "flag", text: "Priorité \(PremiumPlan.priorityLabel(priority))")
                }
                if let deadline = session.deadline {
                    metaChip(icon: "alarm", text: "Pour \(deadline)")
                }
                metaChip(icon: "hourglass", text: "\(PremiumDates.formatDuration(session.durationMinutes)) de travail")
            }
            .padding(.top, 16)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        // cardShadow : offset (0, 2), opacité 0.04, rayon 8, couleur #0A0D0C.
        .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    /// `modalMetaChip` + `modalMetaText`.
    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Carte de saisie des tâches

/// `TaskCaptureCard` (`src/components/TaskCaptureCard.tsx`), seule dépendance
/// d'interface de l'écran : une carte flottante ancrée en bas, bouton micro compris.
///
/// absent: `useDictation` (dictée vocale, moteur « device »/« alibaba », statuts et
/// erreurs) et `usePremiumToolGate` (portail premium du micro) : le bouton micro est
/// donc rendu à l'identique mais reste sans effet.
/// absent: tout ce qui dépend de ces états — styles `inputCardListening`,
/// `micButtonActive`, `statusListening`, `notice` et `error`, messages de statut
/// (« Finalisation de la transcription… », « Mise en forme de la transcription… »,
/// « Le téléphone transcrit en direct… appuie sur stop quand tu as terminé. »,
/// « Écoute en cours… toute la phrase apparaîtra après stop. », « Connexion au service
/// vocal… »), libellés d'accessibilité du micro (« Transcription haute précision
/// en cours », « Mise en forme mathématique en cours », « Arrêter la dictée ») et
/// message de permission « Autorise le micro et la reconnaissance vocale pour dicter
/// tes tâches. » — non portés, faute d'états correspondants.
private struct PremiumTaskCaptureCard: View {
    let onValidate: (String) -> Void

    @State private var transcript = ""

    /// `isPanelVisible` (l. 51-56) : les quatre autres termes (`isListening`,
    /// `isFormatting`, `voiceError`, `voiceNotice`) viennent de la dictée et valent
    /// donc toujours `false` ici.
    private var isPanelVisible: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canValidate: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isPanelVisible {
                panel
            }
            micButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12) // floatingContainer { bottom: 12 }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Theme.primaryLight)
                        .frame(width: 38, height: 38)
                    Image(systemName: "sparkles")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.primary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("AJOUT RAPIDE")
                        .font(.system(size: 8, weight: .black))
                        .kerning(1.1)
                        .foregroundStyle(Theme.ink) // colors.accent = #0A0D0C
                    Text("Dis tout ce que tu as à faire")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Une phrase par tâche, même en vrac. Pour bien la placer, indique si possible :")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 15)

            PremiumFlowLayout(spacing: 7) {
                requirement(icon: "flag", label: "Priorité", optional: false)     // flag-outline
                requirement(icon: "calendar", label: "Échéance", optional: false) // calendar-outline
                requirement(icon: "book", label: "Matière", optional: false)      // book-outline
                requirement(icon: "timer", label: "Durée", optional: true)        // timer-outline
            }
            .padding(.top, 11)

            // inputCard / input : le champ multiligne grandit à partir de 90 pt.
            TextField(
                "Ex. Demain, finir le DM de maths — urgent, environ 1 h. Puis apprendre le vocabulaire d’anglais pour vendredi, 30 min.",
                text: $transcript,
                axis: .vertical
            )
            .lineLimit(3...10)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.ink)
            .frame(minHeight: 90, alignment: .top)
            .padding(13)
            .frame(minHeight: 150, alignment: .top)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1.5)
            )
            .padding(.top, 15)
            .accessibilityLabel("Tâches à ajouter")

            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil") // Ionicons « create-outline »
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                Text("Relis et corrige toujours la transcription avant de valider.")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 10)

            Button(action: validate) {
                HStack(spacing: 8) {
                    Text("Organiser dans mon programme")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.surface) // colors.white
                    Image(systemName: "arrow.right") // Ionicons « arrow-forward »
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.surface)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(canValidate ? 1 : 0.35) // validateButtonDisabled
            }
            .buttonStyle(PremiumPressedButtonStyle(pressedOpacity: canValidate ? 0.75 : 1))
            .disabled(!canValidate)
            .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface) // colors.white
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    /// `micButton` : le seul élément toujours visible de la carte.
    private var micButton: some View {
        Button {
            // absent: `useDictation` / `usePremiumToolGate` — la dictée vocale n'est pas
            // portée, l'appui reste donc sans effet.
        } label: {
            Image(systemName: "mic.fill") // Ionicons « mic »
                .font(.system(size: 25))
                .foregroundStyle(Theme.surface)
                .frame(width: 54, height: 54)
                .background(Theme.primary)
                .clipShape(Circle())
                .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PremiumPressedButtonStyle(pressedOpacity: 0.75))
        .padding(.leading, 20) // micButton { marginLeft: 20 }
        .accessibilityLabel("Dicter mes tâches")
    }

    /// `Requirement` (l. 169-185).
    private func requirement(icon: String, label: String, optional: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.primary)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.primary)
            if optional {
                Text("optionnel")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(Theme.primaryLight)
        .clipShape(Capsule()) // radii.pill
    }

    /// `validate()` (l. 32-38).
    private func validate() {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        onValidate(clean)
        transcript = ""
    }
}

// MARK: - Outils de mise en page et de style

/// Disposition en lignes successives — équivalent du `flexWrap: 'wrap'` des rangées
/// « modalMetaRow » et « requirements ». `Layout` est disponible depuis iOS 16, la
/// cible minimale du portage.
private struct PremiumFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += (x > 0 ? spacing : 0) + size.width
            widest = max(widest, x)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxWidth, widest), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Effet d'appui de la source (`opacity: 0.7` / `0.75`).
private struct PremiumPressedButtonStyle: ButtonStyle {
    var pressedOpacity: Double = 0.7

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? pressedOpacity : 1)
    }
}
