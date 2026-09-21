import SwiftUI

/// Onglets « Exercices » et « Colles » de l'écran « Progression » : carte de la
/// matière affichée puis détail chapitre par chapitre. Extension de
/// `DuelloProgressView` (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Exercices et colles

    /// Carte de la matière pour un type d'entraînement, puis détail par chapitre.
    @ViewBuilder
    func trainingSection(_ kind: ProgressItemKind) -> some View {
        let stat = trainingStat(kind: kind)
        trainingCard(stat)
        chapterList(kind)
    }

    private func trainingCard(_ stat: TrainingStat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(selectedSubject?.name ?? "Matière")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 10)
                Text(stat.total > 0 ? "\(stat.mastered)/\(stat.total)" : "À venir")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.ink)
            }

            ProgressBar(fraction: stat.fraction)

            Text(trainingSummary(stat))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .duelloCard()
    }

    /// Métriques de la carte d'entraînement : maîtrisés, tentés, tentatives.
    private func trainingSummary(_ stat: TrainingStat) -> String {
        guard stat.total > 0 else { return "Aucun sujet disponible pour le moment" }

        let mastered = "\(stat.mastered) réussi\(agreement(stat.mastered)) sur \(stat.total)"
        let attempted = "\(stat.attempted) tenté\(agreement(stat.attempted))"
        let attempts = "\(stat.attempts) tentative\(agreement(stat.attempts))"
        return [mastered, attempted, attempts].joined(separator: " · ")
    }

    /// Avancement chapitre par chapitre, limité aux chapitres servis.
    @ViewBuilder
    private func chapterList(_ kind: ProgressItemKind) -> some View {
        let chapters = chapterProgress(kind)
        if !chapters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Par chapitre")
                ForEach(chapters) { chapter in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(chapter.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            Spacer(minLength: 10)
                            Text("\(chapter.stat.mastered)/\(chapter.stat.total)")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        ProgressBar(fraction: chapter.stat.fraction, height: 4)
                    }
                }
            }
            .duelloCard()
        }
    }

    /// Avancement de chaque chapitre dont la banque n'est pas vide.
    private func chapterProgress(_ kind: ProgressItemKind) -> [ChapterProgress] {
        guard kind == .exercises, let subject = selectedSubject else { return [] }

        let pool = itemPool
        return subject.chapters.compactMap { chapter -> ChapterProgress? in
            guard let ids = pool["\(subject.id):\(chapter.id)"], !ids.isEmpty else {
                return nil
            }
            return ChapterProgress(
                id: chapter.id,
                name: chapter.name,
                stat: progress.trainingStat(forItemIds: ids)
            )
        }
    }
}

// MARK: - Types des cartes d'entraînement

/// Nature d'item suivie par une carte d'entraînement : `chapterItems` (Expo)
/// distingue les exercices des colles, mais seule la banque d'exercices est
/// portée par cette version.
enum ProgressItemKind {
    case exercises
    case colles
}

/// Avancement d'un chapitre de la matière affichée.
private struct ChapterProgress: Identifiable {
    let id: String
    let name: String
    let stat: TrainingStat
}
