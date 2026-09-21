import SwiftUI

/// Onglet « Heures » de l'écran « Progression » : temps d'entraînement cumulé,
/// journées travaillées, puis temps de chaque matière du parcours. Extension de
/// `DuelloProgressView` (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Heures

    /// Temps d'entraînement cumulé, journées travaillées, puis temps de chaque
    /// matière du parcours (la section reste globale, comme côté Expo).
    @ViewBuilder
    var hoursSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                summaryBlock("Temps d'entraînement", progress.formattedTrainingTime())
                summaryBlock("Jours travaillés", "\(progress.activeDayCount())")
            }
        }
        .duelloCard()

        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Temps par matière")
            ForEach(subjects) { subject in
                subjectTimeRow(subject)
            }
        }
        .duelloCard()
    }

    /// Grand chiffre légendé du résumé « Heures ».
    private func summaryBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Temps d'entraînement cumulé d'une matière.
    private func subjectTimeRow(_ subject: TrackSubject) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.primaryLight)
                    .frame(width: 38, height: 38)
                Image(systemName: "clock")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Temps d'entraînement cumulé")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer(minLength: 10)

            Text(ProgressStore.formatTrainingTime(minutes: progress.subjectMinutes[subject.name] ?? 0))
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
        }
    }
}
