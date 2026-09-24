//
//  AdmUsageAnalyticsJournal.swift
//  Duello
//
//  Journal d'usage consolidé (`UserUsageAnalytics`) : structure persistée,
//  décodage tolérant et normalisation (équivalent de `normalizeUsage`).
//
//  Fichier source Expo porté (règles reprises mot pour mot) :
//    - src/utils/usageAnalytics.ts
//        `UserUsageAnalytics` (`version: 3`, `firstSeenAt`, `lastSeenAt`,
//        `sessionCount`, `totalActiveSeconds`, `pageSeconds`, `pageVisits`,
//        `actions`, `daily`, `events`), `normalizeUsage`, `normalizeDay`,
//        `normalizeEvent`, `loadUsageAnalytics`, `emptyUsage`, les replis
//        hérités `screenSeconds` / `screenVisits` et le tri/rognage
//        (`RETAINED_DAYS`, `MAX_EVENTS`).
//
//  Notes (réduit / approché / limite assumée, 24/09/2026) :
//   - le décodage est tolérant champ par champ : une valeur illisible est
//     ramenée à zéro (ou écartée) plutôt que de faire échouer toute la lecture,
//     comme `normalizeUsage` ;
//   - le filtre d'âge des événements (`now - Date.parse(at)`) s'appuie sur
//     l'horloge au moment de la lecture, comme la source ;
//   - `version` est toujours réécrit à 3, comme `normalizeUsage`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// `UserUsageAnalytics` : journal d'usage consolidé, persisté sous
/// `AdmUsageRules.storageKey`.
struct AdmUsageJournal: Encodable, Equatable {
    var version: Int = 3
    var firstSeenAt: String
    var lastSeenAt: String
    var sessionCount: Int = 0
    var totalActiveSeconds: Double = 0
    var pageSeconds = AdmUsagePageCounters()
    var pageVisits = AdmUsagePageCounters()
    var actions = AdmUsageActionCounters()
    /// Fenêtre glissante suffisante pour les vues 7, 30 et 90 jours.
    var daily: [AdmUsageDayRecord] = []
    /// Événements métier bornés, sans réponse ni contenu de copie.
    var events: [AdmUsageEvent] = []

    init(
        version: Int = 3,
        firstSeenAt: String,
        lastSeenAt: String,
        sessionCount: Int = 0,
        totalActiveSeconds: Double = 0,
        pageSeconds: AdmUsagePageCounters = AdmUsagePageCounters(),
        pageVisits: AdmUsagePageCounters = AdmUsagePageCounters(),
        actions: AdmUsageActionCounters = AdmUsageActionCounters(),
        daily: [AdmUsageDayRecord] = [],
        events: [AdmUsageEvent] = []
    ) {
        self.version = version
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.sessionCount = sessionCount
        self.totalActiveSeconds = totalActiveSeconds
        self.pageSeconds = pageSeconds
        self.pageVisits = pageVisits
        self.actions = actions
        self.daily = daily
        self.events = events
    }

    /// `emptyUsage` : journal vierge horodaté.
    static func empty(now: Double) -> AdmUsageJournal {
        let timestamp = AdmUsageRules.iso(now)
        return AdmUsageJournal(firstSeenAt: timestamp, lastSeenAt: timestamp)
    }

    /// `appendEvent` : ajoute un événement et ne garde que les `MAX_EVENTS` plus récents.
    static func appendingEvent(_ events: [AdmUsageEvent], _ event: AdmUsageEvent) -> [AdmUsageEvent] {
        Array((events + [event]).suffix(AdmUsageRules.maxEvents))
    }

    /// Sérialisation JSON (identique à `JSON.stringify` du journal normalisé).
    func encoded() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `loadUsageAnalytics` : un journal illisible repart à vide (jamais d'erreur).
    static func decode(_ raw: String?) -> AdmUsageJournal {
        let now = Date().timeIntervalSince1970 * 1000
        guard let raw,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(AdmUsageJournalRaw.self, from: data)
        else { return empty(now: now) }
        return normalize(decoded, now: now)
    }

    /// `normalizeUsage` à partir de la forme brute (lecture disque / serveur).
    static func normalize(_ raw: AdmUsageJournalRaw, now: Double) -> AdmUsageJournal {
        let fallback = empty(now: now)
        let journal = AdmUsageJournal(
            firstSeenAt: raw.firstSeenAt ?? fallback.firstSeenAt,
            lastSeenAt: raw.lastSeenAt ?? fallback.lastSeenAt,
            sessionCount: AdmUsageRules.nonNegativeInteger(raw.sessionCount),
            totalActiveSeconds: AdmUsageRules.finitePositive(raw.totalActiveSeconds),
            pageSeconds: pageCounters(raw.pageSeconds, legacy: raw.screenSeconds),
            pageVisits: pageCounters(raw.pageVisits, legacy: raw.screenVisits).floored(),
            actions: actionCounters(raw.actions),
            daily: (raw.daily ?? []).compactMap(AdmUsageDayRecord.init(raw:)),
            events: (raw.events ?? []).compactMap { AdmUsageEvent(raw: $0, now: now) }
        )
        return normalize(journal, now: now)
    }

    /// `normalizeUsage` appliqué à un journal déjà typé (après une mutation).
    static func normalize(_ journal: AdmUsageJournal, now: Double) -> AdmUsageJournal {
        var next = journal
        next.version = 3
        next.sessionCount = max(0, journal.sessionCount)
        next.totalActiveSeconds = AdmUsageRules.finitePositive(journal.totalActiveSeconds)
        next.pageSeconds = journal.pageSeconds.clamped()
        next.pageVisits = journal.pageVisits.floored()
        next.actions = journal.actions.clamped()
        next.daily = Array(
            journal.daily.sorted { $0.date < $1.date }.suffix(AdmUsageRules.retainedDays)
        )
        next.events = Array(
            journal.events
                .compactMap { AdmUsageEvent.sanitized($0, now: now) }
                .sorted { $0.at < $1.at }
                .suffix(AdmUsageRules.maxEvents)
        )
        return next
    }

    /// `pages(value, legacy)` : compteurs de pages, avec repli des anciennes clés
    /// `screenSeconds` / `screenVisits` (le parcours n'existait pas alors).
    static func pageCounters(
        _ raw: AdmUsageJournalRaw.Counters?,
        legacy: AdmUsageJournalRaw.Counters? = nil
    ) -> AdmUsagePageCounters {
        AdmUsagePageCounters(
            training: AdmUsageRules.finitePositive(raw?.training ?? legacy?.training),
            journey: AdmUsageRules.finitePositive(raw?.journey),
            challenges: AdmUsageRules.finitePositive(raw?.challenges ?? legacy?.challenges),
            account: AdmUsageRules.finitePositive(raw?.account ?? legacy?.account)
        )
    }

    /// `actions(value)` : compteurs d'actions ramenés à des entiers non négatifs.
    static func actionCounters(_ raw: AdmUsageJournalRaw.Actions?) -> AdmUsageActionCounters {
        var counters = AdmUsageActionCounters()
        counters.exerciseCompleted = AdmUsageRules.nonNegativeInteger(raw?.exerciseCompleted)
        counters.challengeCompleted = AdmUsageRules.nonNegativeInteger(raw?.challengeCompleted)
        counters.courseUpdated = AdmUsageRules.nonNegativeInteger(raw?.courseUpdated)
        counters.feedbackSent = AdmUsageRules.nonNegativeInteger(raw?.feedbackSent)
        return counters
    }
}

// MARK: - Forme brute tolérante

/// Vue brute de `UserUsageAnalytics` : tous les champs optionnels, décodés sans
/// jamais lever, pour alimenter `AdmUsageJournal.normalize(_:now:)`.
struct AdmUsageJournalRaw: Decodable {
    /// `pageSeconds` / `pageVisits` bruts.
    struct Counters: Decodable {
        var training: Double?
        var journey: Double?
        var challenges: Double?
        var account: Double?

        enum CodingKeys: String, CodingKey { case training, journey, challenges, account }

        init(from decoder: Decoder) throws {
            guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
            training = (try? c.decodeIfPresent(Double.self, forKey: .training)) ?? nil
            journey = (try? c.decodeIfPresent(Double.self, forKey: .journey)) ?? nil
            challenges = (try? c.decodeIfPresent(Double.self, forKey: .challenges)) ?? nil
            account = (try? c.decodeIfPresent(Double.self, forKey: .account)) ?? nil
        }
    }

    /// `actions` brut.
    struct Actions: Decodable {
        var exerciseCompleted: Double?
        var challengeCompleted: Double?
        var courseUpdated: Double?
        var feedbackSent: Double?

        enum CodingKeys: String, CodingKey {
            case exerciseCompleted = "exercise_completed"
            case challengeCompleted = "challenge_completed"
            case courseUpdated = "course_updated"
            case feedbackSent = "feedback_sent"
        }

        init(from decoder: Decoder) throws {
            guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
            exerciseCompleted = (try? c.decodeIfPresent(Double.self, forKey: .exerciseCompleted)) ?? nil
            challengeCompleted = (try? c.decodeIfPresent(Double.self, forKey: .challengeCompleted)) ?? nil
            courseUpdated = (try? c.decodeIfPresent(Double.self, forKey: .courseUpdated)) ?? nil
            feedbackSent = (try? c.decodeIfPresent(Double.self, forKey: .feedbackSent)) ?? nil
        }
    }

    /// `daily[]` brut.
    struct Day: Decodable {
        var date: String?
        var activeSeconds: Double?
        var sessions: Double?
        var pageSeconds: Counters?
        var pageVisits: Counters?
        var actions: Actions?

        enum CodingKeys: String, CodingKey {
            case date, activeSeconds, sessions, pageSeconds, pageVisits, actions
        }

        init(from decoder: Decoder) throws {
            guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
            date = (try? c.decodeIfPresent(String.self, forKey: .date)) ?? nil
            activeSeconds = (try? c.decodeIfPresent(Double.self, forKey: .activeSeconds)) ?? nil
            sessions = (try? c.decodeIfPresent(Double.self, forKey: .sessions)) ?? nil
            pageSeconds = (try? c.decodeIfPresent(Counters.self, forKey: .pageSeconds)) ?? nil
            pageVisits = (try? c.decodeIfPresent(Counters.self, forKey: .pageVisits)) ?? nil
            actions = (try? c.decodeIfPresent(Actions.self, forKey: .actions)) ?? nil
        }
    }

    /// `events[]` brut.
    struct Event: Decodable {
        var id: String?
        var at: String?
        var kind: String?
        var page: String?
        var label: String?
        var section: String?
        var exerciseId: String?
        var exerciseTitle: String?
        var subject: String?
        var outcome: String?
        var durationSeconds: Double?

        enum CodingKeys: String, CodingKey {
            case id, at, kind, page, label, section, exerciseId, exerciseTitle
            case subject, outcome, durationSeconds
        }

        init(from decoder: Decoder) throws {
            guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
            id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? nil
            at = (try? c.decodeIfPresent(String.self, forKey: .at)) ?? nil
            kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? nil
            page = (try? c.decodeIfPresent(String.self, forKey: .page)) ?? nil
            label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? nil
            section = (try? c.decodeIfPresent(String.self, forKey: .section)) ?? nil
            exerciseId = (try? c.decodeIfPresent(String.self, forKey: .exerciseId)) ?? nil
            exerciseTitle = (try? c.decodeIfPresent(String.self, forKey: .exerciseTitle)) ?? nil
            subject = (try? c.decodeIfPresent(String.self, forKey: .subject)) ?? nil
            outcome = (try? c.decodeIfPresent(String.self, forKey: .outcome)) ?? nil
            durationSeconds = (try? c.decodeIfPresent(Double.self, forKey: .durationSeconds)) ?? nil
        }
    }

    var version: Int?
    var firstSeenAt: String?
    var lastSeenAt: String?
    var sessionCount: Double?
    var totalActiveSeconds: Double?
    var pageSeconds: Counters?
    var pageVisits: Counters?
    var actions: Actions?
    /// Clés héritées (avant l'ajout du parcours).
    var screenSeconds: Counters?
    var screenVisits: Counters?
    var daily: [Day]?
    var events: [Event]?

    enum CodingKeys: String, CodingKey {
        case version, firstSeenAt, lastSeenAt, sessionCount, totalActiveSeconds
        case pageSeconds, pageVisits, actions, screenSeconds, screenVisits, daily, events
    }

    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? nil
        firstSeenAt = (try? c.decodeIfPresent(String.self, forKey: .firstSeenAt)) ?? nil
        lastSeenAt = (try? c.decodeIfPresent(String.self, forKey: .lastSeenAt)) ?? nil
        sessionCount = (try? c.decodeIfPresent(Double.self, forKey: .sessionCount)) ?? nil
        totalActiveSeconds = (try? c.decodeIfPresent(Double.self, forKey: .totalActiveSeconds)) ?? nil
        pageSeconds = (try? c.decodeIfPresent(Counters.self, forKey: .pageSeconds)) ?? nil
        pageVisits = (try? c.decodeIfPresent(Counters.self, forKey: .pageVisits)) ?? nil
        actions = (try? c.decodeIfPresent(Actions.self, forKey: .actions)) ?? nil
        screenSeconds = (try? c.decodeIfPresent(Counters.self, forKey: .screenSeconds)) ?? nil
        screenVisits = (try? c.decodeIfPresent(Counters.self, forKey: .screenVisits)) ?? nil
        daily = (try? c.decodeIfPresent([Day].self, forKey: .daily)) ?? nil
        events = (try? c.decodeIfPresent([Event].self, forKey: .events)) ?? nil
    }
}

// MARK: - Construction typée depuis la forme brute

extension AdmUsageDayRecord {
    /// `normalizeDay` : `nil` quand la date est absente ou mal formée.
    init?(raw: AdmUsageJournalRaw.Day) {
        guard let date = raw.date,
              date.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil
        else { return nil }
        self.init(date: date)
        activeSeconds = AdmUsageRules.finitePositive(raw.activeSeconds)
        sessions = AdmUsageRules.nonNegativeInteger(raw.sessions)
        pageSeconds = AdmUsageJournal.pageCounters(raw.pageSeconds)
        pageVisits = AdmUsageJournal.pageCounters(raw.pageVisits).floored()
        actions = AdmUsageJournal.actionCounters(raw.actions)
    }
}

extension AdmUsageEvent {
    /// `normalizeEvent` : `nil` si la nature, la page, l'instant ou le libellé
    /// manquent, ou si l'événement est hors fenêtre de rétention.
    init?(raw: AdmUsageJournalRaw.Event, now: Double) {
        guard let kind = raw.kind.flatMap(AdmUsageEventKind.init(rawValue:)),
              let page = raw.page.flatMap(AdmUsagePage.init(rawValue:))
        else { return nil }
        let at = raw.at ?? ""
        let millis = AdmUsageRules.parseMillis(at)
        let window = Double(AdmUsageRules.retainedDays) * AdmUsageRules.millisecondsPerDay
        let label = AdmUsageRules.boundedText(raw.label, maximum: 120)
        guard millis > 0, now - millis <= window, !label.isEmpty else { return nil }
        let identifier = AdmUsageRules.boundedText(raw.id, maximum: 100)
        self.init(
            id: identifier.isEmpty ? String(Int64(millis)) : identifier,
            at: at,
            kind: kind,
            page: page,
            label: label,
            section: AdmUsageEvent.optional(raw.section, maximum: 120),
            exerciseId: AdmUsageEvent.optional(raw.exerciseId, maximum: 240),
            exerciseTitle: AdmUsageEvent.optional(raw.exerciseTitle, maximum: 180),
            subject: AdmUsageEvent.optional(raw.subject, maximum: 120),
            outcome: raw.outcome.flatMap(AdmUsageEventOutcome.init(rawValue:)),
            durationSeconds: AdmUsageEvent.duration(raw.durationSeconds)
        )
    }
}
