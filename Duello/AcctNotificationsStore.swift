//
//  AcctNotificationsStore.swift
//  Duello
//
//  Magasin local des notifications du compte + lecture distante.
//
//  Fichiers source Expo portés :
//    - `src/utils/socialApi.ts` (`fetchSocialNotifications`) ;
//    - `src/components/NotificationBadgeSync.tsx` (sondage 30 s, fusion, badge) ;
//    - l’état `notifications` de `src/screens/AccountScreen.tsx`.
//
//  V1 (26/09/2026, écart 20#2) : magasin partagé, seule source de vérité de la
//  liste et du compteur de non-lues. La feuille « Notifications » l’observe et
//  le coordinateur de badge le relit — comme `NotificationBadgeSync` à la
//  racine d’Expo.
//
//  À raccorder (vague 2, 2026-09-29, écart 20#2) : `addCorrectionReady` reste
//  sans appelant — la source produit la notification « correction prête » à la
//  transition `ready` de `AnnaleCorrectionMonitor.synchronize`
//  (`AnnaleCorrectionMonitor.tsx:85-94`). Le raccord se fait dans
//  `AnnCorrectionMonitor.upsert`, fichier hors de cette unité (voir rapport,
//  « À raccorder »).
//
//  Cible : iOS 16.
//
import Foundation
import Combine

/// Lecture distante des notifications (`fetchSocialNotifications`).
enum AcctNotificationsAPI {
    /// Enveloppe de la réponse : `{ "notifications": [ … ] }`.
    struct Envelope: Decodable {
        let notifications: [AcctRemoteNotification]?
    }

    /// `GET /notifications?userId=member-…`.
    static func fetch(
        email: String,
        token: String?
    ) async throws -> [AcctRemoteNotification] {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let data = try await DuelloAPI.request(
            "notifications",
            token: token,
            query: [URLQueryItem(
                name: "userId",
                value: DuelloAPI.publicProfileId(email: trimmed))])
        let envelope = (try? DuelloAPI.decoder.decode(Envelope.self, from: data))
            ?? Envelope(notifications: nil)
        return envelope.notifications ?? []
    }
}

/// Magasin partagé de la liste des notifications (`notifications` de l’écran).
@MainActor
final class AcctNotificationsStore: ObservableObject {

    /// Instance partagée : la feuille et le coordinateur de badge lisent le
    /// même état, comme l’unique `notifications` de `AccountScreen`.
    static let shared = AcctNotificationsStore()

    /// Liste courante, dans l’ordre d’affichage (plus récente d’abord).
    @Published private(set) var notifications: [AcctNotification] = []

    /// Identifiant du compte courant, clé de persistance.
    private(set) var accountId = "local"

    private init() {}

    /// `countUnread` : non-lues, pour le badge.
    var unreadCount: Int { AcctNotifications.countUnread(notifications) }

    /// Aligne le magasin sur le compte connecté et relit le stockage.
    func configure(accountId: String) {
        guard accountId != self.accountId else { return }
        self.accountId = accountId
        notifications = AcctNotifications.load(accountId: accountId)
    }

    /// Relit le stockage local (`loadNotifications`).
    func reload() {
        notifications = AcctNotifications.load(accountId: accountId)
    }

    /// `markAllRead` : marque tout lu et persiste.
    func markAllRead() {
        notifications = AcctNotifications.markAllRead(notifications)
        AcctNotifications.save(notifications, accountId: accountId)
    }

    /// `withCorrectionReadyNotification` + `saveNotifications` : ajoute la
    /// notification « correction prête » (une seule fois par `jobId`) et la
    /// publie. Identique à `AnnaleCorrectionMonitor.tsx:85-94`.
    func addCorrectionReady(jobId: String, itemId: String, title: String, score: Double) {
        let current = AcctNotifications.load(accountId: accountId)
        let updated = AcctNotifications.withCorrectionReadyNotification(
            current, jobId: jobId, itemId: itemId, title: title, score: score)
        guard updated != current else { return }
        AcctNotifications.save(updated, accountId: accountId)
        notifications = updated
    }

    /// `syncRemote` : relit le serveur, fusionne, écrit si changé.
    func syncRemote(email: String, token: String?) async {
        guard let remote = try? await AcctNotificationsAPI.fetch(email: email, token: token)
        else { return }
        let current = AcctNotifications.load(accountId: accountId)
        let merged = AcctNotifications.mergeRemoteNotifications(current, remote: remote)
        if merged != current {
            AcctNotifications.save(merged, accountId: accountId)
        }
        notifications = merged
    }
}

/// Fusion réseau isolée pour le coordinateur de badge (`synchronize` de
/// `PushNotifBadgeProviders`) : ne touche aucun état observable, écrit le
/// stockage, et renvoie le compteur de non-lues.
enum AcctNotificationsSync {
    /// Relit le serveur, fusionne, écrit si changé, renvoie les non-lues.
    static func remote(email: String, token: String?, accountId: String) async -> Int {
        guard let remote = try? await AcctNotificationsAPI.fetch(email: email, token: token)
        else {
            return AcctNotifications.countUnread(AcctNotifications.load(accountId: accountId))
        }
        let current = AcctNotifications.load(accountId: accountId)
        let merged = AcctNotifications.mergeRemoteNotifications(current, remote: remote)
        if merged != current {
            AcctNotifications.save(merged, accountId: accountId)
        }
        return AcctNotifications.countUnread(merged)
    }
}
