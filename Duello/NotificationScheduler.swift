import Foundation
import SwiftUI
import UserNotifications

// Découpage par responsabilité (fichiers de ce module) :
// `NotificationPreferences.swift`, `NotificationScheduler.swift`,
// `NotificationSettingsCard.swift`, `NotificationInstalledPager.swift`.

// MARK: - Programmation des rappels locaux

/// Programmation des rappels locaux Duello.
///
/// Simple espace de noms : les rappels sont posés par `UNUserNotificationCenter`
/// sous forme de déclencheurs calendaires répétés
/// (`UNCalendarNotificationTrigger`). **Aucun serveur push distant** n'est
/// utilisé ; seuls les rappels récurrents (entraînement quotidien, classement
/// hebdomadaire) sont programmables sur l'appareil.
enum LocalNotificationScheduler {

    /// Identifiant du rappel quotidien d'entraînement.
    static let dailyTrainingIdentifier = "com.duello.ios.reminder.daily-training"
    /// Identifiant du rappel hebdomadaire de classement.
    static let weeklyLeaderboardIdentifier = "com.duello.ios.reminder.weekly-leaderboard"

    /// Identifiants de tous les rappels posés par Duello.
    static var identifiers: [String] {
        [dailyTrainingIdentifier, weeklyLeaderboardIdentifier]
    }

    /// Lit l'état d'autorisation courant, sans afficher de demande.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Demande l'autorisation d'afficher des notifications (alerte, son, badge).
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Nombre de rappels Duello actuellement programmés.
    static func pendingCount() async -> Int {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.filter { identifiers.contains($0.identifier) }.count
    }

    /// Repose tous les rappels Duello d'après les préférences : les anciens sont
    /// retirés, puis les rappels actifs sont reprogrammés. Sans autorisation,
    /// rien n'est posé (le système refuserait de livrer la bannière).
    static func apply(_ preferences: NotificationPreferences) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        if preferences.dailyTrainingReminder {
            var components = DateComponents()
            components.hour = min(max(preferences.reminderHour, 0), 23)
            components.minute = min(max(preferences.reminderMinute, 0), 59)
            await schedule(
                identifier: dailyTrainingIdentifier,
                title: "Entraînement du jour",
                body: "Un peu de travail aujourd'hui ? Reprends là où tu t'es arrêté.",
                matching: components
            )
        }

        if preferences.weeklyLeaderboard {
            var components = DateComponents()
            // Dimanche 18 h : la semaine Duello commence le lundi
            // (`WeeklyXP.weekKey`), le rappel invite donc à clore la semaine.
            components.weekday = 1
            components.hour = 18
            components.minute = 0
            await schedule(
                identifier: weeklyLeaderboardIdentifier,
                title: "Classement de la semaine",
                body: "Découvre où tu te situes avant la remise à zéro du lundi.",
                matching: components
            )
        }
    }

    /// Retire tous les rappels Duello (par exemple à la déconnexion).
    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: Interne

    /// Pose un rappel récurrent à partir de composants calendaires.
    private static func schedule(
        identifier: String,
        title: String,
        body: String,
        matching components: DateComponents
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Libellé français d'un état d'autorisation.
    static func statusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Autorisées"
        case .provisional: return "Autorisées (provisoires)"
        case .ephemeral: return "Autorisées (temporaires)"
        case .denied: return "Refusées par le système"
        case .notDetermined: return "En attente"
        @unknown default: return "Inconnues"
        }
    }

    /// Libellé court d'un état d'autorisation, pour les tuiles de statistique.
    static func statusShortLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "Accordée"
        case .denied: return "Refusée"
        case .notDetermined: return "En attente"
        @unknown default: return "—"
        }
    }

    /// Ton de pastille associé à un état d'autorisation.
    static func statusTone(_ status: UNAuthorizationStatus) -> DuelloPillTone {
        switch status {
        case .authorized, .provisional, .ephemeral: return .success
        case .denied: return .danger
        case .notDetermined: return .warning
        @unknown default: return .neutral
        }
    }
}
