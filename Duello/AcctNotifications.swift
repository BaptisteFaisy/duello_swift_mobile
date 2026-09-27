//
//  AcctNotifications.swift
//  Duello
//
//  Notifications du compte : modèle, magasin local et lecture distante.
//
//  Fichiers source Expo portés :
//    - `src/utils/notifications.ts` (`AccountNotification`, `loadNotifications`,
//      `saveNotifications`, `countUnread`, `markAllRead`,
//      `mergeRemoteNotifications`, `formatTimeAgo`) ;
//    - `src/utils/socialApi.ts` (`fetchSocialNotifications` :
//      `GET /notifications?userId=member-…`, corps `{ notifications: […] }`).
//
//  V1 (26/09/2026, écart 20#2) : la feuille affichait toujours l’état vide ;
//  elle rend désormais la vraie liste (`AccountScreen.tsx:2258-2360`). Les
//  likes simulés de la source (`nextIncomingLike`, « pas encore de serveur »)
//  ne sont **pas** portés : la liste vient du stockage local et du réseau,
//  jamais d’une génération locale.
//
//  Cible : iOS 16.
//
import Foundation
import Combine

/// `kind` d’une notification, valeurs exactes de la source. `kind` absent des
/// anciens stockages = like reçu (`performance-like`).
enum AcctNotificationKind: String, Codable, Equatable {
    case performanceLike = "performance-like"
    case newFollower = "new-follower"
    case profileView = "profile-view"
    case challengeUnavailable = "challenge-unavailable"
    case annaleCorrectionReady = "annale-correction-ready"
}

/// Une notification du compte (`AccountNotification`), les cinq variantes en
/// une seule forme codable, équivalente aux champs lus par l’écran.
struct AcctNotification: Identifiable, Codable, Equatable {
    var id: String
    var kind: AcctNotificationKind
    var actorId: String
    var actorName: String
    var performanceLabel: String
    var performanceText: String
    var subject: String
    var chapterNames: [String]
    var durationMinutes: Int
    var jobId: String
    var itemId: String
    var title: String
    var score: Double
    var createdAt: String
    var read: Bool

    /// Clés de stockage, déclarées explicitement : le `init(from:)` personnalisé
    /// supprime la synthèse de `CodingKeys`.
    enum CodingKeys: String, CodingKey {
        case id, kind, actorId, actorName, performanceLabel, performanceText
        case subject, chapterNames, durationMinutes, jobId, itemId, title
        case score, createdAt, read
    }

    /// Construction directe (le `init(from:)` personnalisé supprime
    /// l’initialiseur membre à membre synthétisé).
    init(
        id: String, kind: AcctNotificationKind,
        actorId: String, actorName: String,
        performanceLabel: String, performanceText: String,
        subject: String, chapterNames: [String], durationMinutes: Int,
        jobId: String, itemId: String, title: String, score: Double,
        createdAt: String, read: Bool
    ) {
        self.id = id
        self.kind = kind
        self.actorId = actorId
        self.actorName = actorName
        self.performanceLabel = performanceLabel
        self.performanceText = performanceText
        self.subject = subject
        self.chapterNames = chapterNames
        self.durationMinutes = durationMinutes
        self.jobId = jobId
        self.itemId = itemId
        self.title = title
        self.score = score
        self.createdAt = createdAt
        self.read = read
    }

    /// Décodage tolérant aux anciens stockages : champs absents et `kind`
    /// manquant (like reçu).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.str(c, .id)
        kind = (try? c.decode(AcctNotificationKind.self, forKey: .kind)) ?? .performanceLike
        actorId = Self.str(c, .actorId)
        actorName = Self.str(c, .actorName)
        performanceLabel = Self.str(c, .performanceLabel)
        performanceText = Self.str(c, .performanceText)
        subject = Self.str(c, .subject)
        chapterNames = (try? c.decode([String].self, forKey: .chapterNames)) ?? []
        durationMinutes = (try? c.decode(Int.self, forKey: .durationMinutes)) ?? 0
        jobId = Self.str(c, .jobId)
        itemId = Self.str(c, .itemId)
        title = Self.str(c, .title)
        score = (try? c.decode(Double.self, forKey: .score)) ?? 0
        createdAt = Self.str(c, .createdAt)
        read = (try? c.decode(Bool.self, forKey: .read)) ?? false
    }

    private static func str(
        _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> String {
        (try? c.decode(String.self, forKey: key)) ?? ""
    }
}

/// Événement distant (`RemoteNotificationLike`) : identification de l’acteur
/// et, pour un défi, le contexte de l’invitation.
struct AcctRemoteNotification: Decodable {
    var id: String = ""
    var kind: String = ""
    var actor: AcctRemoteActor = AcctRemoteActor()
    var createdAt: String = ""
    var challenge: AcctRemoteChallenge?

    /// Clés explicites : `init(from:)` personnalisé supprime leur synthèse.
    enum CodingKeys: String, CodingKey {
        case id, kind, actor, createdAt, challenge
    }

    /// Décodage tolérant : un événement partiel reste lisible.
    init(from decoder: Decoder) throws {
        let c = (try? decoder.container(keyedBy: CodingKeys.self))
        id = (try? c?.decode(String.self, forKey: .id)) ?? ""
        kind = (try? c?.decode(String.self, forKey: .kind)) ?? ""
        actor = (try? c?.decode(AcctRemoteActor.self, forKey: .actor)) ?? AcctRemoteActor()
        createdAt = (try? c?.decode(String.self, forKey: .createdAt)) ?? ""
        challenge = try? c?.decodeIfPresent(AcctRemoteChallenge.self, forKey: .challenge)
    }

    init() {}
}

/// Acteur distant : identifiant et nom publié (`actor`).
struct AcctRemoteActor: Decodable {
    var id: String = ""
    var displayName: String = ""

    /// Clés explicites : `init(from:)` personnalisé supprime leur synthèse.
    enum CodingKeys: String, CodingKey {
        case id, displayName
    }

    init(from decoder: Decoder) throws {
        let c = (try? decoder.container(keyedBy: CodingKeys.self))
        id = (try? c?.decode(String.self, forKey: .id)) ?? ""
        displayName = (try? c?.decode(String.self, forKey: .displayName)) ?? ""
    }

    init() {}
}

/// Contexte d’une invitation reçue en défi (`challenge`).
struct AcctRemoteChallenge: Decodable {
    var subject: String = ""
    var chapterNames: [String] = []
    var durationMinutes: Int = 0
}

/// Fonctions du module `utils/notifications.ts` et de sa lecture réseau.
enum AcctNotifications {
    /// `MAX_NOTIFICATIONS` : au-delà, les plus anciennes sont oubliées.
    static let maxNotifications = 30

    /// `loadNotifications` : lit la liste du compte, vide si illisible.
    static func load(accountId: String) -> [AcctNotification] {
        guard let raw = UserDefaults.standard.string(forKey: key(accountId: accountId)),
              let data = raw.data(using: .utf8),
              let list = try? JSONDecoder().decode([AcctNotification].self, from: data) else {
            return []
        }
        return list
    }

    /// `saveNotifications` : écrit les 30 plus récentes du compte.
    static func save(_ list: [AcctNotification], accountId: String) {
        let trimmed = Array(list.prefix(maxNotifications))
        guard let data = try? JSONEncoder().encode(trimmed),
              let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: key(accountId: accountId))
    }

    /// `countUnread` : nombre de non lues.
    static func countUnread(_ list: [AcctNotification]) -> Int {
        list.filter { !$0.read }.count
    }

    /// `markAllRead` : tout marquer lu.
    static func markAllRead(_ list: [AcctNotification]) -> [AcctNotification] {
        list.map { n in
            guard !n.read else { return n }
            var c = n
            c.read = true
            return c
        }
    }

    /// `mergeRemoteNotifications` : ajoute les événements distants sans réouvrir
    /// ceux déjà lus. Les anciennes demandes de connexion restent ignorées.
    static func mergeRemoteNotifications(
        _ existing: [AcctNotification],
        remote: [AcctRemoteNotification]
    ) -> [AcctNotification] {
        let known = Set(existing.map { $0.id })
        var received: [AcctNotification] = []
        for event in remote where !known.contains(event.id) && !event.id.isEmpty {
            if let added = convert(event) { received.append(added) }
        }
        return received.isEmpty ? existing : received + existing
    }

    /// Convertit un événement distant en notification, ou `nil` s’il n’a pas
    /// de forme affichable ici (`connection-request`, défi sans contexte).
    private static func convert(_ event: AcctRemoteNotification) -> AcctNotification? {
        switch event.kind {
        case AcctNotificationKind.newFollower.rawValue:
            return AcctNotification(
                id: event.id, kind: .newFollower,
                actorId: event.actor.id, actorName: event.actor.displayName,
                performanceLabel: "", performanceText: "",
                subject: "", chapterNames: [], durationMinutes: 0,
                jobId: "", itemId: "", title: "", score: 0,
                createdAt: event.createdAt, read: false)
        case AcctNotificationKind.profileView.rawValue:
            return AcctNotification(
                id: event.id, kind: .profileView,
                actorId: event.actor.id, actorName: event.actor.displayName,
                performanceLabel: "", performanceText: "",
                subject: "", chapterNames: [], durationMinutes: 0,
                jobId: "", itemId: "", title: "", score: 0,
                createdAt: event.createdAt, read: false)
        case AcctNotificationKind.challengeUnavailable.rawValue:
            guard let challenge = event.challenge else { return nil }
            return AcctNotification(
                id: event.id, kind: .challengeUnavailable,
                actorId: event.actor.id, actorName: event.actor.displayName,
                performanceLabel: "", performanceText: "",
                subject: challenge.subject, chapterNames: challenge.chapterNames,
                durationMinutes: challenge.durationMinutes,
                jobId: "", itemId: "", title: "", score: 0,
                createdAt: event.createdAt, read: false)
        default:
            return nil
        }
    }

    /// `formatTimeAgo` : ancienneté lisible (« à l’instant », « il y a N min/h/j »).
    static func formatTimeAgo(_ createdAt: String, now: Date = Date()) -> String {
        guard let created = ISO8601DateFormatter.date(fromISO: createdAt) else {
            return "à l'instant"
        }
        let elapsed = Int(floor(now.timeIntervalSince(created) / 60))
        if elapsed < 1 { return "à l'instant" }
        if elapsed < 60 { return "il y a \(elapsed) min" }
        let hours = elapsed / 60
        if hours < 24 { return "il y a \(hours) h" }
        return "il y a \(hours / 24) j"
    }

    /// Identifiant de compte local, comme `PremCodeSync` : l’e-mail normalisé
    /// haché en identifiant public, ou `"local"` sans compte.
    static func accountId(email: String) -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "local" : DuelloAPI.publicProfileId(email: trimmed)
    }

    /// Clé de persistance locale des notifications, suffixée par le compte.
    static func key(accountId: String) -> String {
        "com.duello.ios.notifications.\(accountId)"
    }
}
