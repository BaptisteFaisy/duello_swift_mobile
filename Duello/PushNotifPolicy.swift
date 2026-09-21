import Foundation

// Politique des notifications poussées Duello — partie **pure et portable**.
//
// Sources Expo portées : `src/utils/notificationPolicy.ts` (statut agrégé,
// libellés) et `src/utils/pushNotifications.ts` (état de permission, règles
// pures `pushNotificationsCanStayEnabled` / `canKeepNotificationsEnabled`).
//
// Aucun appel système ici : ces fonctions sont déterministes, testables, et
// restent compilables sans `UserNotifications` (absent de la plateforme de
// pré-contrôle Linux). L'usage réel de `UNUserNotificationCenter` et d'APNs
// est isolé dans `PushNotifNative.swift`, appelé par `PushNotifCoordinator`.

// MARK: - Permission et statut

/// État de la permission de notifications, aligné sur
/// `PushNotificationPermissionState` (`pushNotifications.ts`).
enum PushNotifPermission: String, Codable, Equatable {
    case granted
    case denied
    case undetermined
    case unsupported
}

/// Statut agrégé du bouton Notifications (`NotificationTrackerStatus`).
enum PushNotifTrackerStatus: String, Equatable {
    case active
    case blocked
    case pending
    case inactive
    case unsupported
    case loading

    /// Libellé français, mot pour mot depuis `notificationTrackerLabel`.
    var label: String {
        switch self {
        case .active: return "Activées"
        case .blocked: return "Refusées par le système"
        case .pending: return "En attente"
        case .inactive: return "Désactivées"
        case .unsupported: return "Non disponible"
        case .loading: return "Chargement…"
        }
    }
}

/// Type d'une alerte poussée, aligné sur `data.kind` du serveur
/// (`PushNotificationTapHandler.tsx`, `utils/notifications.ts`).
enum PushNotifKind: String, Codable, Equatable, CaseIterable {
    case newFollower = "new-follower"
    case challengeInvitation = "challenge-invitation"
    case challengeUnavailable = "challenge-unavailable"
}

// MARK: - Politique pure

/// Politique pure : faut-il notifier, priorité, dédoublonnage, fenêtre horaire.
enum PushNotifPolicy {

    // MARK: Statut agrégé

    /// Statut du bouton Notifications, calqué sur `notificationTrackerStatus`.
    static func trackerStatus(
        preference: Bool?,
        permission: PushNotifPermission?,
        platformIsWeb: Bool = false
    ) -> PushNotifTrackerStatus {
        if platformIsWeb || permission == .unsupported { return .unsupported }
        guard let preference, let permission else { return .loading }
        if !preference { return .inactive }
        switch permission {
        case .granted: return .active
        case .denied: return .blocked
        case .undetermined: return .pending
        case .unsupported: return .unsupported
        }
    }

    /// Vrai seulement quand une push peut réellement partir
    /// (`canReceivePushNotifications`).
    static func canReceivePushNotifications(
        preference: Bool?,
        permission: PushNotifPermission?
    ) -> Bool {
        trackerStatus(preference: preference, permission: permission) == .active
    }

    /// ON et pas bloqué (`canKeepNotificationsEnabled`).
    static func canKeepNotificationsEnabled(
        preference: Bool,
        permission: PushNotifPermission
    ) -> Bool {
        preference && (permission == .granted || permission == .undetermined)
    }

    /// La permission autorise encore l'enregistrement
    /// (`pushNotificationsCanStayEnabled`).
    static func permissionStaysEnabled(_ state: PushNotifPermission) -> Bool {
        state == .granted || state == .undetermined
    }

    // MARK: Priorité, dédoublonnage, fenêtre horaire

    /// Priorité relative d'une alerte : plus la valeur est haute, plus l'alerte
    /// passe devant (invitation de défi > nouvel abonné > défi indisponible).
    static func priority(for kind: PushNotifKind) -> Int {
        switch kind {
        case .challengeInvitation: return 3
        case .newFollower: return 2
        case .challengeUnavailable: return 1
        }
    }

    /// Dédoublonnage : une alerte déjà connue (même identifiant) est ignorée,
    /// comme le `known.has(id)` de `mergeRemoteNotifications`.
    static func isDuplicate(id: String, known: Set<String>) -> Bool {
        known.contains(id)
    }

    /// Fenêtre horaire autorisée, alignée sur les créneaux du rappel local
    /// (`NotificationSettingsCard` : 6 h – 22 h 30). Hors fenêtre, aucune alerte
    /// poussée n'est remontée à l'élève.
    static func isWithinAllowedWindow(
        _ date: Date,
        calendar: Calendar = .current,
        startMinute: Int = 6 * 60,
        endMinute: Int = 22 * 60 + 30
    ) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return minute >= startMinute && minute <= endMinute
    }
}
