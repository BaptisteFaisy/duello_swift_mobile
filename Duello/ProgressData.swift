import SwiftUI

/// Lecture des données de l'écran « Progression » : parcours de l'élève,
/// banque d'items réellement servie, avancement, défis et cote Elo. Extension
/// de `DuelloProgressView` — membres partagés par l'en-tête et les quatre
/// onglets (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Données

    /// Matières du parcours choisi, dans l'ordre de l'app Expo.
    var subjects: [TrackSubject] {
        DuelloProgram.subjects(
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: session.profile.year
        )
    }

    /// Matière affichée : le choix de l'élève, ou la première du parcours.
    var selectedSubject: TrackSubject? {
        subjects.first { $0.id == selectedSubjectId } ?? subjects.first
    }

    /// Sélection du menu de matières. Le getter repasse par `selectedSubject` :
    /// quand le parcours change, l'écran retombe sur une matière qui existe.
    var subjectSelection: Binding<String> {
        Binding(
            get: { selectedSubject?.id ?? "" },
            set: { selectedSubjectId = $0 }
        )
    }

    /// Banque d'items servie pour ce profil, repliée en `matière:chapitre`. Les
    /// clés du catalogue sont `<année>:<matière>:<chapitre>` : une année 2 porte
    /// les banques des deux années, on réunit donc les chapitres homonymes.
    var itemPool: [String: [String]] {
        var merged: [String: Set<String>] = [:]
        for (key, ids) in DuelloExerciseCatalog.forProfile(session.profile) {
            let parts = key.split(separator: ":", maxSplits: 2)
            guard parts.count == 3 else { continue }
            merged["\(parts[1]):\(parts[2])", default: []].formUnion(ids)
        }
        return merged.mapValues { $0.sorted() }
    }

    /// Items servis pour toute la matière, tous chapitres confondus.
    private func itemIds(for subject: TrackSubject, kind: ProgressItemKind) -> [String] {
        // Aucune banque de colles n'est portée : la matière reste à zéro et
        // l'écran annonce « Contenu à venir », comme Expo sans items servis.
        guard kind == .exercises else { return [] }

        let pool = itemPool
        var ids = Set<String>()
        for chapter in subject.chapters {
            if let chapterIds = pool["\(subject.id):\(chapter.id)"] {
                ids.formUnion(chapterIds)
            }
        }
        return ids.sorted()
    }

    /// Avancement de la matière affichée pour un type d'entraînement.
    func trainingStat(kind: ProgressItemKind) -> TrainingStat {
        guard let subject = selectedSubject else { return TrainingStat() }
        return progress.trainingStat(forItemIds: itemIds(for: subject, kind: kind))
    }

    /// Défis de la matière affichée.
    var duelStat: DuelStat {
        guard let subject = selectedSubject else { return DuelStat() }
        return progress.duelStat(for: subject.name)
    }

    /// Cote Elo de la matière affichée.
    var selectedElo: Int {
        guard let subject = selectedSubject else { return ProgressStore.initialElo }
        return progress.subjectElo(for: subject.name)
    }
}
