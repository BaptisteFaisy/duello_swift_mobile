import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

// Pont natif vers `UNUserNotificationCenter` et APNs.
//
// **Fichier non portable** : `UserNotifications` et l'enregistrement APNs
// n'existent pas hors d'iOS. Il sort donc du lot portable du pré-contrôle Linux
// (`import UserNotifications`), qui ne le vérifie qu'en syntaxe — la logique
// pure, elle, vit dans `PushNotifPolicy` / `PushNotifRouter`, portables.
//
// Sources Expo portées : `src/utils/pushNotifications.ts`
// (`getPermissionsAsync`, `requestPermissionsAsync`, `openAppNotificationSettings`,
// `unregisterForNotificationsAsync`) et `PushNotificationTapHandler.tsx` (cold
// start via `getLastNotificationResponseAsync`).
//
// Limite assumée : le jeton APNs est livré par le système à l'`AppDelegate`
// (`application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`), qui doit
// l'enregistrer via `PushNotifDeviceTokenRegistry.shared.set(_:)`, puis appeler
// `PushNotifCoordinator.acceptDeviceToken(_:)`.

// MARK: - Registre du jeton d'appareil

/// Registre du jeton APNs, alimenté par l'`AppDelegate`.
///
/// Le système ne rend le jeton que par rappel : il est donc mis en cache ici,
/// sous verrou, en hexadécimal, pour que le coordinateur le lise à son rythme.
final class PushNotifDeviceTokenRegistry {

    static let shared = PushNotifDeviceTokenRegistry()

    private let lock = NSLock()
    private var token: String?

    private init() {}

    /// Jeton courant, ou `nil` tant que le système ne l'a pas livré.
    var current: String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    /// Enregistre le jeton binaire reçu de l'`AppDelegate`, en hexadécimal.
    func set(_ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        lock.lock()
        defer { lock.unlock() }
        token = hex
    }

    /// Oublie le jeton (désinscription).
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        token = nil
    }
}

// MARK: - Accès natif

/// Accès natif aux notifications poussées (permission, jeton, désinscription).
enum PushNotifNative {

    /// Permission courante, sans afficher de demande (`getPermissionsAsync`).
    /// Traduit aussi l'état d'autorisation système en permission Duello
    /// (`pushNotificationPermissionState`).
    static func currentPermission() async -> PushNotifPermission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        case .notDetermined: return .undetermined
        @unknown default: return .denied
        }
    }

    /// Demande la permission si nécessaire (`requestPushNotificationPermission`).
    static func requestPermission() async -> PushNotifPermission {
        let current = await currentPermission()
        if current != .undetermined { return current }
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return .denied
        }
        return await currentPermission()
    }

    /// Vrai si la permission n'a pas encore été tranchée
    /// (`isPushNotificationPermissionUndetermined`).
    static func isPermissionUndetermined() async -> Bool {
        await currentPermission() == .undetermined
    }

    /// Demande l'enregistrement APNs ; le jeton arrive ensuite par l'`AppDelegate`.
    static func registerForRemoteNotifications() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    /// Jeton d'appareil courant (hexadécimal), ou `nil` s'il n'est pas encore là.
    static func currentDeviceToken() async -> String? {
        PushNotifDeviceTokenRegistry.shared.current
    }

    /// Désinscrit l'appareil (`unregisterForNotificationsAsync`) et oublie le
    /// jeton local. L'autorisation système reste inchangée, comme côté Expo.
    static func unregisterNative() async -> Bool {
        #if canImport(UIKit)
        UIApplication.shared.unregisterForRemoteNotifications()
        #endif
        PushNotifDeviceTokenRegistry.shared.clear()
        return true
    }
}
