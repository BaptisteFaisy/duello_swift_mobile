//
//  ConsentPushActions.swift
//  Duello
//
//  Actions des réglages de notifications poussées : activer / couper la
//  préférence et ouvrir la page de réglages iOS, avec l'alerte d'échec.
//
//  Fichiers source Expo portés :
//    - `src/hooks/usePushNotificationSettingsActions.ts`
//      (`usePushNotificationSettingsActions` : `busy`, `updateEnabled`,
//      `openSettings`, alerte « Réglage indisponible ») ;
//    - `src/utils/notificationSettings.ts` (`notificationSettingsPath`,
//      `openNotificationSettings`, `authorizeNotificationsInSettings`,
//      `updatePushNotificationPreference`) ;
//    - `src/utils/notificationPreferences.ts` (`loadPushNotificationsEnabled`,
//      `savePushNotificationsEnabled` : absence de valeur = actif, comportement
//      historique).
//
//  La permission et l'ouverture des réglages passent par les ponts natifs déjà
//  portés : `PushNotifNative` (permission, réglages) et `PushNotifPolicy`
//  (`permissionStaysEnabled`). L'état `busy` et l'alerte, portés par le hook,
//  vivent dans `ConsentPushActionsController` — l'`enum` ne portant pas d'état.
//
//  **Fichier non portable** : il ouvre la page de réglages iOS via `UIApplication`
//  (`import SwiftUI`). Le pré-contrôle Linux ne le vérifie donc qu'en syntaxe.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Actions des réglages de notifications poussées
/// (`usePushNotificationSettingsActions`).
enum ConsentPushActions {

    /// `AppAlert.alert('Réglage indisponible', …)` : titre de l'alerte d'échec.
    static let unavailableTitle = "Réglage indisponible"

    /// `ACCOUNT_STORAGE_KEYS.pushNotificationsEnabled`.
    static let enabledStorageKey = "prepapp-push-notifications-enabled:v1"

    /// Repli quand le nom de l'application est introuvable (`applicationName`).
    static let appNameFallback = "cette application"

    /// Erreur interne : l'ouverture des réglages n'a pas pu être préparée.
    enum Failure: Error { case settingsUnavailable }

    /// `loadPushNotificationsEnabled` : actif sauf si la valeur vaut `false`
    /// (les installations antérieures au réglage recevaient déjà les alertes).
    static func isEnabled() -> Bool {
        UserDefaults.standard.string(forKey: enabledStorageKey) != "false"
    }

    /// `savePushNotificationsEnabled` : écrit « true » / « false ».
    static func saveEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled ? "true" : "false", forKey: enabledStorageKey)
    }

    /// `notificationSettingsPath` : chemin lisible vers l'écran iOS des
    /// notifications, nommé d'après l'application installée.
    static func settingsPath() -> String {
        let display = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundle = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let name = [display, bundle].compactMap { $0 }.first { !$0.isEmpty } ?? appNameFallback
        return "Réglages → Notifications → \(name) → Autoriser les notifications"
    }

    /// Message de l'alerte d'échec, mot pour mot :
    /// « Réessaie ou ouvre les réglages manuellement : <chemin>. »
    static func unavailableMessage() -> String {
        "Réessaie ou ouvre les réglages manuellement : \(settingsPath())."
    }

    /// `updatePushNotificationPreference` : coupe la préférence, ou demande la
    /// permission — en passant par les réglages si elle est refusée.
    static func updateEnabled(_ enabled: Bool) async throws {
        if !enabled {
            saveEnabled(false)
            return
        }
        let permission = await PushNotifNative.currentPermission()
        if permission == .denied {
            try await openSettings()
            return
        }
        let requested = await PushNotifNative.requestPermission()
        saveEnabled(PushNotifPolicy.permissionStaysEnabled(requested))
    }

    /// `authorizeNotificationsInSettings` : ouvre la page de réglages iOS, puis
    /// enregistre le choix d'activer les alertes.
    static func openSettings() async throws {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            throw Failure.settingsUnavailable
        }
        UIApplication.shared.open(url)
        saveEnabled(true)
        #else
        throw Failure.settingsUnavailable
        #endif
    }
}

// MARK: - Contrôleur

/// État du hook `usePushNotificationSettingsActions` : un seul réglage à la
/// fois (`running`), un drapeau `busy` affiché, et le message d'échec à
/// présenter en alerte.
@MainActor
final class ConsentPushActionsController: ObservableObject {

    /// Vrai pendant qu'une action est en cours (`busy`).
    @Published private(set) var busy = false

    /// Message d'échec à afficher sous `ConsentPushActions.unavailableTitle`,
    /// `nil` tant qu'aucune action n'a échoué.
    @Published var lastError: String?

    private var running = false

    /// `updateEnabled` : bascule la préférence de notifications poussées.
    func updateEnabled(_ enabled: Bool) async {
        await perform { try await ConsentPushActions.updateEnabled(enabled) }
    }

    /// `openSettings` : ouvre la page de réglages iOS.
    func openSettings() async {
        await perform { try await ConsentPushActions.openSettings() }
    }

    /// `perform` : verrou anti-réentrance, `busy`, et alerte en cas d'échec.
    private func perform(_ action: () async throws -> Void) async {
        guard !running else { return }
        running = true
        busy = true
        defer {
            running = false
            busy = false
        }
        do {
            try await action()
            lastError = nil
        } catch {
            lastError = ConsentPushActions.unavailableMessage()
        }
    }
}
