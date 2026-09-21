import SwiftUI

/// Une fiche d'exercice : numéro dans le chapitre, pastille de difficulté,
/// titre, marque de corrigé et avancement personnel. Reprend la fiche
/// `ExerciseItemCard` de `SubjectsScreen.tsx`.
///
/// Écart assumé : Expo masque le titre dans les listes (`showsItemTitles =
/// false`) parce que la fiche y sert de vignette de grille et que l'énoncé
/// s'ouvre ailleurs. Sans lecteur d'énoncé ici, la fiche garde le titre du sujet
/// — il vient du serveur et sert aussi de libellé d'accessibilité.
struct TrainExerciseCard: View {
    let exercise: TrainExercise
    /// Position affichée dans le chapitre (« Sujet n »).
    let number: Int
    let fraction: Double
    let hasProgress: Bool

    private var percentage: Int { Int((min(1, max(0, fraction)) * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityLabel("Sujet \(number)")
                if let level = exercise.difficulty, TrainDifficulty.order.contains(level) {
                    TrainDifficultyPill(level: level, showsLabel: false)
                }
                Spacer(minLength: 8)
                if exercise.hasSolution {
                    DuelloPill(text: "Corrigé", tone: .success, icon: "checkmark.circle")
                }
            }
            Text(exercise.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
            if hasProgress {
                HStack(spacing: 8) {
                    DuelloProgressTrack(fraction: fraction, height: 6)
                    Text("\(percentage) %")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.inkSoft)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Avancement : \(percentage) %")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }
}
