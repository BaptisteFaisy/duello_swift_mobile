//
//  CollCompletionViews.swift
//  Duello
//
//  Sous-vues du panneau de fin de colle : étapes, note, fiche de question,
//  champ multiligne et carte de correction.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ColleCompletionPanel.tsx
//        `stepHeading`, `scoreCard`, `questionCard`, `fieldLabel`, `gradeCard`.
//
//  Extrait de `CollCompletionPanel.swift` : contenu repris tel quel, seuls les
//  types deviennent internes au module (et portent le préfixe `Coll`).
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Étapes

/// Titre d'étape : numéro, titre et indication (`stepHeading`).
struct CollStepHeading: View {
    let number: Int
    let title: String
    let hint: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.surface)
                .frame(width: 25, height: 25)
                .background(Theme.ink)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(hint)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 5)
    }
}

// MARK: - Note de la colle

/// Carte de la note provisoire ou définitive (`scoreCard`).
struct CollScoreCard: View {
    let score: CollGradingScore
    let scoreOn20: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Note de la colle")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                Text(ExGFormat.score(scoreOn20) + (score.complete ? "" : "\u{00A0}· provisoire"))
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 8)
            Text("\(score.gradedQuestions)/\(score.totalQuestions) questions notées")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 62)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityLabel(
            "Note de la colle \(ExGFormat.score(scoreOn20))\(score.complete ? "" : ", provisoire")"
        )
    }
}

// MARK: - Question restante

/// Fiche d'une question restante : énoncé, réponse, correction et soumission.
struct CollQuestionCard: View {
    let index: Int
    let question: CollRemainingQuestion
    let grading: Bool
    let disabled: Bool
    let error: String?
    let onChangePrompt: (String) -> Void
    let onChangeAnswer: (String) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            fields
            submitButton
        }
        .padding(13)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// En-tête : numéro de la question et suppression.
    private var header: some View {
        HStack {
            Text("Question \(index + 1)")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Supprimer la question \(index + 1)")
        }
    }

    /// Champs de la question, erreur éventuelle et correction.
    @ViewBuilder
    private var fields: some View {
        CollFieldLabel(text: "ÉNONCÉ DE LA QUESTION")
        CollMultilineField(
            text: question.prompt,
            placeholder: "Recopie ici la question à terminer…",
            minHeight: 76,
            onChange: onChangePrompt
        )
        CollFieldLabel(text: "TA RÉPONSE")
        CollMultilineField(
            text: question.answer,
            placeholder: "Rédige ton raisonnement…",
            minHeight: 120,
            onChange: onChangeAnswer
        )
        if let error, !error.isEmpty {
            Text(error)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0xA82B2B))
                .fixedSize(horizontal: false, vertical: true)
        }
        if let grade = question.grade {
            CollGradeCard(grade: grade)
        }
    }

    /// Bouton de soumission à la correction.
    private var submitButton: some View {
        Button(action: onSubmit) {
            HStack(spacing: 8) {
                if grading {
                    ProgressView().progressViewStyle(.circular).tint(Theme.surface)
                }
                Text(grading ? "Correction en cours…"
                     : (question.grade != nil ? "Soumettre à nouveau" : "Soumettre à la correction"))
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 47)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .opacity(grading ? 0.65 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

/// Libellé de champ en capitales (`fieldLabel`).
struct CollFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 3)
    }
}

/// Champ multiligne avec indication de saisie, en remplacement du `TextInput`.
struct CollMultilineField: View {
    let text: String
    let placeholder: String
    let minHeight: CGFloat
    let onChange: (String) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
            }
            TextEditor(text: Binding(get: { text }, set: onChange))
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(minHeight: minHeight, alignment: .topLeading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// Correction d'une question : verdict, commentaire et corrigé (`gradeCard`).
struct CollGradeCard: View {
    let grade: CollMathGrade

    private var background: Color {
        switch grade.verdict {
        case .perfect: return Theme.gradingPerfectLightHex.color
        case .correct: return Color(hex: 0xDDF5E7)
        case .partial: return Color(hex: 0xFFF0C7)
        case .incorrect: return Color(hex: 0xFCE0E0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(grade.verdict.label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(grade.feedback)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("CORRIGÉ IA")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 12)
            Text(grade.correction)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
