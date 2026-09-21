import SwiftUI

// MARK: - Compte rendu

/// Compte rendu noté sur 20 : note, synthèse, points forts et axes de travail.
/// Extension de `AnnCopyCorrectionSheet`.
extension AnnCopyCorrectionSheet {
    func readyContent(job: AnnCopyJob, result: AnnCopyResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(job.partLabel)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(result.scoreLabel)
                        .font(.system(size: 38, weight: .black))
                    Text(" / 20")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundStyle(Theme.surface)
                Text("Note de cette partie, ramenée sur 20")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.surface)
                    .opacity(0.82)
                Text(LatexToUnicode.toUnicodeMath(result.summary))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.surface)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))

            if !result.strengths.isEmpty {
                resultSection(title: "Points forts", icon: "checkmark.circle", items: result.strengths)
            }
            if !result.improvements.isEmpty {
                resultSection(title: "À retravailler", icon: "wrench.and.screwdriver", items: result.improvements)
            }

            ForEach(result.exerciseFeedback) { exercise in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(exercise.label)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Text(exercise.scoreLabel)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.ink)
                    }
                    Text(LatexToUnicode.toUnicodeMath(exercise.feedback))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .duelloCard()
            }

            AnnOutlineButton(title: "Soumettre une autre partie", icon: "arrow.clockwise") {
                onNewAttempt()
            }
        }
    }

    private func resultSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            ForEach(items, id: \.self) { item in
                Text(LatexToUnicode.toUnicodeMath("• \(item)"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .duelloCard()
    }
}
