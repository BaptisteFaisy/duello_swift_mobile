//
//  AcctNotificationsModels.swift
//  Duello
//
//  Modèles des notifications du compte, extraits de `AcctNotifications.swift`
//  (limite de 10 fonctions par fichier) : `AcctNotificationKind`,
//  `AcctNotification` (avec `AcctNotification.str`), `AcctRemoteNotification`,
//  `AcctRemoteActor`, `AcctRemoteChallenge`. Comportement inchangé.
//
//  Fichier source Expo porté : `src/utils/notifications.ts`
//  (`AccountNotification`, `RemoteNotificationLike`).
//
//  Cible : iOS 16.
//
import Foundation

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

    /// `private` retiré lors du déplacement dans ce fichier (portée fichier en
    /// Swift) : visibilité élargie à `internal` (visibilité EFFECTIVE inchangée
    /// pour l’app, un seul module) ; corps et signature inchangés.
    static func str(
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
