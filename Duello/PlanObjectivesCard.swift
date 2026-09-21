//
//  PlanObjectivesCard.swift
//  Duello
//
//  Écran « Plan » — carte « Objectifs du jour », pendant accessible de la grille.
//
import Foundation
import SwiftUI

// MARK: - Objectifs du jour

/// Récapitulatif du jour affiché : blocs, temps prévu, avancement, puis la
/// liste des séances. La grille seule ne se lit pas au lecteur d'écran : cette
/// liste est le pendant accessible de `renderDayPage`.
struct PlanObjectivesCard: View {
    let day: PlanDay
    let sessions: [PlanSession]
    let onSelect: (PlanSession) -> Void

    private var plannedMinutes: Int { sessions.reduce(0) { $0 + $1.durationMinutes } }
    private var doneCount: Int { sessions.filter { $0.isDone }.count }

    var body: some View {
        let fraction: Double? = sessions.isEmpty ? nil : Double(doneCount) / Double(sessions.count)

        VStack(alignment: .leading, spacing: 12) {
            DuelloSectionHeader(
                title: "Objectifs du jour",
                subtitle: day.dayOffset == 0
                    ? "Aujourd'hui"
                    : "\(PlanTaskAnalyzer.capitalize(day.dayLabel)) \(day.fullLabel)"
            )

            HStack(spacing: 10) {
                DuelloStatTile(label: "Blocs", value: "\(sessions.count)")
                DuelloStatTile(label: "Temps prévu", value: PlanDateEngine.formatDuration(plannedMinutes))
                DuelloStatTile(
                    label: "Faites",
                    value: "\(doneCount)/\(sessions.count)",
                    fraction: fraction
                )
            }

            if sessions.isEmpty {
                DuelloEmptyState(
                    icon: "calendar",
                    title: "Rien de prévu",
                    message: "Ajoute une tâche : elle sera placée sur un créneau libre de la journée."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        Button {
                            onSelect(session)
                        } label: {
                            DuelloListRow(
                                title: session.title,
                                subtitle: "\(session.startTime)–\(session.endTime) · \(session.subtitle)",
                                icon: session.icon,
                                trailing: PlanDateEngine.formatDuration(session.durationMinutes),
                                showsChevron: true
                            )
                            .opacity(session.isDone ? 0.5 : 1)
                        }
                        .buttonStyle(.plain)
                        if session.id != sessions.last?.id {
                            Divider().background(Theme.border)
                        }
                    }
                }
            }
        }
        .duelloCard()
    }
}
