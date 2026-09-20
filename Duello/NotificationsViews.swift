import Foundation
import SwiftUI
import UserNotifications

// MARK: - Réglages de notifications
//
// Portage des réglages de notifications de l'app Expo
// (`src/components/NotificationSettingsCard.tsx`,
// `src/components/InstalledNotificationsPager.tsx`).
//
// Différence de périmètre, assumée et documentée dans l'interface : la version
// Expo enregistre un jeton distant (Expo / FCM / APNs) et reçoit des alertes
// poussées par le serveur (`PushNotificationCoordinator.tsx`,
// `NotificationBadgeSync.tsx`, `PushNotificationTapHandler.tsx`). Ici, **aucun
// serveur push distant** : Duello ne pose que des **rappels locaux** avec
// `UNUserNotificationCenter`. Les alertes déclenchées par le serveur
// (« résultats de défi », « messages ») gardent leur interrupteur comme
// préférence persistée, mais restent hors périmètre tant qu'un service distant
// n'est pas branché.

// MARK: Préférences

/// Réglages de notifications de l'élève, persistés localement.
///
/// Reprend la forme du traqueur Expo (`utils/notificationPreferences.ts`) :
/// quatre interrupteurs et une heure de rappel. Aucune de ces valeurs ne part
/// vers un serveur ; elles ne pilotent que des rappels locaux.
struct NotificationPreferences: Codable, Equatable {

    /// Rappel quotidien d'entraînement, à l'heure choisie.
    var dailyTrainingReminder: Bool
    /// Résultats de défi. Nécessite le service push distant (hors périmètre).
    var challengeResults: Bool
    /// Messages reçus. Nécessite le service push distant (hors périmètre).
    var messages: Bool
    /// Classement hebdomadaire, rappelé en fin de semaine.
    var weeklyLeaderboard: Bool
    /// Heure du rappel quotidien, de 0 à 23.
    var reminderHour: Int
    /// Minute du rappel quotidien, de 0 à 59.
    var reminderMinute: Int

    enum CodingKeys: String, CodingKey {
        case dailyTrainingReminder, challengeResults, messages
        case weeklyLeaderboard, reminderHour, reminderMinute
    }

    /// Valeurs par défaut alignées sur l'app Expo : les alertes sont actives
    /// sauf le classement, comme l'absence de clé conserve le comportement
    /// historique côté Expo (`loadPushNotificationsEnabled`).
    init(
        dailyTrainingReminder: Bool = true,
        challengeResults: Bool = true,
        messages: Bool = true,
        weeklyLeaderboard: Bool = false,
        reminderHour: Int = 19,
        reminderMinute: Int = 0
    ) {
        self.dailyTrainingReminder = dailyTrainingReminder
        self.challengeResults = challengeResults
        self.messages = messages
        self.weeklyLeaderboard = weeklyLeaderboard
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    /// Décodage tolérant : une clé absente garde sa valeur par défaut, pour
    /// qu'un JSON écrit par une version antérieure reste lisible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyTrainingReminder =
            (try? c.decodeIfPresent(Bool.self, forKey: .dailyTrainingReminder)) ?? true
        challengeResults =
            (try? c.decodeIfPresent(Bool.self, forKey: .challengeResults)) ?? true
        messages =
            (try? c.decodeIfPresent(Bool.self, forKey: .messages)) ?? true
        weeklyLeaderboard =
            (try? c.decodeIfPresent(Bool.self, forKey: .weeklyLeaderboard)) ?? false
        reminderHour = Self.clamp(
            try? c.decodeIfPresent(Int.self, forKey: .reminderHour), 0...23, 19
        )
        reminderMinute = Self.clamp(
            try? c.decodeIfPresent(Int.self, forKey: .reminderMinute), 0...59, 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dailyTrainingReminder, forKey: .dailyTrainingReminder)
        try c.encode(challengeResults, forKey: .challengeResults)
        try c.encode(messages, forKey: .messages)
        try c.encode(weeklyLeaderboard, forKey: .weeklyLeaderboard)
        try c.encode(reminderHour, forKey: .reminderHour)
        try c.encode(reminderMinute, forKey: .reminderMinute)
    }

    /// Heure du rappel quotidien, en minutes depuis minuit.
    var reminderMinutesOfDay: Int { reminderHour * 60 + reminderMinute }

    /// Vrai dès qu'au moins un rappel récurrent peut être posé localement.
    var wantsRecurringReminder: Bool { dailyTrainingReminder || weeklyLeaderboard }

    /// Borne une valeur décodée dans son intervalle, avec repli.
    private static func clamp(_ value: Int?, _ range: ClosedRange<Int>, _ fallback: Int) -> Int {
        guard let value else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - Store

/// Store des préférences de notifications, persisté dans `UserDefaults`.
///
/// Même mécanique que `SessionStore` et `ProgressStore` : un seul JSON sous une
/// clé `com.duello.ios.*`, restauré au lancement. La programmation des rappels
/// est laissée à `LocalNotificationScheduler` ; ce store ne fait que lire et
/// écrire les préférences.
final class NotificationPreferencesStore: ObservableObject {

    /// Préférences courantes ; toute écriture passe par `update` pour persister.
    @Published var preferences: NotificationPreferences

    /// Clé de stockage, alignée sur le préfixe `com.duello.ios.*` du projet.
    private static let storageKey = "com.duello.ios.notification-preferences"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = NotificationPreferences()
        }
    }

    /// Écrit le JSON des préférences dans les préférences utilisateur.
    func persist() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Modifie les préférences puis persiste, en un seul point d'écriture.
    func update(_ transform: (inout NotificationPreferences) -> Void) {
        var next = preferences
        transform(&next)
        preferences = next
        persist()
    }

    /// Liaison SwiftUI sur un interrupteur, persistée à chaque bascule.
    func binding(for keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { self.preferences[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}

// MARK: - Programmation des rappels locaux

/// Programmation des rappels locaux Duello.
///
/// Simple espace de noms : les rappels sont posés par `UNUserNotificationCenter`
/// sous forme de déclencheurs calendaires répétés
/// (`UNCalendarNotificationTrigger`). **Aucun serveur push distant** n'est
/// utilisé ; seuls les rappels récurrents (entraînement quotidien, classement
/// hebdomadaire) sont programmables sur l'appareil.
enum LocalNotificationScheduler {

    /// Identifiant du rappel quotidien d'entraînement.
    static let dailyTrainingIdentifier = "com.duello.ios.reminder.daily-training"
    /// Identifiant du rappel hebdomadaire de classement.
    static let weeklyLeaderboardIdentifier = "com.duello.ios.reminder.weekly-leaderboard"

    /// Identifiants de tous les rappels posés par Duello.
    static var identifiers: [String] {
        [dailyTrainingIdentifier, weeklyLeaderboardIdentifier]
    }

    /// Lit l'état d'autorisation courant, sans afficher de demande.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Demande l'autorisation d'afficher des notifications (alerte, son, badge).
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Nombre de rappels Duello actuellement programmés.
    static func pendingCount() async -> Int {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.filter { identifiers.contains($0.identifier) }.count
    }

    /// Repose tous les rappels Duello d'après les préférences : les anciens sont
    /// retirés, puis les rappels actifs sont reprogrammés. Sans autorisation,
    /// rien n'est posé (le système refuserait de livrer la bannière).
    static func apply(_ preferences: NotificationPreferences) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        if preferences.dailyTrainingReminder {
            var components = DateComponents()
            components.hour = min(max(preferences.reminderHour, 0), 23)
            components.minute = min(max(preferences.reminderMinute, 0), 59)
            await schedule(
                identifier: dailyTrainingIdentifier,
                title: "Entraînement du jour",
                body: "Un peu de travail aujourd'hui ? Reprends là où tu t'es arrêté.",
                matching: components
            )
        }

        if preferences.weeklyLeaderboard {
            var components = DateComponents()
            // Dimanche 18 h : la semaine Duello commence le lundi
            // (`WeeklyXP.weekKey`), le rappel invite donc à clore la semaine.
            components.weekday = 1
            components.hour = 18
            components.minute = 0
            await schedule(
                identifier: weeklyLeaderboardIdentifier,
                title: "Classement de la semaine",
                body: "Découvre où tu te situes avant la remise à zéro du lundi.",
                matching: components
            )
        }
    }

    /// Retire tous les rappels Duello (par exemple à la déconnexion).
    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: Interne

    /// Pose un rappel récurrent à partir de composants calendaires.
    private static func schedule(
        identifier: String,
        title: String,
        body: String,
        matching components: DateComponents
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Libellé français d'un état d'autorisation.
    static func statusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Autorisées"
        case .provisional: return "Autorisées (provisoires)"
        case .ephemeral: return "Autorisées (temporaires)"
        case .denied: return "Refusées par le système"
        case .notDetermined: return "En attente"
        @unknown default: return "Inconnues"
        }
    }

    /// Libellé court d'un état d'autorisation, pour les tuiles de statistique.
    static func statusShortLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "Accordée"
        case .denied: return "Refusée"
        case .notDetermined: return "En attente"
        @unknown default: return "—"
        }
    }

    /// Ton de pastille associé à un état d'autorisation.
    static func statusTone(_ status: UNAuthorizationStatus) -> DuelloPillTone {
        switch status {
        case .authorized, .provisional, .ephemeral: return .success
        case .denied: return .danger
        case .notDetermined: return .warning
        @unknown default: return .neutral
        }
    }
}

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

// MARK: - Pager d'explications

/// Pager d'explications « installé / pas installé ».
///
/// Là où l'app Expo glisse le pager des notifications dans un tiroir quand
/// l'application de bureau est installée (`InstalledNotificationsPager.tsx`),
/// la version iOS présente deux pages d'explication : le fonctionnement des
/// rappels locaux, puis l'état réel sur cet appareil (rappels installés ou
/// non). Tout tient dans une carte, sans navigation supplémentaire.
struct InstalledNotificationsPager: View {

    /// Store des préférences, pour connaître les rappels demandés.
    @ObservedObject var store: NotificationPreferencesStore

    @State private var page = 0
    @State private var authorization: UNAuthorizationStatus = .notDetermined

    /// Nombre de pages du pager.
    private let pageCount = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            TabView(selection: $page) {
                pagerPage(
                    icon: "bell.badge",
                    title: "Rappels locaux",
                    message: "Duello programme ses rappels sur ton iPhone via le "
                        + "centre de notifications d'iOS. Aucun serveur push "
                        + "distant n'intervient."
                )
                .tag(0)

                pagerPage(
                    icon: installed ? "checkmark.seal" : "bell.slash",
                    title: installed ? "Rappels installés" : "Pas encore installés",
                    message: installed
                        ? "Tes rappels sont programmés et se répéteront à l'heure choisie."
                        : "Active un rappel dans les réglages, puis autorise les "
                            + "notifications pour les recevoir."
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 176)
            pageDots
        }
        .duelloCard()
        .task { authorization = await LocalNotificationScheduler.authorizationStatus() }
    }

    /// En-tête : titre de section et pastille « installé / pas installé ».
    private var header: some View {
        HStack(spacing: 10) {
            DuelloSectionHeader(title: "Comment ça marche")
            DuelloPill(
                text: installed ? "Installé" : "Pas installé",
                tone: installed ? .success : .neutral,
                icon: installed ? "checkmark.seal" : "seal"
            )
        }
    }

    /// Vrai quand l'autorisation est accordée et qu'au moins un rappel
    /// récurrent est demandé : les rappels sont alors réellement installés.
    private var installed: Bool {
        let granted: Bool
        switch authorization {
        case .authorized, .provisional, .ephemeral: granted = true
        default: granted = false
        }
        return granted && store.preferences.wantsRecurringReminder
    }

    /// Une page d'explication, dans le cadre gris du thème.
    private func pagerPage(icon: String, title: String, message: String) -> some View {
        DuelloEmptyState(icon: icon, title: title, message: message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }

    /// Points de pagination, à la place de l'indicateur système masqué.
    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? Theme.ink : Theme.border)
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
