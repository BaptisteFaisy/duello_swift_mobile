//
//  EvEventReminderViews.swift
//  Duello
//
//  Port de src/components/event/EventReminderOptIn.tsx (RN) — opt-in aux rappels,
//  et port de src/hooks/useEventReminders.ts (RN) — maintien silencieux des
//  rappels des événements visibles.
//
//  `EvEventReminderOptIn` : placé sous le décompte, invite à activer les
//  notifications pour être prévenu « 10 minutes avant ». Visible seulement quand
//  les notifications ne sont pas acceptées ; l'appui demande l'autorisation
//  système — ou ouvre les réglages si elle a été refusée — puis planifie les
//  rappels de l'événement. Masqué instantanément dès l'acceptation, et au retour
//  au premier plan si l'autorisation a été accordée dans les réglages.
//
//  `EvEventRemindersModifier` (`.evEventReminders(_:)`) : équivalent du hook
//  `useEventReminders`, qui réaligne les rappels à chaque changement de liste.
//
//  Notes datées (24/09/2026) :
//    - Ionicons `notifications-outline` → SF Symbol `bell` ;
//    - `openNotificationSettings` → `ConsentPushActions.openSettings()` (page de
//      réglages iOS de l'app) ;
//    - `AppState.addEventListener('change')` → `@Environment(\.scenePhase)` ;
//    - `requestPushNotificationPermission` → `PushNotifNative.requestPermission()`,
//      même contrat que `getPushNotificationPermissionState` ;
//    - `Platform.OS === 'web'` → sans objet sur iOS, donc jamais masqué pour ce
//      motif.
//
//  Cible : iOS 16.
//
import SwiftUI

// MARK: - Opt-in sous le décompte

/// `EventReminderOptIn` : bouton d'activation des rappels de l'événement.
struct EvEventReminderOptIn: View {
    let event: EvEvent

    @Environment(\.scenePhase) private var scenePhase
    /// Permission connue, `nil` tant qu'elle n'est pas lue.
    @State private var permission: PushNotifPermission?
    @State private var busy = false

    /// Masqué tant que la permission n'est pas connue, ou déjà accordée : seule
    /// la demande a un sens à l'écran.
    private var isHidden: Bool {
        permission == nil || permission == .granted || permission == .unsupported
    }

    var body: some View {
        Group {
            if isHidden { EmptyView() } else { enableButton }
        }
        .task { permission = await PushNotifNative.currentPermission() }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await refreshOnForeground() }
        }
    }

    /// Retour des réglages système : une autorisation accordée dehors masque
    /// l'opt-in sans quitter la page, et les rappels sont planifiés.
    private func refreshOnForeground() async {
        let state = await PushNotifNative.currentPermission()
        permission = state
        if state == .granted {
            _ = await EvEventReminders.sync(events: [event])
        }
    }

    /// Appui : demande l'autorisation, ou ouvre les réglages si elle est refusée.
    private func enable() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if permission == .denied {
            try? await ConsentPushActions.openSettings()
            permission = await PushNotifNative.currentPermission()
            return
        }
        let state = await PushNotifNative.requestPermission()
        if state == .granted {
            // Masquage instantané : l'opt-in disparaît avant la planification.
            permission = .granted
            _ = await EvEventReminders.sync(events: [event])
        } else {
            permission = state
        }
    }

    /// Bouton noir, cloche et libellé, dans l'esprit d'`AppPressable` d'Expo.
    private var enableButton: some View {
        Button { Task { await enable() } } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell")
                    .font(.system(size: 17, weight: .bold))
                Text("Me prévenir 10 minutes avant")
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .opacity(busy ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel("Me prévenir 10 minutes avant")
        .accessibilityHint("Autorise les notifications puis planifie les rappels de l'événement")
    }
}

// MARK: - Maintien des rappels (`useEventReminders`)

/// `useEventReminders` : maintient les rappels locaux des événements visibles.
/// Silencieux : sans permission accordée, ne planifie rien et ne demande rien.
struct EvEventRemindersModifier: ViewModifier {
    let events: [EvEvent]

    func body(content: Content) -> some View {
        content.task(id: events) {
            _ = await EvEventReminders.sync(events: events)
        }
    }
}

extension View {
    /// Réaligne les rappels d'événements à chaque changement de la liste.
    func evEventReminders(_ events: [EvEvent]) -> some View {
        modifier(EvEventRemindersModifier(events: events))
    }
}
