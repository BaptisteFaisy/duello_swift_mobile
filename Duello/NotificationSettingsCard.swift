import Foundation
import SwiftUI
import UserNotifications

// Découpage par responsabilité (fichiers de ce module) :
// `NotificationPreferences.swift`, `NotificationScheduler.swift`,
// `NotificationSettingsCard.swift`, `NotificationInstalledPager.swift`.

// MARK: - Carte de réglages

/// Carte de réglages de notifications : quatre interrupteurs, le choix de
/// l'heure du rappel quotidien, l'état d'autorisation du système et un accès
/// direct aux réglages iOS.
///
/// Reprend la ligne « icône + titre + description courte + interrupteur » de
/// `NotificationSettingsCard.tsx`, étendue aux réglages réels de Duello.
struct NotificationSettingsCard: View {

    /// Store des préférences, injecté par l'écran hôte.
    @ObservedObject var store: NotificationPreferencesStore
    /// Invité : la description d'appel reste courte, comme côté Expo.
    var isGuest: Bool = false

    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var scheduledCount = 0
    @State private var busy = false

    /// Créneaux proposés : toutes les demi-heures, de 6 h à 22 h 30.
    private let reminderSlots: [Int] = Array(stride(from: 6 * 60, through: 22 * 60 + 30, by: 30))
    /// Créneaux rapides, proposés en puces au-dessus du sélecteur précis.
    private let quickSlots: [Int] = [7 * 60, 12 * 60 + 30, 17 * 60 + 30, 21 * 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            authorizationRow
            reminders
            hourPicker
            actions
            footer
        }
        .duelloCard()
        .task { await synchronize(requestIfNeeded: false) }
    }

    // MARK: En-tête et état

    /// Titre de la carte et icône, sur le motif « icône + titre » d'Expo.
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 28)
            DuelloSectionHeader(
                title: "Notifications",
                subtitle: isGuest
                    ? "Alertes de corrections terminées."
                    : "Rappels locaux sur cet appareil"
            )
        }
    }

    /// Pastille d'état d'autorisation et raccourci vers les réglages iOS.
    private var authorizationRow: some View {
        HStack(spacing: 10) {
            DuelloPill(
                text: LocalNotificationScheduler.statusLabel(authorization),
                tone: LocalNotificationScheduler.statusTone(authorization),
                icon: statusIcon
            )
            Spacer(minLength: 8)
            if authorization == .denied {
                Button("Réglages iOS") { openSystemSettings() }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    /// Icône de la pastille, selon l'état d'autorisation.
    private var statusIcon: String {
        switch authorization {
        case .denied: return "bell.slash"
        case .notDetermined: return "bell"
        default: return "bell.fill"
        }
    }

    // MARK: Interrupteurs

    /// Les quatre réglages, séparés par des filets fins.
    private var reminders: some View {
        VStack(spacing: 0) {
            toggleRow(
                icon: "flame",
                title: "Rappel quotidien d'entraînement",
                subtitle: "Un rappel à l'heure choisie pour travailler.",
                isOn: reminderBinding(\.dailyTrainingReminder)
            )
            separator
            toggleRow(
                icon: "trophy",
                title: "Résultats de défi",
                subtitle: "Prévenir quand un défi est noté.",
                isOn: store.binding(for: \.challengeResults)
            )
            separator
            toggleRow(
                icon: "bubble.left",
                title: "Messages",
                subtitle: "Nouveaux messages du direct et du forum.",
                isOn: store.binding(for: \.messages)
            )
            separator
            toggleRow(
                icon: "list.number",
                title: "Classement hebdomadaire",
                subtitle: "Le dimanche, avant la remise à zéro.",
                isOn: reminderBinding(\.weeklyLeaderboard)
            )
        }
    }

    /// Filet séparateur, au ton de bordure du thème.
    private var separator: some View {
        Rectangle().fill(Theme.border).frame(height: 1)
    }

    /// Ligne interrupteur : icône, titre, description, puis le `Toggle`.
    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.ink)
        }
        .padding(.vertical, 6)
    }

    /// Liaison d'un rappel : basculer vers « activé » demande l'autorisation,
    /// puis repose les rappels.
    private func reminderBinding(
        _ keyPath: WritableKeyPath<NotificationPreferences, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { newValue in
                store.update { $0[keyPath: keyPath] = newValue }
                Task { await synchronize(requestIfNeeded: newValue) }
            }
        )
    }

    // MARK: Heure du rappel

    /// Choix de l'heure du rappel quotidien : puces rapides puis sélecteur
    /// précis. Désactivé tant que le rappel quotidien est coupé.
    private var hourPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            DuelloInfoRow(
                label: "Heure du rappel",
                value: timeLabel(store.preferences.reminderMinutesOfDay)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickSlots, id: \.self) { minutes in
                        DuelloChip(
                            title: timeLabel(minutes),
                            selected: store.preferences.reminderMinutesOfDay == minutes
                        ) {
                            setReminder(minutes: minutes)
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            Picker("Heure du rappel", selection: hourSelection) {
                ForEach(reminderSlots, id: \.self) { minutes in
                    Text(timeLabel(minutes)).tag(minutes)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.ink)
        }
        .padding(.vertical, 2)
        .disabled(!store.preferences.dailyTrainingReminder)
        .opacity(store.preferences.dailyTrainingReminder ? 1 : 0.5)
    }

    /// Liaison de l'heure, exprimée en minutes depuis minuit.
    private var hourSelection: Binding<Int> {
        Binding(
            get: { store.preferences.reminderMinutesOfDay },
            set: { minutes in setReminder(minutes: minutes) }
        )
    }

    /// Enregistre une heure de rappel (minutes depuis minuit) et repose les
    /// rappels sans redemander l'autorisation.
    private func setReminder(minutes: Int) {
        store.update {
            $0.reminderHour = minutes / 60
            $0.reminderMinute = minutes % 60
        }
        Task { await synchronize(requestIfNeeded: false) }
    }

    /// Formate un nombre de minutes depuis minuit en « HH:MM ».
    private func timeLabel(_ minutesOfDay: Int) -> String {
        String(format: "%02d:%02d", minutesOfDay / 60, minutesOfDay % 60)
    }

    // MARK: Actions

    /// Bouton principal (autoriser ou reprogrammer) et accès aux réglages iOS.
    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                Task { await primaryAction() }
            } label: {
                HStack(spacing: 8) {
                    if busy { ProgressView().tint(Theme.surface) }
                    Text(primaryButtonTitle)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(busy)

            DuelloListRow(
                title: "Réglages système",
                subtitle: "Autoriser ou couper dans les réglages iOS de Duello.",
                icon: "gearshape",
                showsChevron: true
            )
            .onTapGesture { openSystemSettings() }
        }
    }

    /// Libellé du bouton principal, selon l'état d'autorisation.
    private var primaryButtonTitle: String {
        switch authorization {
        case .denied: return "Ouvrir les réglages iOS"
        case .notDetermined: return "Autoriser les notifications"
        default: return "Reprogrammer les rappels"
        }
    }

    // MARK: Pied de carte

    /// Note de portée (rappels locaux uniquement) et résumé chiffré.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rappels locaux")
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            Text(
                "Duello programme ces rappels directement sur ton iPhone, sans "
                + "serveur push distant. Les alertes « résultats de défi » et "
                + "« messages » dépendent d'un service distant : leur réglage est "
                + "conservé, mais elles restent hors périmètre pour l'instant."
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                DuelloStatTile(label: "Rappels programmés", value: "\(scheduledCount)")
                DuelloStatTile(
                    label: "Autorisation",
                    value: LocalNotificationScheduler.statusShortLabel(authorization)
                )
            }
        }
    }

    // MARK: Effets

    /// Exécute l'action du bouton principal : ouvrir les réglages si l'accès a
    /// été refusé, sinon demander l'autorisation et reprogrammer.
    @MainActor
    private func primaryAction() async {
        if authorization == .denied {
            openSystemSettings()
        } else {
            await synchronize(requestIfNeeded: true)
        }
    }

    /// Aligne les rappels programmés sur les préférences, en demandant
    /// l'autorisation au besoin, puis rafraîchit l'état affiché.
    @MainActor
    private func synchronize(requestIfNeeded: Bool) async {
        if requestIfNeeded {
            let status = await LocalNotificationScheduler.authorizationStatus()
            if status == .notDetermined {
                busy = true
                await LocalNotificationScheduler.requestAuthorization()
                busy = false
            }
        }
        await LocalNotificationScheduler.apply(store.preferences)
        await refresh()
    }

    /// Relit l'autorisation système et le nombre de rappels programmés.
    @MainActor
    private func refresh() async {
        authorization = await LocalNotificationScheduler.authorizationStatus()
        scheduledCount = await LocalNotificationScheduler.pendingCount()
    }

    /// Ouvre la page de réglages iOS de l'application.
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
