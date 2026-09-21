import SwiftUI

// Réglages des notifications poussées.
//
// Sources Expo portées : `src/components/NotificationSettingsCard.tsx` (forme
// de la carte), `src/utils/notificationPolicy.ts` (statuts et libellés) et
// `src/components/PushNotificationCoordinator.tsx` (coordination pilotée ici).
//
// Réutilise `Theme`, `.duelloCard()` et `DuelloUI.swift`. Aucun type existant
// n'est redéfini : la carte s'appuie sur `PushNotifCoordinator` (portable) et
// sur ses types de politique. La limite de portée est affichée en clair.

// MARK: - Carte de réglages

/// Carte de réglages des notifications poussées : statut, explication,
/// statistiques et actions.
struct PushNotifSettingsView: View {

    /// Coordinateur, injecté par l'écran hôte.
    @ObservedObject var coordinator: PushNotifCoordinator
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusRow
            explanation
            stats
            actions
        }
        .duelloCard()
        .task { await coordinator.synchronize() }
    }

    // MARK: En-tête et état

    /// Titre de la carte, sur le motif « icône + titre » d'Expo.
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 28)
            DuelloSectionHeader(
                title: "Notifications poussées",
                subtitle: "Alertes envoyées par le serveur Duello"
            )
        }
    }

    /// Pastille de statut et raccourci vers les réglages iOS si refusé.
    private var statusRow: some View {
        HStack(spacing: 10) {
            DuelloPill(text: coordinator.status.label, tone: tone, icon: statusIcon)
            Spacer(minLength: 8)
            if coordinator.permission == .denied {
                Button("Réglages iOS") { openSystemSettings() }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    /// Icône de la pastille, selon le statut agrégé.
    private var statusIcon: String {
        switch coordinator.status {
        case .active: return "bell.fill"
        case .blocked: return "bell.slash"
        case .pending: return "bell"
        default: return "bell.slash"
        }
    }

    /// Ton de la pastille, selon le statut agrégé.
    private var tone: DuelloPillTone {
        switch coordinator.status {
        case .active: return .success
        case .blocked: return .danger
        case .pending: return .warning
        default: return .neutral
        }
    }

    // MARK: Explication

    /// Note de portée : ce que couvrent les notifications poussées.
    private var explanation: some View {
        Text(
            "Duello inscrit ce téléphone auprès du serveur : les alertes "
            + "(nouvel abonné, invitation de défi, défi indisponible) arrivent "
            + "même quand l'application est fermée. Le jeton d'appareil est "
            + "envoyé au serveur, puis révoqué à la déconnexion."
        )
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Theme.inkSoft)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Statistiques

    /// Jeton courant, nombre de jetons suivis, permission et erreur éventuelle.
    private var stats: some View {
        VStack(spacing: 8) {
            DuelloInfoRow(label: "Jeton d'appareil", value: tokenLabel)
            HStack(spacing: 10) {
                DuelloStatTile(label: "Jetons suivis", value: "\(coordinator.trackedTokenCount)")
                DuelloStatTile(label: "Permission", value: permissionLabel)
            }
            if let lastError = coordinator.lastError {
                Text(lastError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.like)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Actions

    /// Bouton principal (autoriser ou resynchroniser) et accès aux réglages.
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

    /// Libellé du bouton principal, selon la permission.
    private var primaryButtonTitle: String {
        switch coordinator.permission {
        case .denied: return "Ouvrir les réglages iOS"
        case .granted: return "Resynchroniser le jeton"
        default: return "Autoriser les notifications"
        }
    }

    /// Jeton abrégé (10 derniers caractères) pour l'affichage.
    private var tokenLabel: String {
        guard let token = coordinator.currentToken, !token.isEmpty else { return "—" }
        return token.count > 10 ? "…" + token.suffix(10) : token
    }

    /// Libellé court de la permission, aligné sur les tuiles de la carte locale.
    private var permissionLabel: String {
        switch coordinator.permission {
        case .granted: return "Accordée"
        case .denied: return "Refusée"
        case .undetermined: return "En attente"
        case .unsupported: return "Non disponible"
        }
    }

    // MARK: Effets

    /// Action du bouton principal : ouvrir les réglages si refusé, sinon
    /// demander la permission et resynchroniser le jeton.
    @MainActor
    private func primaryAction() async {
        busy = true
        if coordinator.permission == .denied {
            openSystemSettings()
        } else {
            await coordinator.synchronize()
        }
        busy = false
    }

    /// Ouvre la page de réglages iOS de l'application.
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
