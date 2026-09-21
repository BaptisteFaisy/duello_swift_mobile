import SwiftUI

/// Cartes d'exercices et de questions du panneau « Mon TD »
/// (`TdExerciseCard` de `src/components/CourseTdPanel.tsx`).
///
/// Les énoncés portent du LaTeX : ils passent par `LatexToUnicode`, comme les
/// autres écrans portés (`MathStatementText` côté Expo).

// MARK: - Exercice

/// Exercice dépliable : titre, nombre de questions, énoncé et questions.
struct CtdExerciseCard: View {
    let exercise: CtdExercise

    @State private var open = false

    var body: some View {
        VStack(spacing: 0) {
            Button { open.toggle() } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.title)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.ink)
                        Text(questionLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(13)
                .frame(minHeight: 62)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(exercise.title)

            if open {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LatexToUnicode.toUnicodeMath(exercise.statement))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    ForEach(exercise.questions) { question in
                        CtdQuestionCard(question: question)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 0, leading: 13, bottom: 13, trailing: 13))
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// « 1 question » / « 3 questions ».
    private var questionLabel: String {
        let count = exercise.questions.count
        return "\(count) question\(count > 1 ? "s" : "")"
    }
}

// MARK: - Question

/// Question indexée : libellé, difficulté, énoncé, théorèmes et hypothèses
/// (`questionCard`).
struct CtdQuestionCard: View {
    let question: CtdQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(question.label)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                CtdDifficultyDots(level: question.difficulty)
            }
            Text(LatexToUnicode.toUnicodeMath(question.text))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.ink)
            if !question.theorems.isEmpty {
                CtdIndexBlock(label: "THÉORÈMES ASSOCIÉS", lines: question.theorems, latex: false)
            }
            if !question.hypotheses.isEmpty {
                CtdIndexBlock(label: "HYPOTHÈSES À REPÉRER", lines: question.hypotheses, latex: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}

/// Difficulté d'une question, de 1 à 5 pastilles pleines
/// (`difficultyDot` / `difficultyDotFilled`).
struct CtdDifficultyDots: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { step in
                Circle()
                    .fill(step <= level ? Theme.ink : Theme.border)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Difficulté \(level) sur 5")
    }
}

/// Bloc d'indexation d'une question : une puce par entrée (`indexBlock`).
struct CtdIndexBlock: View {
    let label: String
    let lines: [String]
    /// Vrai pour les hypothèses : côté Expo elles passent par
    /// `MathStatementText`, donc par la conversion LaTeX → Unicode ici.
    let latex: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .kerning(0.4)
                .foregroundStyle(Theme.inkSoft)
            ForEach(Array(lines.enumerated()), id: \.offset) { pair in
                Text(text(for: pair.element))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func text(for line: String) -> String {
        let bullet = "• \(line)"
        return latex ? LatexToUnicode.toUnicodeMath(bullet) : bullet
    }
}
