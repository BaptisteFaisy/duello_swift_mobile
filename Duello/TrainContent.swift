import Foundation

/// Résolution des banques servies pour la matière affichée.
///
/// Port de `src/content/contentStartup.ts` : l'ordre des banques du profil
/// décide quel descripteur de chapitre retenir quand plusieurs banques servent
/// le même chapitre (1re et 2e année, colles, annales). La matière et l'option
/// viennent du profil, la même source que `DuelloProgram.subjects`.
enum TrainContent {
    /// Retire les accents et la casse, comme `DuelloProgram.normalize`.
    static func normalize(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Année de programme du profil : tout libellé contenant « 2 » vaut 2.
    static func programYear(from year: String) -> Int {
        year.lowercased().contains("2") ? 2 : 1
    }

    /// Banques du programme de l'élève, année affichée en tête
    /// (`profileBundleIds`). Le lycée n'a pas de banque servie.
    static func profileBundleIds(track: String, specialty: String, year: Int) -> [String] {
        let normalizedTrack = normalize(track)
        if normalizedTrack.contains("lycee") { return [] }

        if normalizedTrack.contains("mpsi") {
            let first = ["mpsi-statements", "colles-mpsi-1"]
            let second = ["mp-statements"]
            return year == 2 ? second + first : first + second
        }

        guard normalizedTrack.contains("ecg") else { return [] }

        if normalize(specialty).contains("applique") {
            let first = [
                "ecg-applied-1-statements",
                "colles-ecg-appliquees-1",
                "ecg-applied-annales-year-1",
            ]
            let second = [
                "ecg-applied-2-statements",
                "colles-ecg-appliquees-2",
                "ecg-applied-annales-2025",
                "ecg-applied-annales-2024",
                "ecg-applied-annales-legendre",
            ]
            return (year == 2 ? second + first : first + second) + ["oral-drive-exercises"]
        }

        let first = [
            "ecg-advanced-1-statements",
            "colles-ecg-approfondies-1",
            "ecg-advanced-annales-1",
            "ecg-advanced-annales-1-kleber",
        ]
        let second = [
            "ecg-advanced-2-statements",
            "colles-ecg-approfondies-2",
            "ecg-advanced-annales-2",
            "ecg-advanced-annales-2-drive",
            "ecg-advanced-maths-i-annales",
            "ecg-advanced-maths-ii-annales",
        ]
        return (year == 2 ? second + first : first + second) + ["oral-drive-exercises"]
    }

    /// Banques d'énoncés de l'année affichée, la première portant le corpus
    /// principal (`exerciseContentBundleIds`).
    static func exerciseBundleIds(track: String, specialty: String, year: Int) -> [String] {
        let normalizedTrack = normalize(track)
        if normalizedTrack.contains("mpsi") {
            return [year == 2 ? "mp-statements" : "mpsi-statements"]
        }
        let profile = profileBundleIds(track: track, specialty: specialty, year: year)
        let marker = year == 2 ? "-2-" : "-1-"
        return profile.filter { $0.contains(marker) && $0.hasSuffix("-statements") }
    }

    /// Descripteur retenu par identifiant de chapitre. Quand plusieurs banques
    /// servent le même chapitre, la plus prioritaire pour le profil gagne ; à
    /// priorité égale, la première du manifeste est conservée.
    static func chapterIndex(
        manifest: DuelloAPI.ContentManifest,
        track: String,
        specialty: String,
        year: String
    ) -> [String: DuelloAPI.ContentChapterDescriptor] {
        let order = exerciseBundleIds(
            track: track,
            specialty: specialty,
            year: programYear(from: year)
        )
        var best: [String: (rank: Int, descriptor: DuelloAPI.ContentChapterDescriptor)] = [:]
        for descriptor in manifest.chapters ?? [] {
            let rank = order.firstIndex(of: descriptor.bundleId) ?? order.count
            if let current = best[descriptor.chapterId], current.rank <= rank { continue }
            best[descriptor.chapterId] = (rank, descriptor)
        }
        return best.mapValues { $0.descriptor }
    }
}
