//
//  SubjTrainingWorkflow.swift
//  Duello
//
//  Lot 9-B « guide du parcours » (préfixe `Subj`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (`TRAINING_WORKFLOW_ACCESSIBILITY_LABEL`,
//      `TrainingWorkflowIcons`, `TrainingWorkflowGuide`,
//      styles `trainingWorkflow*` et `legendTitle`)
//
//  Rappel des trois temps d'un entraînement : rédaction sur feuille → photo →
//  correction. Aucune donnée : la suite d'étapes est fixe. Cible iOS 16.
//
import SwiftUI

/// Titre du guide (`styles.legendTitle` → « Exercice »).
private let subjWorkflowTitle = "Exercice"

/// Une étape du parcours : libellé affiché, icône SF, teinte.
///
/// Les icônes `Ionicons` de la source sont transposées en SF Symbols
/// (`create-outline` → `square.and.pencil`, `camera-outline` → `camera`,
/// `checkmark-circle-outline` → `checkmark.circle`).
struct SubjWorkflowStep: Identifiable {
    let id: String
    /// Libellé, retour à la ligne compris (`numberOfLines={2}` dans la source).
    let label: String
    let icon: String
    let tint: Color
}

/// Constantes du parcours d'entraînement (`TrainingWorkflowIcons`).
enum SubjTrainingWorkflow {
    /// Libellé d'accessibilité de la frise entière (repris mot pour mot).
    static let accessibilityLabel =
        "Conseil : rédaction sur feuille, photo, puis correction"

    /// Identifiant de l'étape finale, mise en avant dans la frise.
    static let correctionStepId = "correction"

    /// Les trois étapes, dans l'ordre de la source.
    static let steps: [SubjWorkflowStep] = [
        SubjWorkflowStep(
            id: "redaction",
            label: "Rédaction\nsur feuille",
            icon: "square.and.pencil",
            tint: Theme.primary
        ),
        SubjWorkflowStep(
            id: "photo",
            label: "Photo",
            icon: "camera",
            tint: Theme.primary
        ),
        SubjWorkflowStep(
            id: correctionStepId,
            label: "Correction",
            icon: "checkmark.circle",
            // Le vert commun de réussite (`colors.mastery`) signale la
            // correction, comme `TrainCourseStatus.completed`.
            tint: Theme.progress
        ),
    ]
}

/// `TrainingWorkflowIcons` de `src/screens/SubjectsScreen.tsx` : frise
/// icône + libellé, flèches entre les étapes, lue d'un bloc par VoiceOver.
struct SubjTrainingWorkflowIcons: View {
    /// Version réduite, utilisée dans le guide.
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(SubjTrainingWorkflow.steps) { step in
                if step.id != SubjTrainingWorkflow.steps.first?.id {
                    arrow
                }
                stepView(step)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SubjTrainingWorkflow.accessibilityLabel)
    }

    /// Une étape : icône encadrée (38 pt, 34 pt en compact) puis libellé sur
    /// deux lignes au plus.
    private func stepView(_ step: SubjWorkflowStep) -> some View {
        let isCorrection = step.id == SubjTrainingWorkflow.correctionStepId
        return VStack(spacing: 0) {
            Image(systemName: step.icon)
                .font(.system(size: compact ? 18 : 23))
                .foregroundStyle(step.tint)
                .frame(width: compact ? 34 : 38, height: compact ? 34 : 38)
                .background(
                    RoundedRectangle(cornerRadius: compact ? 11 : 13)
                        .fill(Theme.primaryLight)
                )
            Text(step.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 5)
        }
        // La correction est légèrement plus étroite et décalée vers la droite.
        .frame(maxWidth: isCorrection ? 60 : 64)
        .offset(x: isCorrection ? 5 : 0)
    }

    /// Flèche de liaison (`arrow-forward`), alignée sur le haut de l'icône.
    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: compact ? 13 : 16))
            .foregroundStyle(Theme.inkFaint)
            .padding(.top, 11)
    }
}

/// `TrainingWorkflowGuide` de `src/screens/SubjectsScreen.tsx` : titre
/// « Exercice » et frise compacte, séparés du contenu par un filet.
struct SubjTrainingWorkflowGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DuelloSectionHeader(title: subjWorkflowTitle)
            SubjTrainingWorkflowIcons(compact: true)
                .padding(.top, 8)
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .padding(.top, 18)
    }
}
