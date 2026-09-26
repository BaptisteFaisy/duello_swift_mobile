//
//  DuelloRootServices.swift
//  Duello
//
//  Services montés **une seule fois** à la racine, comme les composants
//  d’`App.tsx:2586-2636` : hôte de la fenêtre de paiement des outils Premium,
//  synchronisation d’abonnement, notifications poussées et fiche ouverte par un
//  tap.
//
//  V1 (26/09/2026) :
//    - écart 19#2 : `PremiumToolPaywallHost` (`App.tsx:2587`) ;
//    - écart 19#3 : `SubscriptionPaymentSync` (`App.tsx:2599`) ;
//    - écart 20#1 : `PushNotificationCoordinator` + `NotificationBadgeSync` +
//      `PushNotificationTapHandler` (`App.tsx:2600-2636`).
//
//  Cible : iOS 16.
//
import SwiftUI

/// Greffe les services racine sur le contenu de l’app.
///
/// `@MainActor` : le modificateur observe le coordinateur de push, isolé au fil
/// principal — même motif que `MainTabView`.
@MainActor
struct DuelloRootServices: ViewModifier {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var pushRoot = PushNotifRootCoordinator.shared

    func body(content: Content) -> some View {
        content
            // Hôte de la fenêtre de paiement des outils Premium (`PremiumToolPaywallHost`).
            .premToolPaywallHost(token: session.token)
            .background(alignment: .topLeading) { mounts }
            // Fiche ouverte par un tap `new-follower` (`openMemberProfile`).
            .sheet(item: $pushRoot.pendingMember) { member in
                PushNotifMemberSheet(memberId: member.id)
            }
    }

    /// Vues sans rendu (0 × 0) : synchronisation d’abonnement et notifications
    /// poussées, vivantes tant que la racine vit.
    @ViewBuilder
    private var mounts: some View {
        ZStack {
            PushNotifRootMount()
            if session.isSignedIn {
                PremSubscriptionSyncView(email: session.profile.email, token: session.token)
                    .id(AcctNotifications.accountId(email: session.profile.email))
            }
        }
    }
}

extension View {
    /// Monte les services racine (paywall, abonnement, push). À poser **avant**
    /// les `.environmentObject(…)` de la racine, pour que les vues greffées
    /// reçoivent la session.
    func duelloRootServices() -> some View {
        modifier(DuelloRootServices())
    }
}
