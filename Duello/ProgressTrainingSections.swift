import SwiftUI

/// Onglets « Exercices » et « Colles » de l'écran « Progression » : une carte
/// par matière affichée (avancement, « X réussi(s) sur Y » et tentatives), ou
/// l'invitation à choisir au moins une matière. Extension de
/// `DuelloProgressView` (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Exercices et colles

    /// Une carte par matière visible pour un type d'entraînement, ou l'état vide
    /// de l'onglet quand aucune matière n'est cochée.
    @ViewBuilder
    func trainingSection(_ kind: ProgressItemKind) -> some View {
        if activeSubjectNames.isEmpty {
            noSubjectSelectedState
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(visibleSubjects) { subject in
                    trainingCard(subject, kind: kind)
                }
            }
        }
    }

    /// Carte d'une matière : nom, `maîtrisés/total`, barre, puis la ligne de
    /// métadonnées « X réussi(s) sur Y » (gauche) et « N tentative(s) » (droite).
    private func trainingCard(_ subject: TrackSubject, kind: ProgressItemKind) -> some View {
        let stat = trainingStat(for: subject, kind: kind)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(subject.name)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 10)
                Text(stat.total > 0 ? "\(stat.mastered)/\(stat.total)" : "À venir")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.primary)
            }

            ProgressBar(fraction: stat.fraction)
                .padding(.bottom, 2)

            HStack(alignment: .center, spacing: 10) {
                Text(trainingCounts(stat))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 10)
                Text("\(stat.attempts) tentative\(agreement(stat.attempts))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .progressCard()
    }

    /// « X réussi(s) sur Y », ou l'annonce d'une matière sans sujet servi.
    private func trainingCounts(_ stat: TrainingStat) -> String {
        guard stat.total > 0 else { return "Aucun sujet disponible pour le moment" }
        return "\(stat.mastered) réussi\(agreement(stat.mastered)) sur \(stat.total)"
    }
}

// MARK: - Types des cartes d'entraînement

/// Nature d'item suivie par une carte d'entraînement : `chapterItems` (Expo)
/// distingue les exercices des colles ; les deux banques sont ici servies par
/// `DuelloExerciseCatalog` (exercices) et `ProgressColleSocle` (colles).
enum ProgressItemKind {
    case exercises
    case colles
}
