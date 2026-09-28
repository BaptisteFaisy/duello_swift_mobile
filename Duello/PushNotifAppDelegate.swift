//
//  PushNotifAppDelegate.swift
//  Duello
//
//  Délégué d'application iOS : reçoit le jeton APNs et route les taps natifs.
//
//  **Fichier non portable** : `UIApplicationDelegate` n'existe pas hors d'iOS,
//  le corps est donc gardé par `#if canImport(UIKit)` (sous Linux le fichier ne
//  définit rien, et le pré-contrôle ne le vérifie qu'en syntaxe).
//
//  Sources Expo portées :
//    - `src/utils/pushNotifications.ts` (`ensurePushNotificationToken` :
//      l'enregistrement APNs est demandé par `PushNotifNative`, le jeton arrive
//      ici) ;
//    - `src/components/PushNotificationTapHandler.tsx` (bannière chaude/froide :
//      `addNotificationResponseReceivedListener` + `getLastNotificationResponseAsync`).
//
//  Écart 20#1 : sans ce délégué, `PushNotifNative.currentDeviceToken()` reste
//  `nil` (le système ne livre le jeton que par
//  `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`) et
//  l'entrée `handleTap(userInfo:)` n'était jamais appelée. Il est instancié par
//  `@UIApplicationDelegateAdaptor(PushNotifAppDelegate.self)` dans
//  `DuelloApp.swift` (hunk racine).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

#if canImport(UIKit)
import UIKit
import UserNotifications

/// Délégué d'application iOS des notifications poussées.
final class PushNotifAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Monte le délégué de centre de notifications et route le tap « à froid »
    /// (app lancée depuis une bannière, `getLastNotificationResponseAsync`).
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                PushNotifRootCoordinator.shared.handleTap(userInfo: payload)
            }
        }
        return true
    }

    /// Jeton APNs livré par le système : mis au registre, puis relayé au
    /// coordinateur d'inscription actif (`ensurePushNotificationToken`).
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotifDeviceTokenRegistry.shared.set(deviceToken)
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            PushNotifRootCoordinator.shared.acceptDeviceToken(hex)
        }
    }

    /// Échec d'enregistrement APNs : la boucle de reprise du coordinateur
    /// (`PushNotifRetryLoop`) retentera, rien à faire ici.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {}

    /// Bannière reçue au premier plan : affichée comme en arrière-plan.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Tap sur une bannière (app au premier plan ou en arrière-plan) : routé
    /// par `PushNotifRootCoordinator` (`route` de `PushNotificationTapHandler`).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            PushNotifRootCoordinator.shared.handleTap(userInfo: userInfo)
        }
        completionHandler()
    }
}

#endif
