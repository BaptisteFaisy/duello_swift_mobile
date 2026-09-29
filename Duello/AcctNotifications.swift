//
//  AcctNotifications.swift
//  Duello
//
//  Notifications du compte : fonctions du magasin local et lecture distante.
//  Les modèles (`AcctNotificationKind`, `AcctNotification`,
//  `AcctRemoteNotification`, `AcctRemoteActor`, `AcctRemoteChallenge`) sont
//  extraits dans `AcctNotificationsModels.swift` (limite de 10 fonctions par
//  fichier) ; comportement inchangé.
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
//  V2 (28/09/2026, écart 20 C3) : `withCorrectionReadyNotification` porte la
//  notification « correction prête » produite à la fin d’une correction
//  (`utils/notifications.ts:73-86`).
//
//  Cible : iOS 16.
//
import Foundation
import Combine

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

    /// `withCorrectionReadyNotification` : ajoute la notification « correction
    /// prête » en tête, une seule fois par `jobId` (id `annale-correction:<jobId>`,
    /// `createdAt` ISO). Identique à `utils/notifications.ts:73-86`.
    static func withCorrectionReadyNotification(
        _ existing: [AcctNotification],
        jobId: String,
        itemId: String,
        title: String,
        score: Double
    ) -> [AcctNotification] {
        let id = "annale-correction:\(jobId)"
        if existing.contains(where: { $0.id == id }) { return existing }
        let created = AcctNotification(
            id: id, kind: .annaleCorrectionReady,
            actorId: "", actorName: "",
            performanceLabel: "", performanceText: "",
            subject: "", chapterNames: [], durationMinutes: 0,
            jobId: jobId, itemId: itemId, title: title, score: score,
            createdAt: ISO8601DateFormatter.flexible.string(from: Date()),
            read: false)
        return [created] + existing
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
