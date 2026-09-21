//
//  AdmUsageModels.swift
//  Duello
//
//  Usage agrégé d'un compte, vu par l'administration.
//
//  Fichiers source Expo portés :
//    - src/admin/adminApi.ts         (`AdminUsageAnalytics`)
//    - src/admin/AdminUsersScreen.tsx (`areaLabels`, lecture de `usage`)
//    - src/admin/AdminAnalyticsScreen.tsx (`pageLabels`)
//
//  Décodage **tolérant**, comme `Models.swift` : le serveur peut omettre un
//  champ ou en changer le type sans casser l'écran.
//
//  Le journal d'événements (`events`) du serveur n'est lu par aucun écran
//  d'administration : il n'est pas décodé (il peut être volumineux, et le
//  porter sans consommateur serait de la complexité morte).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Page mesurée par l'analytique (`AdminUsageAnalytics['pageSeconds']`).
enum AdmUsagePage: String, CaseIterable, Identifiable {
    case training, journey, challenges, account

    var id: String { rawValue }

    /// `areaLabels` / `pageLabels` : libellés repris mot pour mot.
    var label: String {
        switch self {
        case .training: return "Entraînement"
        case .journey: return "Parcours"
        case .challenges: return "Défis"
        case .account: return "Compte"
        }
    }
}

/// Compteurs par page : secondes cumulées (`pageSeconds`) ou visites
/// (`pageVisits`). Les deux sont des nombres côté serveur.
struct AdmPageCounters: Decodable, Equatable {
    var training: Double = 0
    var journey: Double = 0
    var challenges: Double = 0
    var account: Double = 0

    enum CodingKeys: String, CodingKey {
        case training, journey, challenges, account
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        training = AdmPageCounters.number(c, .training)
        journey = AdmPageCounters.number(c, .journey)
        challenges = AdmPageCounters.number(c, .challenges)
        account = AdmPageCounters.number(c, .account)
    }

    /// Secondes cumulées sur une page.
    func seconds(for page: AdmUsagePage) -> Double {
        switch page {
        case .training: return training
        case .journey: return journey
        case .challenges: return challenges
        case .account: return account
        }
    }

    /// Visites d'une page, arrondies à l'entier.
    func count(for page: AdmUsagePage) -> Int {
        Int(seconds(for: page).rounded())
    }

    /// Somme des quatre pages.
    var total: Double { training + journey + challenges + account }

    private static func number(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double {
        if let value = try? c.decode(Double.self, forKey: key) { return value }
        if let value = try? c.decode(Int.self, forKey: key) { return Double(value) }
        return 0
    }
}

/// `actions` : compteurs d'actions réalisées (`exercise_completed`, …).
struct AdmUsageActions: Decodable, Equatable {
    var exerciseCompleted: Int = 0
    var challengeCompleted: Int = 0
    var courseUpdated: Int = 0
    var feedbackSent: Int = 0

    enum CodingKeys: String, CodingKey {
        case exerciseCompleted = "exercise_completed"
        case challengeCompleted = "challenge_completed"
        case courseUpdated = "course_updated"
        case feedbackSent = "feedback_sent"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exerciseCompleted = (try? c.decode(Int.self, forKey: .exerciseCompleted)) ?? 0
        challengeCompleted = (try? c.decode(Int.self, forKey: .challengeCompleted)) ?? 0
        courseUpdated = (try? c.decode(Int.self, forKey: .courseUpdated)) ?? 0
        feedbackSent = (try? c.decode(Int.self, forKey: .feedbackSent)) ?? 0
    }
}

/// Une journée d'usage (`daily[]`) : agrégats du jour et répartition par page.
struct AdmUsageDay: Decodable, Identifiable, Equatable {
    var date: String = ""
    var activeSeconds: Double = 0
    var sessions: Int = 0
    var pageSeconds: AdmPageCounters = AdmPageCounters()
    var pageVisits: AdmPageCounters = AdmPageCounters()

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date, activeSeconds, sessions, pageSeconds, pageVisits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
        activeSeconds = (try? c.decode(Double.self, forKey: .activeSeconds)) ?? 0
        sessions = (try? c.decode(Int.self, forKey: .sessions)) ?? 0
        pageSeconds = AdmUsageDay.counters(c, .pageSeconds)
        pageVisits = AdmUsageDay.counters(c, .pageVisits)
    }

    private static func counters(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> AdmPageCounters {
        guard let value = try? c.decodeIfPresent(AdmPageCounters.self, forKey: key) else {
            return AdmPageCounters()
        }
        return value ?? AdmPageCounters()
    }
}

/// `AdminUsageAnalytics` : usage agrégé d'un compte, borné côté serveur.
struct AdmUsageAnalytics: Decodable, Equatable {
    var version: Int = 0
    var firstSeenAt: String = ""
    var lastSeenAt: String = ""
    var sessionCount: Int = 0
    var totalActiveSeconds: Double = 0
    var pageSeconds: AdmPageCounters = AdmPageCounters()
    var pageVisits: AdmPageCounters = AdmPageCounters()
    var actions: AdmUsageActions = AdmUsageActions()
    var daily: [AdmUsageDay] = []

    enum CodingKeys: String, CodingKey {
        case version, firstSeenAt, lastSeenAt, sessionCount, totalActiveSeconds
        case pageSeconds, pageVisits, actions, daily
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 0
        firstSeenAt = (try? c.decode(String.self, forKey: .firstSeenAt)) ?? ""
        lastSeenAt = (try? c.decode(String.self, forKey: .lastSeenAt)) ?? ""
        sessionCount = (try? c.decode(Int.self, forKey: .sessionCount)) ?? 0
        totalActiveSeconds = (try? c.decode(Double.self, forKey: .totalActiveSeconds)) ?? 0
        pageSeconds = AdmUsageAnalytics.counters(c, .pageSeconds)
        pageVisits = AdmUsageAnalytics.counters(c, .pageVisits)
        actions = AdmUsageAnalytics.actions(c, .actions)
        daily = (try? c.decode([AdmUsageDay].self, forKey: .daily)) ?? []
    }

    private static func counters(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> AdmPageCounters {
        guard let value = try? c.decodeIfPresent(AdmPageCounters.self, forKey: key) else {
            return AdmPageCounters()
        }
        return value ?? AdmPageCounters()
    }

    private static func actions(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> AdmUsageActions {
        guard let value = try? c.decodeIfPresent(AdmUsageActions.self, forKey: key) else {
            return AdmUsageActions()
        }
        return value ?? AdmUsageActions()
    }
}
