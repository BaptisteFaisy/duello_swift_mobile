import Foundation
import SwiftUI

// Découpage par responsabilité (fichiers de ce module) :
// `NotificationPreferences.swift`, `NotificationScheduler.swift`,
// `NotificationSettingsCard.swift`, `NotificationInstalledPager.swift`.

// MARK: - Carte de réglages

/// Carte de réglages des notifications : la ligne « icône + titre + description
/// courte + interrupteur » de `NotificationSettingsCard.tsx`.
///
/// L'interrupteur pilote la **préférence push** du compte, comme le hook
/// `usePushNotificationSettings` de la source : l'état porte `status`
/// (`loading` / `error` / `ready`), `enabled` (préférence persistée) et
/// `permission` (autorisation système). La valeur affichée vaut
/// `enabled && permissionStaysEnabled(permission)` ; l'action `updateEnabled`
/// vient de `ConsentPushActionsController` (`usePushNotificationSettingsActions`).
struct NotificationSettingsCard: View {

    /// Préférence locale des rappels : conservée pour les appelants existants
    /// (`AcctInfoAccountPage`), l'interrupteur de cette carte ne la pilote plus.
    @ObservedObject var store: NotificationPreferencesStore
    /// Invité : la description d'appel est affichée, comme côté Expo.
    var isGuest: Bool = false

    /// État du hook `usePushNotificationSettings` : `loading` au montage,
    /// `ready` une fois la préférence et la permission lues, `error` sinon.
    private enum Status { case loading, error, ready }

    @State private var status: Status = .loading
    @State private var enabled = false
    @State private var permission: PushNotifPermission = .undetermined
    @StateObject private var actions = ConsentPushActionsController()

    /// Valeur affichée par l'interrupteur (`enabled` du hook) : la préférence
    /// est active **et** la permission autorise encore l'enregistrement.
    private var isOn: Bool {
        status == .ready && enabled && PushNotifPolicy.permissionStaysEnabled(permission)
    }

    /// Interrupteur inerte tant que l'état n'est pas prêt, ou pendant une action
    /// (`disabled={state.status !== 'ready' || actions.busy}`).
    private var isDisabled: Bool { status != .ready || actions.busy }

    var body: some View {
        HStack(spacing: 10) {
            icon
            copy
            Spacer(minLength: 8)
            NotifSwitch(isOn: switchBinding, disabled: isDisabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Theme.white)
        .task { await refresh() }
        .alert(
            ConsentPushActions.unavailableTitle,
            isPresented: Binding(
                get: { actions.lastError != nil },
                set: { if !$0 { actions.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { actions.lastError = nil }
        } message: {
            Text(actions.lastError ?? "")
        }
    }

    /// Boîte 34 × 34, fond blanc, cloche 22 pt à l'encre (`styles.icon`).
    private var icon: some View {
        Image(systemName: "bell")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 34, height: 34)
            .background(Theme.white)
    }

    /// Titre « Notifications » (13/800, encre) et, pour un invité seulement, la
    /// description d'appel (`styles.title` / `styles.description`).
    private var copy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Notifications")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
            if isGuest {
                Text("Alertes de corrections terminées.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// `onValueChange={actions.updateEnabled}` : basculer coupe la préférence,
    /// ou demande la permission (et ouvre les réglages si elle est refusée).
    private var switchBinding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { newValue in
                Task {
                    await actions.updateEnabled(newValue)
                    await refresh()
                }
            }
        )
    }

    /// Relit la préférence persistée et la permission système
    /// (`usePushNotificationSettings.refresh`).
    @MainActor
    private func refresh() async {
        enabled = ConsentPushActions.isEnabled()
        permission = await PushNotifNative.currentPermission()
        status = .ready
    }
}

// MARK: - Interrupteur

/// Interrupteur de la carte, aux couleurs de la source (`Switch` RN) : piste
/// `surfaceMuted` / `primaryLight`, pouce `ink` / `inkFaint`.
///
/// SwiftUI ne règle ni la piste éteinte ni la couleur du pouce : plutôt qu'un
/// `ToggleStyle` (dont `configuration.isOn` n'est pas portable d'un
/// environnement à l'autre), l'interrupteur est un contrôle dédié piloté par
/// une `Binding<Bool>`, au rendu identique au `Switch` de la source.
private struct NotifSwitch: View {
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Theme.primaryLight : Theme.surfaceMuted)
                    .frame(width: 51, height: 31)
                Circle()
                    .fill(isOn ? Theme.ink : Theme.inkFaint)
                    .frame(width: 27, height: 27)
                    .padding(2)
                    .shadow(color: Color.black.opacity(0.15), radius: 1, y: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel("Activer ou désactiver les notifications")
        .accessibilityValue(isOn ? "activé" : "désactivé")
    }
}
