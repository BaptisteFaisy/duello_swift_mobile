//
//  PushNotifRootMount.swift
//  Duello
//
//  Notifications poussées montées à la racine : inscription serveur, badge
//  global et routage d'un tap.
//
//  Fichiers source Expo portés :
//    - `App.tsx:2600-2636` (montage racine) ;
//    - `src/components/PushNotificationCoordinator.tsx` (inscription serveur) ;
//    - `src/components/PushNotificationTapHandler.tsx` (routage du tap :
//      nouvel abonné → profil du membre, invitation → Défis, défi indisponible
//      → Mon compte) ;
//    - `src/components/NotificationBadgeSync.tsx` (badge global, sondage 30 s).
//
//  R7 (2026-09-27) : `PushNotifCoordinator` (avec `PushNotifNative`) était
//  porté mais jamais instancié. Ce fichier le câble à la racine, comme
//  `App.tsx` monte `PushNotificationCoordinator` une fois pour toute l'app.
//
//  V2 (28/09/2026, écart 20#1) : le badge global (`PushNotifBadgeController`,
//  `PushNotifBadgeSync.swift`) est désormais monté ici, adossé au magasin
//  partagé, comme `NotificationBadgeSync` à la racine d'Expo ; et le jeton APNs
//  livré par l'`AppDelegate` (`PushNotifAppDelegate`) est relayé au coordinateur
//  actif via `PushNotifRootCoordinator.acceptDeviceToken(_:)`.
//
//  Le routage réutilise `PushNotifTap` / `PushNotifRouter` de
//  `PushNotifRouting.swift` : **aucun `enum` n'est recopié**. La destination
//  est posée dans `PushNotifRootCoordinator` (état partagé) puis consommée par
//  `MainTabView` — jamais exécutée en silence.
//
//  Couture honnête : le jeton APNs et le tap natif ne sont livrés que par
//  l'`AppDelegate` (`PushNotifAppDelegate.swift`, instancié par
//  `@UIApplicationDelegateAdaptor` dans `DuelloApp.swift`). Le point d'entrée du
//  tap est donc exposé (`PushNotifRootCoordinator.handleTap(userInfo:)`) pour
//  que le délégué d'application l'appelle.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI

/// Onglet demandé par un tap (`navigate('challenges' | 'account')`).
enum PushNotifTab: Equatable {
    case account
    case challenges
}

/// Membre à ouvrir depuis un tap (`new-follower` → profil du membre).
struct PushNotifPendingMember: Identifiable, Equatable {
    /// `actorId` (`member-…`).
    let id: String
}

/// État partagé du routage des notifications poussées, posé à la racine et
/// consommé par `MainTabView`.
@MainActor
final class PushNotifRootCoordinator: ObservableObject {

    /// Instance unique, lue par la vue racine et par `MainTabView`.
    static let shared = PushNotifRootCoordinator()

    /// Onglet demandé par un tap, consommé par `MainTabView` (`nil` = aucun).
    @Published var pendingTab: PushNotifTab?
    /// Membre à ouvrir, consommé à la racine (`nil` = aucun).
    @Published var pendingMember: PushNotifPendingMember?

    /// Coordinateur d'inscription actif, pour lui relayer le jeton APNs livré
    /// par l'`AppDelegate`. Référence faible : le montage en est propriétaire.
    private weak var registration: PushNotifCoordinator?

    private init() {}

    /// Dépose (ou retire) le coordinateur d'inscription courant, à chaque
    /// (re)montage ou arrêt de `PushNotifRootMount`.
    func attach(_ registration: PushNotifCoordinator?) {
        self.registration = registration
    }

    /// Point d'entrée de l'`AppDelegate` : un jeton APNs vient d'être livré par
    /// le système, il est relayé au coordinateur actif (`acceptDeviceToken(_:)`).
    func acceptDeviceToken(_ hexToken: String) {
        registration?.acceptDeviceToken(hexToken)
    }

    /// Routage d'un tap décodé (`route` de `PushNotificationTapHandler.tsx`).
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

    /// Décode le payload brut d'une bannière système puis le route, via le
    /// routeur de `PushNotifRouting.swift` (aucun `enum` recopié).
    func handleTap(userInfo: [AnyHashable: Any]) {
        guard let tap = PushNotifRouter.route(userInfo: userInfo) else { return }
        handleTap(tap)
    }
}

/// Montage racine : démarre l'inscription serveur et le badge global pour le
/// compte connecté, et les arrête à la déconnexion (vue sans rendu, 0 × 0).
///
/// `@MainActor` : pilote `PushNotifCoordinator` / `PushNotifBadgeController`,
/// isolés au fil principal.
@MainActor
struct PushNotifRootMount: View {
    @EnvironmentObject private var session: SessionStore

    /// Inscription serveur courante, `nil` tant que la racine n'est pas montée
    /// ou que le compte est fermé.
    @State private var registration: PushNotifCoordinator?
    /// Badge global courant (`NotificationBadgeSync`), `nil` hors session.
    @State private var badgeController: PushNotifBadgeController?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear { synchronize() }
            .onChange(of: session.isSignedIn) { _ in synchronize() }
            .onDisappear { stop() }
    }

    /// (Re)instancie le coordinateur et le badge pour le compte courant, ou les
    /// arrête hors session — `registerRemotely` reste faux sans adresse
    /// (compte invité).
    private func synchronize() {
        stop()
        guard session.isSignedIn else { return }
        // Copie locale de la session : le jeton est lu à chaque envoi, sans que
        // les fermetures capturent la vue (`self`).
        let sessionStore = session
        let profile = session.profile
        let accountId = AcctNotifications.accountId(email: profile.email)
        AcctNotificationsStore.shared.configure(accountId: accountId)
        let hasAccount = !profile.email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let coordinator = PushNotifCoordinator(
            profile: profile,
            accountId: accountId,
            preference: { ConsentPushActions.isEnabled() },
            registerRemotely: { hasAccount },
            sessionToken: { sessionStore.token }
        )
        coordinator.start()
        registration = coordinator
        // Le délégué d'application (jeton APNs, tap natif) relaie au
        // coordinateur courant par cet état partagé.
        PushNotifRootCoordinator.shared.attach(coordinator)

        // Badge global (`NotificationBadgeSync.tsx`) : relit le stockage local
        // puis le serveur toutes les 30 s au premier plan.
        let store = AcctNotificationsStore.shared
        let badge = PushNotifBadgeController(providers: PushNotifBadgeProviders(
            loadUnreadCount: { await MainActor.run { store.unreadCount } },
            synchronize: {
                await AcctNotificationsSync.remote(
                    email: profile.email,
                    token: sessionStore.token,
                    accountId: accountId
                )
            }
        ))
        badge.start()
        badgeController = badge
    }

    /// Arrête l'inscription et le badge (déconnexion, changement de compte).
    private func stop() {
        registration?.stop()
        registration = nil
        PushNotifRootCoordinator.shared.attach(nil)
        badgeController?.stop()
        badgeController = nil
    }
}
