//
//  PremSubscriptionSyncView.swift
//  Duello
//
//  Synchronisation d’abonnement montée à la racine.
//
//  Fichier source Expo porté : `src/components/SubscriptionPaymentSync.tsx`,
//  monté à la racine dans `App.tsx:2599` (hors invité). Au montage puis toutes
//  les cinq minutes au premier plan — et au retour au premier plan — le compte
//  interroge `GET /subscription`, réconcilie l’état stocké et prévient la
//  célébration quand une période vient d’être payée.
//
//  V1 (26/09/2026, écart 19#3) : `PremCodeSync.start()` n’était appelé par
//  personne ; ce montage racine le lance enfin. Vue sans rendu (0 × 0), qui ne
//  fait que vivre le cycle de la synchronisation.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Recopie l’essai ou l’abonnement dès que le serveur l’accorde, à la racine
/// de l’app (`SubscriptionPaymentSync` de la source).
struct PremSubscriptionSyncView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sync: PremCodeSync

    /// - Parameters:
    ///   - email: adresse du compte connecté, source de l’identifiant public.
    ///   - token: jeton de session, joint en `Bearer` à `GET /subscription`.
    init(email: String, token: String?) {
        _sync = StateObject(wrappedValue: PremCodeSync(email: email, token: token))
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            // V1 (écart 19#4) : la célébration d’abonnement
            // (`PremiumUnlockCelebrationCoordinator`, `App.tsx:2586`) n’était
            // montée par personne. Elle est sœur de la synchronisation dans la
            // source ; elle est donc posée ici, sur ce fichier premium déjà
            // racine, pour n’avoir qu’un seul abonnement aux déblocages.
            .overlay {
                PremCodeUnlockCoordinator(
                    accountId: sync.accountId,
                    daysRemaining: sync.daysRemaining
                )
            }
            .onAppear { sync.start() }
            .onDisappear { sync.stop() }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                Task { await sync.sync() }
            }
    }
}
