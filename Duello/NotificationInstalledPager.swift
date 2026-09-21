import Foundation
import SwiftUI
import UserNotifications

// Découpage par responsabilité (fichiers de ce module) :
// `NotificationPreferences.swift`, `NotificationScheduler.swift`,
// `NotificationSettingsCard.swift`, `NotificationInstalledPager.swift`.

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
