//
//  EvEventReminders.swift
//  Duello
//
//  Port de src/utils/eventReminders.ts (RN) — rappels locaux des événements.
//
//  Programme, aligne et annule les rappels locaux d'un concours blanc : « la
//  veille » puis « dix minutes avant » le début. Les rappels sont posés par
//  `UNUserNotificationCenter` (rappels **locaux**) : aucun service push distant,
//  aucun jeton, aucun OTA Expo (`expo-notifications`).
//
//  Fichier source Expo porté : `src/utils/eventReminders.ts`
//  (`EVENT_REMINDER_DAY_BEFORE_MS`, `EVENT_REMINDER_TEN_MINUTES_MS`,
//  `EVENT_REMINDER_ID_PREFIX`, `eventReminderId`, `eventReminderPlan`,
//  `syncEventReminders`). L'instant de début vient d'`EvEventSchedule.startDate`,
//  port d'`eventStartAt`.
//
//  Seam honnête — le pont natif est isolé derrière `EvEventReminderScheduling` :
//  la logique de plan est pure et testable, l'usage réel de
//  `UNUserNotificationCenter` vit dans `EvEventReminderCenter`. L'autorisation se
//  lit par `PushNotifNative.currentPermission()`, même traduction que
//  `getPushNotificationPermissionState` (`granted` seul autorise la pose).
//
//  Limites assumées (24/09/2026) :
//    - `Platform.OS === 'web'` → sans objet sur iOS : pas de repli web ;
//    - `ensureAndroidPushNotificationChannel` (canal Android) non porté : iOS
//      n'a pas de canal de notification ;
//    - le déclencheur DATE d'Expo devient un `UNCalendarNotificationTrigger`
//      unique, seconde comprise (précision suffisante pour « la veille » et
//      « dix minutes avant »).
//
//  Cible : iOS 16.
//
import Foundation
import UserNotifications

// MARK: - Décalages

/// Décalage d'un rappel avant le début de l'événement (`EVENT_REMINDER_OFFSETS`).
enum EvEventReminderOffset: String, CaseIterable {
    /// « La veille » du début.
    case dayBefore = "day-before"
    /// « Dix minutes avant » le début.
    case tenMinutes = "ten-minutes"

    /// Délai du tir avant le début de l'épreuve.
    var lead: TimeInterval {
        switch self {
        case .dayBefore: return EvEventReminders.dayBefore
        case .tenMinutes: return EvEventReminders.tenMinutes
        }
    }
}

/// Rappel à planifier (`EventReminderPlanEntry`).
struct EvEventReminderPlanEntry: Identifiable, Equatable {
    var identifier: String
    var eventId: String
    var fireAt: Date
    var title: String
    var body: String

    var id: String { identifier }
}

// MARK: - Plan et synchronisation

/// Rappels locaux des événements : plan, identifiants et alignement.
enum EvEventReminders {

    /// « La veille » : 24 h avant le début (`EVENT_REMINDER_DAY_BEFORE_MS`).
    static let dayBefore: TimeInterval = 24 * 60 * 60
    /// « Dix minutes avant » (`EVENT_REMINDER_TEN_MINUTES_MS`).
    static let tenMinutes: TimeInterval = 10 * 60
    /// Préfixe des identifiants : les rappels d'événements se reconnaissent
    /// (`EVENT_REMINDER_ID_PREFIX`).
    static let idPrefix = "duello-event-reminder:"

    /// Identifiant d'un rappel (`eventReminderId`).
    static func identifier(eventId: String, key: EvEventReminderOffset) -> String {
        "\(idPrefix)\(eventId):\(key.rawValue)"
    }

    /// Corps d'un rappel (`reminderBody`), libellés repris mot pour mot.
    static func body(event: EvEvent, offset: EvEventReminderOffset) -> String {
        switch offset {
        case .dayBefore:
            return event.startTime.map { "\(event.title) commence demain à \($0)." }
                ?? "\(event.title) commence demain."
        case .tenMinutes:
            return "\(event.title) commence dans 10 minutes — ouvre Duello !"
        }
    }

    /// Rappels à planifier (`eventReminderPlan`) : un tir par décalage encore
    /// futur. Un événement sans horaire lisible ne donne rien ; un décalage
    /// périmé non plus — jamais de tir immédiat.
    static func plan(events: [EvEvent], now: Date) -> [EvEventReminderPlanEntry] {
        var entries: [EvEventReminderPlanEntry] = []
        for event in events {
            guard let start = EvEventSchedule.startDate(event) else { continue }
            for offset in EvEventReminderOffset.allCases {
                let fireAt = start.addingTimeInterval(-offset.lead)
                guard fireAt > now else { continue }
                entries.append(EvEventReminderPlanEntry(
                    identifier: identifier(eventId: event.id, key: offset),
                    eventId: event.id,
                    fireAt: fireAt,
                    title: event.title,
                    body: body(event: event, offset: offset)
                ))
            }
        }
        return entries
    }

    /// Aligne les rappels planifiés sur les événements visibles
    /// (`syncEventReminders`) : les périmés sont annulés, les manquants posés,
    /// les bons conservés. Silencieux : sans autorisation accordée, rien n'est
    /// planifié et rien n'est demandé. Retourne le nombre de rappels posés.
    @discardableResult
    static func sync(
        events: [EvEvent],
        now: Date = Date(),
        scheduler: EvEventReminderScheduling = EvEventReminderCenter()
    ) async -> Int {
        guard await scheduler.isAuthorized() else { return 0 }
        let wanted = plan(events: events, now: now)
        let wantedIds = Set(wanted.map(\.identifier))
        let ours = (await scheduler.pendingIdentifiers()).filter { $0.hasPrefix(idPrefix) }
        scheduler.cancel(identifiers: ours.filter { !wantedIds.contains($0) })
        let kept = Set(ours.filter { wantedIds.contains($0) })
        var added = 0
        for entry in wanted where !kept.contains(entry.identifier) {
            await scheduler.add(entry)
            added += 1
        }
        return added
    }
}

// MARK: - Pont natif

/// Pont natif des rappels d'événements : seam explicite, pour que la logique de
/// plan reste pure et qu'un double de test puisse la piloter.
protocol EvEventReminderScheduling {
    /// Vrai si l'autorisation système autorise la livraison (`granted`).
    func isAuthorized() async -> Bool
    /// Identifiants des rappels actuellement en attente.
    func pendingIdentifiers() async -> [String]
    /// Retire des rappels en attente.
    func cancel(identifiers: [String])
    /// Pose un rappel.
    func add(_ entry: EvEventReminderPlanEntry) async
}

/// Implémentation réelle : `UNUserNotificationCenter` (rappels locaux).
struct EvEventReminderCenter: EvEventReminderScheduling {

    func isAuthorized() async -> Bool {
        switch await PushNotifNative.currentPermission() {
        case .granted: return true
        default: return false
        }
    }

    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func cancel(identifiers: [String]) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ entry: EvEventReminderPlanEntry) async {
        let content = UNMutableNotificationContent()
        content.title = entry.title
        content.body = entry.body
        content.sound = .default
        content.userInfo = ["kind": "event-reminder", "eventId": entry.eventId]
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Self.components(for: entry.fireAt),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: entry.identifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Composants calendaires locaux de la date de tir (déclencheur DATE).
    private static func components(for date: Date) -> DateComponents {
        Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
    }
}
