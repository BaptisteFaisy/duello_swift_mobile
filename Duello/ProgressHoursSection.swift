import SwiftUI

/// Onglet « Heures » de l'écran « Progression » : temps d'entraînement cumulé et
/// journées travaillées, puis une carte de temps par matière. Extension de
/// `DuelloProgressView` (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Heures

    @ViewBuilder
    var hoursSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                summaryBlock("Temps d’entraînement", progress.formattedTrainingTime())
                summaryBlock("Jours travaillés", "\(progress.activeDayCount())")
            }
        }
        .progressCard(padding: 18)
        .padding(.bottom, 20)

        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Temps par matière")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(subjects) { subject in
                    subjectTimeCard(subject)
                }
            }
        }
    }

    /// Grand chiffre légendé du résumé « Heures ».
    private func summaryBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Theme.inkSoft)
            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Carte du temps d'entraînement cumulé d'une matière.
    private func subjectTimeCard(_ subject: TrackSubject) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.primaryLight)
                    .frame(width: 38, height: 38)
                Image(systemName: "clock")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Temps d’entraînement cumulé")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer(minLength: 10)

            Text(ProgressStore.formatTrainingTime(minutes: progress.subjectMinutes[subject.name] ?? 0))
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.primary)
        }
        .progressCard()
    }
}
