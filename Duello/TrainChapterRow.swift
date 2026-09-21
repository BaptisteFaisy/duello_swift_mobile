import SwiftUI

/// Une ligne de chapitre : statut du cours, nom, avancement et résumé.
/// Reprend `ChapterRow` de `SubjectsScreen.tsx` en remplaçant l'ouverture plein
/// écran par un dépliage sur place.
struct TrainChapterRow: View {
    let chapter: TrackChapter
    let status: TrainCourseStatus
    /// Résumé accordé du chapitre (« 3/12 exercices réussis »…).
    let summaryText: String
    /// Dénominateur d'avancement ; 0 masque la barre et le résumé fort.
    let progressTotal: Int
    let progressFraction: Double
    let isExpanded: Bool
    let onToggleStatus: () -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleStatus) {
                Image(systemName: status.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(status.tint)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Statut cours — \(chapter.name)")
            .accessibilityValue(status.label)

            Button(action: onToggleExpanded) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(chapter.name)
                        .font(.system(size: 14, weight: status == .completed ? .bold : .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if progressTotal > 0 {
                        DuelloProgressTrack(fraction: progressFraction, height: 6)
                    }
                    Text(summaryText)
                        .font(.system(size: 11, weight: progressTotal > 0 ? .bold : .semibold))
                        .foregroundStyle(progressTotal > 0 ? Theme.inkSoft : Theme.inkFaint)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ouvrir les exercices — \(chapter.name)")

            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 12)
    }
}
