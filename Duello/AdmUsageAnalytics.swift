//
//  AdmUsageAnalytics.swift
//  Duello
//
//  Journal d'usage local d'un compte : pages, compteurs et libellés, persistés
//  sous `prepapp-usage-analytics:v1`. Les six écritures vivent dans
//  `AdmUsageAnalyticsStore.swift` (+ `+Writes`) ; la normalisation tolérante et
//  le décodage dans `AdmUsageAnalyticsJournal.swift`.
//
//  Fichier source Expo porté (règles, libellés et clés repris mot pour mot) :
//    - src/utils/usageAnalytics.ts
//        `UserUsagePage`, `UserUsageAction`, `usagePageForScreen`,
//        `UserUsageEventKind`, `boundedText`, `finitePositive`,
//        `nonNegativeInteger`, `localDayKey`, `eventId`, `USAGE_STORAGE_KEY`
//        (`ACCOUNT_STORAGE_KEYS.usageAnalytics`), `RETAINED_DAYS` (120),
//        `MAX_EVENTS` (2 000).
//
//  Notes (réduit / approché / limite assumée, 24/09/2026) :
//   - `AdmUsagePage` est déjà défini dans `AdmUsageModels.swift` : on réutilise
//     ses quatre pages et on ne lui ajoute que `Codable` (extension dans CE
//     fichier, aucun `.swift` existant modifié).
//   - `boundedText` borne par graphèmes (`prefix`) là où la source coupe par
//     unités UTF-16 : identique pour les libellés latins, sans intérêt ici.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

// MARK: - Pages et libellés

/// `UserUsagePage` (`AdminUsageAnalytics['pageSeconds']`) — déjà défini comme
/// `AdmUsagePage` ; cette extension ne fait qu'ajouter la conformité `Codable`
/// nécessaire à la persistance locale.
extension AdmUsagePage: Codable {}

/// `UserUsageAction` : actions métier comptées dans `actions`.
enum AdmUsageActionKind: String, Codable, CaseIterable, Identifiable {
    case exerciseCompleted = "exercise_completed"
    case challengeCompleted = "challenge_completed"
    case courseUpdated = "course_updated"
    case feedbackSent = "feedback_sent"

    var id: String { rawValue }
}

/// `UserUsageEventKind` : nature d'un événement d'usage.
enum AdmUsageEventKind: String, Codable, CaseIterable {
    case pageView = "page_view"
    case buttonClick = "button_click"
    case action
    case exercise
}

/// `UserUsageEvent['outcome']`.
enum AdmUsageEventOutcome: String, Codable, CaseIterable {
    case opened
    case fail
    case partial
    case success
}

/// `AppScreenKey` réduit aux écrans dont la page d'usage diffère. Les écrans
/// sans page propre (accueil, etc.) comptent dans « Entraînement ».
enum AdmUsageScreenKey: String, Codable, CaseIterable {
    case home
    case training
    case program
    case journey
    case challenges
    case account
    case other

    /// `usagePageForScreen` : programme → parcours, défis → défis, compte →
    /// compte, tout le reste → entraînement.
    var usagePage: AdmUsagePage {
        switch self {
        case .program: return .journey
        case .challenges: return .challenges
        case .account: return .account
        default: return .training
        }
    }
}

// MARK: - Règles et primitives

/// Constantes et primitives du journal (`usageAnalytics.ts`).
enum AdmUsageRules {
    /// `USAGE_STORAGE_KEY` (`ACCOUNT_STORAGE_KEYS.usageAnalytics`).
    static let storageKey = "prepapp-usage-analytics:v1"

    /// `RETAINED_DAYS` : fenêtre glissante suffisante pour les vues 7/30/90 j.
    static let retainedDays = 120

    /// `MAX_EVENTS` : nombre maximal d'événements conservés.
    static let maxEvents = 2_000

    /// `86_400_000` : millisecondes d'un jour, pour le filtre d'âge des événements.
    static let millisecondsPerDay: Double = 86_400_000

    /// `usagePageForScreen`.
    static func usagePageForScreen(_ screen: AdmUsageScreenKey) -> AdmUsagePage {
        screen.usagePage
    }

    /// `boundedText` : texte rogné à `maximum` caractères, jamais `nil`.
    static func boundedText(_ value: String?, maximum: Int) -> String {
        guard let value else { return "" }
        return String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximum))
    }

    /// `finitePositive` : nombre fini strictement positif, sinon 0.
    static func finitePositive(_ value: Double?) -> Double {
        guard let value, value.isFinite, value > 0 else { return 0 }
        return value
    }

    /// `nonNegativeInteger` : entier non négatif (`Math.floor` d'un positif fini).
    static func nonNegativeInteger(_ value: Double?) -> Int {
        Int(finitePositive(value).rounded(.down))
    }

    /// `localDayKey` : jour local `AAAA-MM-JJ`.
    static func localDayKey(_ now: Double) -> String {
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: Date(timeIntervalSince1970: now / 1000)
        )
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// `new Date(now).toISOString()` : instant ISO-8601 en UTC, avec millisecondes.
    static func iso(_ now: Double) -> String {
        ISO8601DateFormatter.flexible.string(from: Date(timeIntervalSince1970: now / 1000))
    }

    /// `Date.parse` : millisecondes depuis l'époque, ou 0 si illisible.
    static func parseMillis(_ value: String) -> Double {
        guard let date = ISO8601DateFormatter.date(fromISO: value) else { return 0 }
        return date.timeIntervalSince1970 * 1000
    }

    /// `eventId` : horodatage + suffixe base 36 aléatoire de huit caractères.
    static func eventId(_ now: Double) -> String {
        "\(Int64(now))-\(randomBase36(length: 8))"
    }

    /// `Math.random().toString(36).slice(2, 10)` : suffixe base 36 aléatoire.
    static func randomBase36(length: Int) -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        return String((0..<length).map { _ in alphabet.randomElement() ?? "0" })
    }
}
