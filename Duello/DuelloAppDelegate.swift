//
//  DuelloAppDelegate.swift
//  Duello
//
//  Délégue d’application iOS : jeton APNs, badge, tap sur une bannière.
//
//  V1 (26/09/2026, écart 20#1) : l’app n’avait aucun `AppDelegate`
//  (`UIApplicationDelegate` absent) ; le jeton APNs ne pouvait donc jamais
//  arriver et `PushNotifDeviceTokenRegistry` restait vide. Ce délégué alimente
//  le registre puis le coordinateur racine, selon la couture déjà prévue.
//
//  Fichiers source Expo portés : `src/utils/pushNotificationSync.ts` (cycle du
//  jeton) et `src/components/PushNotificationTapHandler.tsx` (`getLastNotificationResponseAsync`,
//  le cold start couvert par la relance du tap).
//
//  Doctrine « seam honnête » : hors d’iOS (`#if canImport(UIKit)`), il n’y a ni
//  APNs ni délégué ; le coordinateur continue de sonder le serveur (le badge
//  reste exact) mais aucun jeton n’est inventé. Sous iOS, la permission reste
//  demandée par le coordinateur avant tout enregistrement.
//
//  **Fichier non portable** : UIKit / `UserNotifications` n’existent que sur
//  iOS. Le pré-contrôle Linux ne le vérifie qu’en syntaxe.
//
//  Cible : iOS 16.
//
import Foundation

#if canImport(UIKit)
import UIKit
import UserNotifications

/// Délégue d’application iOS des notifications poussées.
final class DuelloAppDelegate: NSObject, UIApplicationDelegate {

    /// Enregistre le centre comme délégué des bannières, pour le tap.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Le système livre le jeton APNs : registre, puis coordinateur.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotifDeviceTokenRegistry.shared.set(deviceToken)
        guard let hex = PushNotifDeviceTokenRegistry.shared.current,
              PushNotifTokenJournal.isValidToken(hex) else { return }
        Task { @MainActor in
            PushNotifRootCoordinator.shared.acceptDeviceToken(hex)
        }
    }

    /// APNs a refusé l’appareil : le registre est vidé, sans jamais inventer
    /// un jeton.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotifDeviceTokenRegistry.shared.clear()
    }
}

// MARK: - Tap sur une bannière

extension DuelloAppDelegate: UNUserNotificationCenterDelegate {

    /// Tap sur la bannière (premier plan ou fond) : décodage + routage.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            PushNotifRootCoordinator.shared.handleTap(userInfo: userInfo)
        }
    }

    /// Bannière reçue au premier plan : affichée comme au fond, et le badge
    /// est resynchronisé sans attendre 30 s (`syncRemote`).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Task { @MainActor in
            await PushNotifRootCoordinator.shared.badge?.refreshLocal()
        }
        return [.banner, .sound, .badge]
    }
}

#endif
