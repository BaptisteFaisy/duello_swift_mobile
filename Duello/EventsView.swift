//
//  EventsView.swift
//  Duello
//
//  Liste des concours blancs de l'onglet « Événements » : chaque carte est
//  pressable, le bloc se grise à l'appui pour confirmer le geste, puis l'espace
//  événement prend tout l'écran — décompte, salle d'attente, épreuve, correction
//  ou classement selon le moment.
//
//  Fichier source Expo porté : `src/components/EventsList.tsx` (et sa carte
//  `EventCard`). L'espace événement est présenté ici en pleine page
//  (`fullScreenCover`) ; `onOpenEvent` est notifié au passage, comme
//  `ChallengesScreen.tsx` marque l'événement vu avant de l'ouvrir.
//
//  Icônes Ionicons : calendar-outline (38, état vide), time-outline (15),
//  location-outline (15), open-outline (14), chevron-forward (18), comme la
//  source — plus de substitution SF Symbol.
//
//  V1 (29/09/2026, écart 14#4) : la pastille de date des cartes passe au noir
//  `#000000` à libellés blancs (`EventsList.tsx:241-270`), au lieu de
//  `surfaceMuted` à libellés d'encre.
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit

struct EventsView: View {
    @EnvironmentObject private var session: SessionStore

    /// Remontée à l'écran parent : l'espace événement passe en pleine page.
    var onOpenEvent: ((EvEvent) -> Void)? = nil
    /// Identifiants déjà vus, pour la pastille « nouveau » de chaque carte ;
    /// `nil` tant que la liste n'est pas chargée (aucune pastille).
    var seenEventIds: [String]? = nil
    /// Ouvre le profil d'un participant depuis l'espace événement ; `nil` laisse
    /// les lignes inactives.
    var onOpenProfile: ((String) -> Void)? = nil

    @State private var openEvent: EvEvent?

    /// Événements visibles pour ce profil, triés par date.
    private var events: [EvEvent] {
        EvEventAudienceFilter.visibleEvents(EvEventCatalog.upcoming, profile: session.profile)
    }

    var body: some View {
        content
            .evEventReminders(events)
            .fullScreenCover(item: $openEvent) { event in
                EvEventWorkspace(
                    event: event,
                    email: session.profile.email,
                    token: session.token,
                    onBack: { openEvent = nil },
                    onOpenProfile: onOpenProfile
                )
            }
    }

    @ViewBuilder private var content: some View {
        let now = Date()
        if events.isEmpty {
            emptyState
        } else {
            // Instant commun des pastilles de statut : relu à chaque rendu.
            VStack(spacing: 12) {
                ForEach(events) { event in
                    EvEventCard(event: event, now: now, isNew: isNew(event)) { open(event) }
                }
            }
        }
    }

    /// État vide : cadre de 76×76, icône `calendar-outline` (38, encre) et titre.
    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .fill(Theme.surface)
                    .frame(width: 76, height: 76)
                IonIcon(name: "calendar-outline", size: 38, color: Theme.ink)
            }
            .padding(.bottom, 6)
            Text("Aucun événement à venir")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    /// Pastille « nouveau » : l'événement est visible mais jamais ouvert
    /// (`seenEventIds != null && !seenEventIds.includes(event.id)`).
    private func isNew(_ event: EvEvent) -> Bool {
        guard let seenEventIds else { return false }
        return !seenEventIds.contains(event.id)
    }

    /// Ouvre l'espace événement : prévient le parent (marque vu) puis l'affiche
    /// en pleine page ici.
    private func open(_ event: EvEvent) {
        onOpenEvent?(event)
        openEvent = event
    }
}

// MARK: - Carte d'événement

/// Carte pressable d'un événement : pastille de date, titre, description,
/// horaire, lieu et lien d'information (`EventCard`).
private struct EvEventCard: View {
    let event: EvEvent
    /// Instant commun des pastilles de statut.
    let now: Date
    /// Événement jamais ouvert : allume la pastille « nouveau » en coin.
    let isNew: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 14) {
                dateBadge
                cardBody
                    .frame(maxWidth: .infinity, alignment: .leading)
                // Réserve la largeur du chevron : la colonne reste centrée
                // verticalement sur la carte, comme `chevronColumn` de la source.
                Color.clear.frame(width: 18)
            }
            .padding(16)
            .contentShape(Rectangle())
            .overlay(alignment: .topTrailing) { newDot }
            .overlay(alignment: .trailing) {
                IonIcon(name: "chevron-forward", size: 18, color: Theme.inkFaint)
                    .padding(.trailing, 16)
            }
        }
        .buttonStyle(EvEventCardStyle())
        .accessibilityLabel(
            isNew
                ? "\(event.title) — nouvel événement — ouvrir l'événement"
                : "\(event.title) — ouvrir l'événement"
        )
    }

    /// Pastille « nouveau » en coin (`styles.newDot` : 8×8, r4, top/right 10).
    @ViewBuilder private var newDot: some View {
        if isNew {
            Circle()
                .fill(Theme.ink)
                .frame(width: 8, height: 8)
                .padding(10)
                .accessibilityLabel("Nouvel événement")
        }
    }

    /// Pastille de date à la manière d'un agenda papier : fond noir `#000000`,
    /// les trois libellés en blanc (`EventsList.tsx:241-270`).
    private var dateBadge: some View {
        VStack(spacing: 1) {
            Text(EvEventDateFormatting.weekdayLabel(event.date))
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
            Text("\(EvEventDateFormatting.dayNumber(event.date))")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
            Text(EvEventDateFormatting.monthLabel(event.date))
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(.white)
        }
        .frame(width: 54)
        .frame(minHeight: 58)
        .padding(.vertical, 5)
        .background(Color(hex: 0x000000))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }

    /// Corps de la carte : pastille de statut, titre, description, méta et lien.
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let status = EvEventSchedule.statusBadge(event, now: now) {
                EvEventStatusBadge(status: status)
                    .padding(.bottom, 6)
            }
            Text(event.title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let description = event.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            metaRow
            linkRow
        }
    }

    /// Horaire et lieu de l'événement, affichés seulement s'ils existent.
    @ViewBuilder private var metaRow: some View {
        if EvEventDateFormatting.timeRange(event) != nil || event.location != nil {
            HStack(spacing: 12) {
                if let range = EvEventDateFormatting.timeRange(event) {
                    HStack(spacing: 5) {
                        IonIcon(name: "time-outline", size: 15, color: Theme.inkFaint)
                        Text(range)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                if let location = event.location {
                    HStack(spacing: 5) {
                        IonIcon(name: "location-outline", size: 15, color: Theme.inkFaint)
                        Text(location)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .padding(.top, 9)
        }
    }

    /// Lien « Plus d'informations », ouvert dans le navigateur du système.
    @ViewBuilder private var linkRow: some View {
        if let raw = event.linkUrl, let url = URL(string: raw) {
            Button { UIApplication.shared.open(url) } label: {
                HStack(spacing: 6) {
                    Text("Plus d'informations")
                        .font(.system(size: 13, weight: .heavy))
                        .underline()
                        .foregroundStyle(Theme.ink)
                    IonIcon(name: "open-outline", size: 14, color: Theme.inkSoft)
                }
                .padding(.top, 10)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(event.title) — plus d'informations")
        }
    }
}

/// Carte à bord fin qui se grise à l'appui (`cardPressed`).
private struct EvEventCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.surfaceMuted : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
