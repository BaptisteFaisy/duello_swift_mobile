//
//  PlanTaskListCard.swift
//  Duello
//
//  Écran « Plan » — liste des tâches : ligne, coche et report d'un jour.
//
import Foundation
import SwiftUI

// MARK: - Liste des tâches

/// Une tâche : coche, contenu, report d'un jour.
struct PlanTaskRow: View {
    let task: PlanTask
    let plannedLabel: String?
    let onToggle: () -> Void
    let onReport: () -> Void

    private var deadlineText: String {
        var parts: [String] = [task.subject]
        if let deadline = task.deadline, !deadline.isEmpty {
            parts.append("Pour \(deadline)")
        } else {
            parts.append("Sans échéance")
        }
        if task.postponedDays > 0 {
            parts.append(task.postponedDays > 1 ? "reportée de \(task.postponedDays) jours" : "reportée d'un jour")
        }
        return parts.joined(separator: " · ")
    }

    private var durationText: String {
        PlanDateEngine.formatDuration(task.estimatedDuration ?? 45)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(task.isDone ? Theme.progress : Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone ? "Marquer comme à faire" : "Marquer comme faite")

                DuelloListRow(
                    title: task.title,
                    subtitle: deadlineText,
                    icon: PlanSubjects.visual(for: task.subject).icon,
                    trailing: durationText,
                    showsChevron: false
                )

                if task.isDone {
                    DuelloPill(text: "Fait", tone: .success, icon: "checkmark")
                } else {
                    Button(action: onReport) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(6)
                            .background(Theme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reporter d'un jour")
                }
            }

            if let plannedLabel {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Prévue \(plannedLabel)")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.inkFaint)
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 4)
        .opacity(task.isDone ? 0.75 : 1)
    }
}

/// Liste des tâches, triée par urgence comme à l'ajout (ligne 180).
struct PlanTaskListCard: View {
    let tasks: [PlanTask]
    let plannedLabels: [String: String]
    let doneCount: Int
    let onToggle: (PlanTask) -> Void
    let onReport: (PlanTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DuelloSectionHeader(
                title: "Tâches",
                subtitle: "\(tasks.count) tâche(s) · \(doneCount) faite(s)"
            )

            if tasks.isEmpty {
                DuelloEmptyState(
                    icon: "checklist",
                    title: "Aucune tâche",
                    message: "Écris tes tâches en vrac : elles sont réparties automatiquement sur les jours du programme."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        PlanTaskRow(
                            task: task,
                            plannedLabel: plannedLabels[task.id],
                            onToggle: { onToggle(task) },
                            onReport: { onReport(task) }
                        )
                        if task.id != tasks.last?.id {
                            Divider().background(Theme.border)
                        }
                    }
                }
            }
        }
        .duelloCard()
    }
}
