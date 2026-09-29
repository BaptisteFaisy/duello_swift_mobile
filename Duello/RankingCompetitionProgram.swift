//
//  RankingCompetitionProgram.swift
//  Duello
//
//  Couverture du programme menant aux concours, en pourcentage.
//
//  Fichier source Expo porté (mêmes seuils et même repli que la source) :
//    - src/utils/subjectProgress.ts
//        `defaultChapterCourseStatus`, `loadCompetitionProgramPercent`.
//
//  La source range le statut de cours de chaque chapitre dans la progression de
//  matière (`subjectProgressStorageKey(track, year, specialty)`). Le port iOS
//  n'a pas de store par matière pour ce champ : `TrainCourseStatusStore`
//  (`TrainCourseStatus.swift`) tient une table plate `chapterId → statut`, sous
//  la clé `com.duello.ios.training.course-status`. `load` relit donc cette table
//  (clé miroir documentée) et `percent` rejoue le même décompte : chaque
//  chapitre du programme des deux années compte, un chapitre sans statut prend
//  le défaut, et seul « completed » incrémente.
//
//  Écart assumé : la table plate indexe par identifiant de chapitre, sans
//  portée année/option — un identifiant partagé entre deux années compte une
//  seule fois. La source, elle, lit un JSON par année et par option.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `utils/subjectProgress.ts` : couverture du programme de concours.
enum RankingCompetitionProgram {

    /// Clé miroir de `TrainCourseStatusStore.storageKey`
    /// (`TrainCourseStatus.swift`).
    static let chapterStatusStorageKey = "com.duello.ios.training.course-status"

    /// `defaultChapterCourseStatus` : un élève en 2e année a déjà suivi le
    /// programme de 1re année, ses chapitres partent donc à « vu ».
    static func defaultChapterCourseStatus(
        chapterYear: Int,
        profileYear: Int
    ) -> TrainCourseStatus {
        chapterYear == 1 && profileYear > 1 ? .completed : .notStarted
    }

    /// Filière et option retenues pour une année (`academicProgramSelection`) :
    /// le parcours détaillé prime sur les champs historiques.
    static func selection(_ profile: UserProfile, year: Int) -> (track: String, specialty: String) {
        guard let path = profile.academicPath else {
            return (profile.track, profile.specialty)
        }
        return year == 1
            ? (path.firstYearTrack, path.firstYearOption)
            : (path.currentTrack, path.currentOption)
    }

    /// `loadCompetitionProgramPercent` : part des chapitres des deux années
    /// marquée « vu », en pourcentage arrondi ; zéro sans chapitre servi.
    static func percent(
        chapterStatuses: [String: TrainCourseStatus],
        profile: UserProfile
    ) -> Int {
        let profileYear = DuelloProgram.isFirstProgramYear(profile.year) ? 1 : 2
        var completed = 0
        var total = 0

        for year in [1, 2] {
            let choice = selection(profile, year: year)
            let label = year == 1 ? "1re année" : "2e année"
            let program = DuelloProgram.subjects(
                track: choice.track,
                specialty: choice.specialty,
                year: label
            )
            let fallback = defaultChapterCourseStatus(chapterYear: year, profileYear: profileYear)
            for subject in program {
                for chapter in subject.chapters {
                    total += 1
                    let status = chapterStatuses[chapter.id] ?? fallback
                    if status == .completed { completed += 1 }
                }
            }
        }

        return total > 0 ? Int((Double(completed) / Double(total) * 100).rounded()) : 0
    }

    /// `loadCompetitionProgramPercent` : relit le statut de cours persisté puis
    /// décompte la couverture du programme.
    static func load(profile: UserProfile) -> Int {
        percent(chapterStatuses: storedStatuses(), profile: profile)
    }

    /// Statut de cours persisté par `TrainCourseStatusStore` : table plate
    /// `chapterId → statut` ; les valeurs inconnues sont écartées.
    static func storedStatuses() -> [String: TrainCourseStatus] {
        guard let data = UserDefaults.standard.data(forKey: chapterStatusStorageKey),
              let stored = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        var result: [String: TrainCourseStatus] = [:]
        for (chapterId, raw) in stored {
            guard !chapterId.isEmpty, let status = TrainCourseStatus(rawValue: raw) else { continue }
            result[chapterId] = status
        }
        return result
    }
}
