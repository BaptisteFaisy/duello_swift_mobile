import SwiftUI

/// En-tête de l'écran « Progression » : sélecteur de matière puis résumé
/// compact de la matière affichée. Extension de `DuelloProgressView` (voir
/// `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Sélecteur de matière

    var subjectPickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Matière")

            Picker("Matière", selection: subjectSelection) {
                ForEach(subjects) { subject in
                    Text(subject.name).tag(subject.id)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let fullName = selectedSubject?.fullName {
                Text(fullName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .duelloCard()
    }

    // MARK: Résumé compact

    /// Résumé de la matière choisie : les trois lignes compactes de l'écran
    /// Expo, une par type de travail.
    var summaryCard: some View {
        let exercises = trainingStat(kind: .exercises)
        let colles = trainingStat(kind: .colles)
        let challenges = duelStat

        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Résumé")

            EmbeddedMetric(
                label: "Exercices",
                value: exercises.total > 0
                    ? "\(exercises.mastered)/\(exercises.total) maîtrisés"
                    : "Contenu à venir",
                progress: exercises.fraction
            )
            EmbeddedMetric(
                label: "Colles",
                value: colles.total > 0
                    ? "\(colles.mastered)/\(colles.total) maîtrisées"
                    : "Contenu à venir",
                progress: colles.fraction
            )
            EmbeddedMetric(
                label: "Défis",
                value: "\(challenges.won)/\(challenges.played) gagnés · \(selectedElo) Elo",
                progress: challenges.fraction
            )
        }
        .duelloCard()
    }
}
