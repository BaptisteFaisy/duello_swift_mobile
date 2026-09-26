//
//  PushNotifRoot.swift
//  Duello
//
//  Notifications poussées montées à la racine : inscription, badge, tap.
//
//  Fichiers source Expo portés :
//    - `App.tsx:2600-2636` (montage racine) ;
//    - `src/components/NotificationBadgeSync.tsx` (badge, sondage 30 s) ;
//    - `src/components/PushNotificationCoordinator.tsx` (inscription serveur) ;
//    - `src/components/PushNotificationTapHandler.tsx` (routage du tap :
//      nouvel abonné → profil du membre, invitation → Défis, défi
//      indisponible → Mon compte).
//
//  V1 (26/09/2026, écart 20#1) : le coordinateur et le badge n’étaient jamais
//  instanciés ; l’unique entrée reste ce coordinateur partagé, démarré au
//  montage de la racine et arrêté à la déconnexion.
//
//  Doctrine « seam honnête » : le jeton APNs et le tap natif sont indisponibles
//  hors d’iOS ; l’`AppDelegate` (`DuelloAppDelegate.swift`) les alimente quand
//  UIKit est présent, et `handleTap` dit explicitement la destination.
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

/// Onglet demandé par un tap (`navigate('challenges' | 'account')`).
enum PushNotifTab: Equatable {
    case account
    case challenges
}

/// Membre à ouvrir depuis un tap (`new-follower` → `openMemberProfile`).
struct PushNotifPendingMember: Identifiable, Equatable {
    /// `actorId` (`member-…`).
    let id: String
}

/// Coordinateur racine des notifications poussées, partagé.
@MainActor
final class PushNotifRootCoordinator: ObservableObject {

    /// Instance unique, lue aussi par l’`AppDelegate` et les onglets.
    static let shared = PushNotifRootCoordinator()

    /// Onglet demandé par un tap, consommé par `MainTabView` (`nil` = aucun).
    @Published var pendingTab: PushNotifTab?
    /// Membre à ouvrir, consommé par la feuille racine (`nil` = aucun).
    @Published var pendingMember: PushNotifPendingMember?

    /// Inscription serveur, `nil` avant le démarrage.
    private(set) var registration: PushNotifCoordinator?
    /// Badge global, `nil` avant le démarrage.
    private(set) var badge: PushNotifBadgeController?

    private init() {}

    /// Non-lues du badge, relues depuis le magasin partagé.
    var unreadCount: Int { AcctNotificationsStore.shared.unreadCount }

    /// Démarre l’inscription serveur et le badge pour le compte connecté.
    func start(profile: UserProfile, accountId: String, sessionToken: String?) {
        stop()
        let hasAccount = !profile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let registration = PushNotifCoordinator(
            profile: profile,
            accountId: accountId,
            preference: { ConsentPushActions.isEnabled() },
            registerRemotely: { hasAccount },
            sessionToken: { sessionToken })
        registration.start()
        self.registration = registration

        AcctNotificationsStore.shared.configure(accountId: accountId)
        let badge = PushNotifBadgeController(providers: PushNotifBadgeProviders(
            loadUnreadCount: { [accountId] in
                AcctNotifications.countUnread(AcctNotifications.load(accountId: accountId))
            },
            synchronize: { [accountId] in
                await AcctNotificationsSync.remote(
                    email: profile.email, token: sessionToken, accountId: accountId)
            }))
        badge.start()
        self.badge = badge
    }

    /// Arrête l’inscription et le badge (déconnexion, changement de compte).
    func stop() {
        registration?.stop()
        registration = nil
        badge?.stop()
        badge = nil
        pendingTab = nil
        pendingMember = nil
    }

    /// Bascule premier plan / arrière-plan (relance ou coupe le sondage).
    func setActive(_ active: Bool) {
        badge?.setActive(active)
    }

    /// Enregistre un jeton d’appareil reçu de l’`AppDelegate`.
    func acceptDeviceToken(_ hexToken: String) {
        registration?.acceptDeviceToken(hexToken)
    }

    /// Routage d’un tap (`route` de `PushNotificationTapHandler.tsx`) : la
    /// destination est posée, jamais exécutée en silence.
    func handleTap(_ tap: PushNotifTap) {
        switch tap {
        case .newFollower(let actorId):
            pendingMember = PushNotifPendingMember(id: actorId)
        case .challengeInvitation:
            pendingTab = .challenges
        case .challengeUnavailable:
            pendingTab = .account
        }
    }

    /// Décodage + routage du payload brut d’une bannière système.
    func handleTap(userInfo: [AnyHashable: Any]) {
        guard let tap = PushNotifRouter.route(userInfo: userInfo) else { return }
        handleTap(tap)
    }
}

/// Montage racine : démarre le coordinateur pour le compte connecté et le
/// rebascule au premier plan (vue sans rendu, 0 × 0).
///
/// `@MainActor` : observe le coordinateur partagé, isolé au fil principal.
@MainActor
struct PushNotifRootMount: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var root = PushNotifRootCoordinator.shared

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear { start() }
            .onChange(of: session.isSignedIn) { _ in start() }
            .onChange(of: scenePhase) { phase in
                root.setActive(phase == .active)
            }
    }

    /// Instancie le coordinateur avec le profil et le jeton courants.
    private func start() {
        root.start(
            profile: session.profile,
            accountId: AcctNotifications.accountId(email: session.profile.email),
            sessionToken: session.token
        )
    }
}
