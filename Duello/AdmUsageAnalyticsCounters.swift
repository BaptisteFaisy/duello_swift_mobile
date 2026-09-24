//
//  AdmUsageAnalyticsCounters.swift
//  Duello
//
//  Compteurs, journée et événement du journal d'usage local.
//
//  Fichier source Expo porté (champs et règles repris mot pour mot) :
//    - src/utils/usageAnalytics.ts
//        `UserUsageDay` (`activeSeconds`, `sessions`, `pageSeconds`,
//        `pageVisits`, `actions`), `UserUsageEvent` (`id`, `at`, `kind`,
//        `page`, `label`, `section?`, `exerciseId?`, `exerciseTitle?`,
//        `subject?`, `outcome?`, `durationSeconds?`), `emptyDay`, `appendEvent`
//        (`MAX_EVENTS`), `pages`, `visits`, `actions`, `normalizeEvent`.
//
//  Notes (réduit / approché / limite assumée, 24/09/2026) :
//   - `pageVisits` est stocké comme les secondes (nombres) ; les visites sont
//     lues entières par `floored()`, comme `visits()` de la source.
//   - `durationSeconds` est conservé borné à 86 400 s (24 h), comme la source.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

// MARK: - Compteurs

/// `pageSeconds` / `pageVisits` : compteurs par page, décodage tolérant.
struct AdmUsagePageCounters: Codable, Equatable {
    var training: Double = 0
    var journey: Double = 0
    var challenges: Double = 0
    var account: Double = 0

    enum CodingKeys: String, CodingKey { case training, journey, challenges, account }

    init() {}

    init(training: Double, journey: Double, challenges: Double, account: Double) {
        self.training = training
        self.journey = journey
        self.challenges = challenges
        self.account = account
    }

    /// Décodage tolérant : un champ absent ou illisible vaut 0 (`finitePositive`).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        training = AdmUsageRules.finitePositive((try? c.decodeIfPresent(Double.self, forKey: .training)) ?? nil)
        journey = AdmUsageRules.finitePositive((try? c.decodeIfPresent(Double.self, forKey: .journey)) ?? nil)
        challenges = AdmUsageRules.finitePositive((try? c.decodeIfPresent(Double.self, forKey: .challenges)) ?? nil)
        account = AdmUsageRules.finitePositive((try? c.decodeIfPresent(Double.self, forKey: .account)) ?? nil)
    }

    /// Accès par page (`pages`).
    subscript(page: AdmUsagePage) -> Double {
        get {
            switch page {
            case .training: return training
            case .journey: return journey
            case .challenges: return challenges
            case .account: return account
            }
        }
        set {
            switch page {
            case .training: training = newValue
            case .journey: journey = newValue
            case .challenges: challenges = newValue
            case .account: account = newValue
            }
        }
    }

    func seconds(for page: AdmUsagePage) -> Double { self[page] }

    var total: Double { training + journey + challenges + account }

    /// `pages` : chaque page ramenée à un nombre positif fini.
    func clamped() -> AdmUsagePageCounters {
        AdmUsagePageCounters(
            training: AdmUsageRules.finitePositive(training),
            journey: AdmUsageRules.finitePositive(journey),
            challenges: AdmUsageRules.finitePositive(challenges),
            account: AdmUsageRules.finitePositive(account)
        )
    }

    /// `visits` : chaque page ramenée à un entier non négatif.
    func floored() -> AdmUsagePageCounters {
        AdmUsagePageCounters(
            training: Double(AdmUsageRules.nonNegativeInteger(training)),
            journey: Double(AdmUsageRules.nonNegativeInteger(journey)),
            challenges: Double(AdmUsageRules.nonNegativeInteger(challenges)),
            account: Double(AdmUsageRules.nonNegativeInteger(account))
        )
    }
}

/// `actions` : compteurs d'actions réalisées.
struct AdmUsageActionCounters: Codable, Equatable {
    var exerciseCompleted = 0
    var challengeCompleted = 0
    var courseUpdated = 0
    var feedbackSent = 0

    enum CodingKeys: String, CodingKey {
        case exerciseCompleted = "exercise_completed"
        case challengeCompleted = "challenge_completed"
        case courseUpdated = "course_updated"
        case feedbackSent = "feedback_sent"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exerciseCompleted = AdmUsageRules.nonNegativeInteger((try? c.decodeIfPresent(Double.self, forKey: .exerciseCompleted)) ?? nil)
        challengeCompleted = AdmUsageRules.nonNegativeInteger((try? c.decodeIfPresent(Double.self, forKey: .challengeCompleted)) ?? nil)
        courseUpdated = AdmUsageRules.nonNegativeInteger((try? c.decodeIfPresent(Double.self, forKey: .courseUpdated)) ?? nil)
        feedbackSent = AdmUsageRules.nonNegativeInteger((try? c.decodeIfPresent(Double.self, forKey: .feedbackSent)) ?? nil)
    }

    /// Accès par action (`actions`).
    subscript(action: AdmUsageActionKind) -> Int {
        get {
            switch action {
            case .exerciseCompleted: return exerciseCompleted
            case .challengeCompleted: return challengeCompleted
            case .courseUpdated: return courseUpdated
            case .feedbackSent: return feedbackSent
            }
        }
        set {
            switch action {
            case .exerciseCompleted: exerciseCompleted = newValue
            case .challengeCompleted: challengeCompleted = newValue
            case .courseUpdated: courseUpdated = newValue
            case .feedbackSent: feedbackSent = newValue
            }
        }
    }

    /// `actions` : chaque compteur ramené à un entier non négatif.
    func clamped() -> AdmUsageActionCounters {
        var next = self
        for action in AdmUsageActionKind.allCases {
            next[action] = AdmUsageRules.nonNegativeInteger(Double(self[action]))
        }
        return next
    }
}

// MARK: - Journée

/// `UserUsageDay` : agrégats d'une journée.
struct AdmUsageDayRecord: Encodable, Equatable, Identifiable {
    var date: String
    var activeSeconds: Double = 0
    var sessions: Int = 0
    var pageSeconds = AdmUsagePageCounters()
    var pageVisits = AdmUsagePageCounters()
    var actions = AdmUsageActionCounters()

    var id: String { date }

    init(date: String) { self.date = date }

    /// `emptyDay`.
    static func empty(date: String) -> AdmUsageDayRecord { AdmUsageDayRecord(date: date) }
}

// MARK: - Événement

/// `UserUsageEvent` : événement métier borné, sans réponse ni brouillon.
struct AdmUsageEvent: Encodable, Equatable, Identifiable {
    var id: String
    var at: String
    var kind: AdmUsageEventKind
    var page: AdmUsagePage
    var label: String
    var section: String?
    var exerciseId: String?
    var exerciseTitle: String?
    var subject: String?
    var outcome: AdmUsageEventOutcome?
    var durationSeconds: Double?

    init(
        id: String,
        at: String,
        kind: AdmUsageEventKind,
        page: AdmUsagePage,
        label: String,
        section: String? = nil,
        exerciseId: String? = nil,
        exerciseTitle: String? = nil,
        subject: String? = nil,
        outcome: AdmUsageEventOutcome? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.at = at
        self.kind = kind
        self.page = page
        self.label = label
        self.section = section
        self.exerciseId = exerciseId
        self.exerciseTitle = exerciseTitle
        self.subject = subject
        self.outcome = outcome
        self.durationSeconds = durationSeconds
    }

    /// Construit un événement horodaté (`appendEvent` de la source).
    static func make(
        kind: AdmUsageEventKind,
        page: AdmUsagePage,
        label: String,
        section: String? = nil,
        exerciseId: String? = nil,
        exerciseTitle: String? = nil,
        subject: String? = nil,
        outcome: AdmUsageEventOutcome? = nil,
        durationSeconds: Double? = nil,
        now: Double
    ) -> AdmUsageEvent {
        AdmUsageEvent(
            id: AdmUsageRules.eventId(now),
            at: AdmUsageRules.iso(now),
            kind: kind,
            page: page,
            label: label,
            section: section,
            exerciseId: exerciseId,
            exerciseTitle: exerciseTitle,
            subject: subject,
            outcome: outcome,
            durationSeconds: durationSeconds
        )
    }

    /// `normalizeEvent` (partie commune) : un événement hors fenêtre ou sans
    /// libellé est écarté.
    static func sanitized(_ event: AdmUsageEvent, now: Double) -> AdmUsageEvent? {
        let millis = AdmUsageRules.parseMillis(event.at)
        let window = Double(AdmUsageRules.retainedDays) * AdmUsageRules.millisecondsPerDay
        guard millis > 0, now - millis <= window, !event.label.isEmpty else { return nil }
        var next = event
        if next.id.isEmpty { next.id = String(Int64(millis)) }
        return next
    }

    /// `boundedText(candidate.x, max)` renvoyant un champ optionnel omis si vide.
    static func optional(_ value: String?, maximum: Int) -> String? {
        let text = AdmUsageRules.boundedText(value, maximum: maximum)
        return text.isEmpty ? nil : text
    }

    /// `durationSeconds` : conservé s'il est positif, borné à 86 400 s.
    static func duration(_ value: Double?) -> Double? {
        let positive = AdmUsageRules.finitePositive(value)
        return positive > 0 ? min(86_400, positive) : nil
    }
}
