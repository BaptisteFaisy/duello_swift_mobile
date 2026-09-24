//
//  AdmUsageAnalyticsStore+Writes.swift
//  Duello
//
//  Trois des six écritures du journal d'usage : action métier, appui de bouton
//  et exercice (ouverture ou fin). Complète `AdmUsageAnalyticsStore.swift`.
//
//  Fichier source Expo porté (règles et libellés repris mot pour mot) :
//    - src/utils/usageAnalytics.ts
//        `recordUsageAction`, `recordButtonClick`, `recordExerciseUsage`,
//        `ExerciseUsageDetails`, et la table de libellés
//        (« Exercice terminé », « Défi terminé », « Cours mis à jour »,
//         « Feedback envoyé », « Exercice ouvert »).
//
//  Note (limite assumée, 24/09/2026) : `ExerciseUsageDetails['page']` est restreint par la
//  source à `'training' | 'journey'` ; le portage accepte les quatre pages et
//  laisse l'appelant respecter la restriction.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import Foundation

/// `ExerciseUsageDetails` : détails d'un usage d'exercice.
struct AdmExerciseUsageDetails {
    /// La source restreint à `'training' | 'journey'`.
    var page: AdmUsagePage
    var exerciseId: String
    var exerciseTitle: String?
    var subject: String?
    var section: String?
    var outcome: AdmUsageEventOutcome
    var durationSeconds: Double?
}

extension AdmUsageAnalyticsStore {
    /// `recordUsageAction` : compte une action métier et journalise l'événement.
    func recordUsageAction(
        action: AdmUsageActionKind,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) async -> AdmUsageJournal {
        await mutate(now: now) { current, day in
            var next = current
            next.lastSeenAt = AdmUsageRules.iso(now)
            next.actions[action] += 1
            next.events = AdmUsageJournal.appendingEvent(
                next.events,
                .make(kind: .action, page: Self.usagePage(for: action),
                      label: Self.actionLabel(for: action), now: now)
            )
            var updatedDay = day
            updatedDay.actions[action] += 1
            next.daily.append(updatedDay)
            return next
        }
    }

    /// `recordButtonClick` : journalise un appui de bouton, sans compter de visite.
    func recordButtonClick(
        page: AdmUsagePage,
        label: String,
        section: String,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) async -> AdmUsageJournal {
        await mutate(now: now) { current, day in
            var next = current
            next.lastSeenAt = AdmUsageRules.iso(now)
            next.events = AdmUsageJournal.appendingEvent(
                next.events,
                .make(kind: .buttonClick, page: page, label: label, section: section, now: now)
            )
            next.daily.append(day)
            return next
        }
    }

    /// `recordExerciseUsage` : journalise l'ouverture ou la fin d'un exercice ;
    /// une fin compte aussi une action `exercise_completed`.
    func recordExerciseUsage(
        details: AdmExerciseUsageDetails,
        now: Double = Date().timeIntervalSince1970 * 1000
    ) async -> AdmUsageJournal {
        await mutate(now: now) { current, day in
            let completed = details.outcome != .opened
            var next = current
            next.lastSeenAt = AdmUsageRules.iso(now)
            if completed { next.actions.exerciseCompleted += 1 }
            next.events = AdmUsageJournal.appendingEvent(
                next.events,
                .make(
                    kind: .exercise,
                    page: details.page,
                    label: completed ? "Exercice terminé" : "Exercice ouvert",
                    section: details.section,
                    exerciseId: details.exerciseId,
                    exerciseTitle: details.exerciseTitle,
                    subject: details.subject,
                    outcome: details.outcome,
                    durationSeconds: details.durationSeconds,
                    now: now
                )
            )
            var updatedDay = day
            if completed { updatedDay.actions.exerciseCompleted += 1 }
            next.daily.append(updatedDay)
            return next
        }
    }

    /// Page rattachée à une action (défi → défis, feedback → compte, reste → entraînement).
    static func usagePage(for action: AdmUsageActionKind) -> AdmUsagePage {
        switch action {
        case .challengeCompleted: return .challenges
        case .feedbackSent: return .account
        default: return .training
        }
    }

    /// Libellé de l'événement d'une action.
    static func actionLabel(for action: AdmUsageActionKind) -> String {
        switch action {
        case .exerciseCompleted: return "Exercice terminé"
        case .challengeCompleted: return "Défi terminé"
        case .courseUpdated: return "Cours mis à jour"
        case .feedbackSent: return "Feedback envoyé"
        }
    }
}
