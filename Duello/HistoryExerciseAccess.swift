//
//  HistoryExerciseAccess.swift
//  Duello
//
//  Accès aux exercices depuis l'historique des notes du profil : chaque ligne
//  retrouve son chapitre d'origine et la cible de reprise dans l'entraînement.
//
//  Fichier source Expo porté :
//    - src/utils/historyExerciseAccess.ts (`ResolvedGradeHistoryRow`,
//      `indexHistoryExercises`, `historyTracksMatch`, `resolveHistoryRow` et le
//      cache par spectateur).
//
//  Écart assumé : la source indexe les sujets des banques du spectateur
//  (`getChapterItems` / `getTrackAnnaleItems`, résolues localement, tous les
//  identifiants parcourus). Le port iOS sert ces banques par l'API
//  (`DuelloAPI.contentManifest`) et ne peut pas les énumérer hors ligne — même
//  limite documentée que `SubjScopeBundles` (« `exerciseCardCatalogItemIds`
//  n'existe pas côté Swift »). Le chapitre est donc déduit de l'identifiant du
//  sujet (`chapitre::exercice::clé`, `TrainItemID.chapterId`) puis résolu dans
//  le programme du spectateur (`DuelloProgram.subjects`). Seules les natures
//  `exercice` et `colle` ouvrent une cible, comme la source ; les annales,
//  dont l'identifiant ne porte pas son chapitre, restent non cliquables
//  (repli assumé).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `ResolvedGradeHistoryRow` : ligne d'historique rattachée au programme du
/// spectateur — nom du chapitre d'origine et cible de reprise.
struct ResolvedGradeHistoryRow: Identifiable, Equatable {
    var row: GradeHistoryRow
    /// Nom du chapitre d'origine, ou l'intitulé de repli de la ligne.
    var displayTitle: String
    /// Cible de reprise dans l'entraînement, nulle sans accès.
    var target: ChalRunTrainingTarget?

    var id: String { row.id }
    var category: String { row.category }
    var score: Double { row.score }
    var evolutionPercentage: Double? { row.evolutionPercentage }
    var record: Bool { row.record }
}

/// `utils/historyExerciseAccess.ts` : reprise d'un sujet depuis l'historique.
enum HistoryExerciseAccess {

    /// `PROGRAM_YEARS` (`src/data/tracks.ts:135`).
    static let programYears = [1, 2]

    /// `PREP_TRACKS` (`src/data/tracks.ts:133`).
    private static let prepTracks = ["ECG", "MPSI", "Lycée"]

    /// Chapitre d'un sujet du spectateur : son nom, sa matière et son année,
    /// de quoi composer la cible de reprise d'un `itemId`.
    struct IndexedHistoryChapter: Equatable {
        var chapterName: String
        var subjectId: String
        var year: String
    }

    /// Cache par spectateur, comme `indexCache` de la source.
    private static var indexCache: [String: [String: IndexedHistoryChapter]] = [:]

    /// `normalizeTrack` : « Prépa commerce » vaut ECG ; toute filière inconnue
    /// retombe sur ECG (`PREP_TRACKS[0]`).
    static func normalizeTrack(_ track: String) -> String {
        let resolved = track == "Prépa commerce" ? "ECG" : track
        return prepTracks.contains(resolved) ? resolved : prepTracks[0]
    }

    /// `historyTracksMatch` : même filière, anciens intitulés compris ; sans
    /// elle, pas de reprise.
    static func historyTracksMatch(viewerTrack: String, ownerTrack: String) -> Bool {
        normalizeTrack(viewerTrack) == normalizeTrack(ownerTrack)
    }

    /// `indexHistoryExercises` : index des chapitres du spectateur sur les deux
    /// années du programme, chacun donnant sa matière et son année. Le premier
    /// chapitre rencontré pour un identifiant l'emporte (année 1 d'abord), comme
    /// la source.
    static func indexHistoryExercises(viewer: UserProfile) -> [String: IndexedHistoryChapter] {
        var index: [String: IndexedHistoryChapter] = [:]
        for year in programYears {
            let selection = ProfStudentContext.academicProgramSelection(viewer, programYear: year)
            let subjects = DuelloProgram.subjects(
                track: viewer.track,
                specialty: selection.specialty,
                year: year == 1 ? "1re" : "2e"
            )
            for subject in subjects {
                for chapter in subject.chapters {
                    if index[chapter.id] != nil { continue }
                    index[chapter.id] = IndexedHistoryChapter(
                        chapterName: chapter.name,
                        subjectId: subject.id,
                        year: year == 1 ? "1re" : "2e"
                    )
                }
            }
        }
        return index
    }

    /// Index du spectateur, mémoïsé sur sa filière, son année, sa spécialité et
    /// son parcours scolaire (`cachedIndex`).
    private static func cachedIndex(_ viewer: UserProfile) -> [String: IndexedHistoryChapter] {
        let key = [
            viewer.track,
            viewer.year,
            viewer.specialty,
            viewer.academicPath?.currentTrack ?? "",
            viewer.academicPath?.firstYearTrack ?? "",
            viewer.academicPath?.currentOption ?? "",
            viewer.academicPath?.firstYearOption ?? "",
        ].joined(separator: "|")
        if let cached = indexCache[key] { return cached }
        let index = indexHistoryExercises(viewer: viewer)
        indexCache[key] = index
        return index
    }

    /// `resolveHistoryRow` : rattache une ligne d'historique au programme du
    /// spectateur — le chapitre affiché et la cible de reprise, ou le repli non
    /// cliquable. Un sujet absent des banques du spectateur ne s'ouvre pas, même
    /// dans la même filière.
    static func resolveHistoryRow(
        _ row: GradeHistoryRow,
        viewer: UserProfile,
        ownerTrack: String
    ) -> ResolvedGradeHistoryRow {
        guard historyTracksMatch(viewerTrack: viewer.track, ownerTrack: ownerTrack),
              let itemId = row.itemId,
              let chapterId = TrainItemID.chapterId(of: itemId),
              let activity = chapterActivity(of: itemId),
              let found = cachedIndex(viewer)[chapterId]
        else {
            return ResolvedGradeHistoryRow(row: row, displayTitle: row.title, target: nil)
        }
        let target = ChalRunTrainingTarget(
            itemId: itemId,
            itemTitle: CollTrainingTitle.itemTitle(chapterId: chapterId, title: ""),
            subjectId: found.subjectId,
            chapterId: chapterId,
            year: found.year,
            activity: activity
        )
        return ResolvedGradeHistoryRow(row: row, displayTitle: found.chapterName, target: target)
    }

    /// Nature du sujet lue dans son identifiant (`chapitre::<nature>::clé`) :
    /// seules `exercice` et `colle` ouvrent une cible, comme la source (les
    /// annales gardent leur intitulé de ligne, sans chapitre).
    private static func chapterActivity(of itemId: String) -> String? {
        let parts = itemId.components(separatedBy: "::")
        guard parts.count >= 3 else { return nil }
        let kind = parts[1]
        return (kind == "exercice" || kind == "colle") ? kind : nil
    }
}
