import Foundation
import SwiftUI
import UserNotifications

// MARK: - Réglages de notifications
//
// Portage des réglages de notifications de l'app Expo
// (`src/components/NotificationSettingsCard.tsx`,
// `src/components/InstalledNotificationsPager.tsx`).
//
// Différence de périmètre, assumée et documentée dans l'interface : la version
// Expo enregistre un jeton distant (Expo / FCM / APNs) et reçoit des alertes
// poussées par le serveur (`PushNotificationCoordinator.tsx`,
// `NotificationBadgeSync.tsx`, `PushNotificationTapHandler.tsx`). Ici, **aucun
// serveur push distant** : Duello ne pose que des **rappels locaux** avec
// `UNUserNotificationCenter`. Les alertes déclenchées par le serveur
// (« résultats de défi », « messages ») gardent leur interrupteur comme
// préférence persistée, mais restent hors périmètre tant qu'un service distant
// n'est pas branché.
//
// Découpage par responsabilité (fichiers de ce module) :
// `NotificationPreferences.swift` (préférences + store),
// `NotificationScheduler.swift` (rappels locaux),
// `NotificationSettingsCard.swift` (carte de réglages),
// `NotificationInstalledPager.swift` (pager d'explications).

// MARK: Préférences

/// Réglages de notifications de l'élève, persistés localement.
///
/// Reprend la forme du traqueur Expo (`utils/notificationPreferences.ts`) :
/// quatre interrupteurs et une heure de rappel. Aucune de ces valeurs ne part
/// vers un serveur ; elles ne pilotent que des rappels locaux.
struct NotificationPreferences: Codable, Equatable {

    /// Rappel quotidien d'entraînement, à l'heure choisie.
    var dailyTrainingReminder: Bool
    /// Résultats de défi. Nécessite le service push distant (hors périmètre).
    var challengeResults: Bool
    /// Messages reçus. Nécessite le service push distant (hors périmètre).
    var messages: Bool
    /// Classement hebdomadaire, rappelé en fin de semaine.
    var weeklyLeaderboard: Bool
    /// Heure du rappel quotidien, de 0 à 23.
    var reminderHour: Int
    /// Minute du rappel quotidien, de 0 à 59.
    var reminderMinute: Int

    enum CodingKeys: String, CodingKey {
        case dailyTrainingReminder, challengeResults, messages
        case weeklyLeaderboard, reminderHour, reminderMinute
    }

    /// Valeurs par défaut alignées sur l'app Expo : les alertes sont actives
    /// sauf le classement, comme l'absence de clé conserve le comportement
    /// historique côté Expo (`loadPushNotificationsEnabled`).
    init(
        dailyTrainingReminder: Bool = true,
        challengeResults: Bool = true,
        messages: Bool = true,
        weeklyLeaderboard: Bool = false,
        reminderHour: Int = 19,
        reminderMinute: Int = 0
    ) {
        self.dailyTrainingReminder = dailyTrainingReminder
        self.challengeResults = challengeResults
        self.messages = messages
        self.weeklyLeaderboard = weeklyLeaderboard
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    /// Décodage tolérant : une clé absente garde sa valeur par défaut, pour
    /// qu'un JSON écrit par une version antérieure reste lisible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyTrainingReminder =
            (try? c.decodeIfPresent(Bool.self, forKey: .dailyTrainingReminder)) ?? true
        challengeResults =
            (try? c.decodeIfPresent(Bool.self, forKey: .challengeResults)) ?? true
        messages =
            (try? c.decodeIfPresent(Bool.self, forKey: .messages)) ?? true
        weeklyLeaderboard =
            (try? c.decodeIfPresent(Bool.self, forKey: .weeklyLeaderboard)) ?? false
        reminderHour = Self.clamp(
            try? c.decodeIfPresent(Int.self, forKey: .reminderHour), 0...23, 19
        )
        reminderMinute = Self.clamp(
            try? c.decodeIfPresent(Int.self, forKey: .reminderMinute), 0...59, 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dailyTrainingReminder, forKey: .dailyTrainingReminder)
        try c.encode(challengeResults, forKey: .challengeResults)
        try c.encode(messages, forKey: .messages)
        try c.encode(weeklyLeaderboard, forKey: .weeklyLeaderboard)
        try c.encode(reminderHour, forKey: .reminderHour)
        try c.encode(reminderMinute, forKey: .reminderMinute)
    }

    /// Heure du rappel quotidien, en minutes depuis minuit.
    var reminderMinutesOfDay: Int { reminderHour * 60 + reminderMinute }

    /// Vrai dès qu'au moins un rappel récurrent peut être posé localement.
    var wantsRecurringReminder: Bool { dailyTrainingReminder || weeklyLeaderboard }

    /// Borne une valeur décodée dans son intervalle, avec repli.
    private static func clamp(_ value: Int?, _ range: ClosedRange<Int>, _ fallback: Int) -> Int {
        guard let value else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - Store

/// Store des préférences de notifications, persisté dans `UserDefaults`.
///
/// Même mécanique que `SessionStore` et `ProgressStore` : un seul JSON sous une
/// clé `com.duello.ios.*`, restauré au lancement. La programmation des rappels
/// est laissée à `LocalNotificationScheduler` ; ce store ne fait que lire et
/// écrire les préférences.
final class NotificationPreferencesStore: ObservableObject {

    /// Préférences courantes ; toute écriture passe par `update` pour persister.
    @Published var preferences: NotificationPreferences

    /// Clé de stockage, alignée sur le préfixe `com.duello.ios.*` du projet.
    private static let storageKey = "com.duello.ios.notification-preferences"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = NotificationPreferences()
        }
    }

    /// Écrit le JSON des préférences dans les préférences utilisateur.
    func persist() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Modifie les préférences puis persiste, en un seul point d'écriture.
    func update(_ transform: (inout NotificationPreferences) -> Void) {
        var next = preferences
        transform(&next)
        preferences = next
        persist()
    }

    /// Liaison SwiftUI sur un interrupteur, persistée à chaque bascule.
    func binding(for keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { self.preferences[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}
