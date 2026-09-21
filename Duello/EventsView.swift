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
//  `EventCard`). L'espace événement est ici présenté en pleine page
//  (`fullScreenCover`) quand aucun parent ne l'héberge ; un parent peut aussi le
//  prendre en charge via `onOpenEvent`, comme `ChallengesScreen.tsx`.
//
//  Substitutions SF Symbols (Ionicons → SF Symbols) : calendar-outline →
//  calendar ; time-outline → clock ; location-outline → mappin.and.ellipse ;
//  open-outline → arrow.up.right.square ; chevron-forward → chevron.right.
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit

struct EventsView: View {
    @EnvironmentObject private var session: SessionStore

    /// Remontée à l'écran parent : l'espace événement passe en pleine page.
    var onOpenEvent: ((EvEvent) -> Void)? = nil

    @State private var openEvent: EvEvent?

    /// Événements visibles pour ce profil, triés par date.
    private var events: [EvEvent] {
        EvEventAudienceFilter.visibleEvents(EvEventCatalog.upcoming, profile: session.profile)
    }

    var body: some View {
        content
            .fullScreenCover(item: $openEvent) { event in
                EvEventWorkspace(
                    event: event,
                    email: session.profile.email,
                    token: session.token,
                    onBack: { openEvent = nil }
                )
            }
    }

    @ViewBuilder private var content: some View {
        if events.isEmpty {
            DuelloEmptyState(icon: "calendar", title: "Aucun événement à venir")
        } else {
            VStack(spacing: 12) {
                ForEach(events) { event in
                    EvEventCard(event: event) { open(event) }
                }
            }
        }
    }

    /// Ouvre l'espace événement : chez le parent s'il l'héberge, ici sinon.
    private func open(_ event: EvEvent) {
        if let onOpenEvent {
            onOpenEvent(event)
        } else {
            openEvent = event
        }
    }
}

// MARK: - Carte d'événement

/// Carte pressable d'un événement : pastille de date, titre, description,
/// horaire, lieu et lien d'information (`EventCard`).
private struct EvEventCard: View {
    let event: EvEvent
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 14) {
                dateBadge
                VStack(alignment: .leading, spacing: 0) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 2)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(EvEventCardStyle())
        .accessibilityLabel("\(event.title) — ouvrir l'événement")
    }

    /// Pastille de date à la manière d'un agenda papier.
    private var dateBadge: some View {
        VStack(spacing: 1) {
            Text(EvEventDateFormatting.weekdayLabel(event.date))
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            Text("\(EvEventDateFormatting.dayNumber(event.date))")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(EvEventDateFormatting.monthLabel(event.date))
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(width: 54)
        .frame(minHeight: 58)
        .padding(.vertical, 5)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }

    /// Horaire et lieu de l'événement, affichés seulement s'ils existent.
    @ViewBuilder private var metaRow: some View {
        if EvEventDateFormatting.timeRange(event) != nil || event.location != nil {
            HStack(spacing: 12) {
                if let range = EvEventDateFormatting.timeRange(event) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                        Text(range)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                if let location = event.location {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
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
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.top, 10)
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
