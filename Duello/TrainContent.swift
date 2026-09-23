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
        let first = yearBundleIds(track: track, specialty: specialty, year: 1)
        let second = yearBundleIds(track: track, specialty: specialty, year: 2)
        let ordered = year == 2 ? second + first : first + second
        // Le corpus oral de l'ECG complète les deux années.
        return normalize(track).contains("ecg") ? ordered + ["oral-drive-exercises"] : ordered
    }

    /// Banques de l'année affichée seule : énoncés, colles et annales réunis.
    /// C'est le périmètre du décompte d'une matière (`chapterItemScope` de
    /// `data/chapterItemBasics.ts`) — l'autre année ne doit pas gonfler le
    /// dénominateur quand un chapitre porte le même identifiant dans les deux
    /// programmes (par exemple `prehilbertiens` en MPSI et en MP).
    static func yearBundleIds(track: String, specialty: String, year: Int) -> [String] {
        let normalizedTrack = normalize(track)
        if normalizedTrack.contains("lycee") { return [] }

        if normalizedTrack.contains("mpsi") {
            return year == 2 ? ["mp-statements"] : ["mpsi-statements", "colles-mpsi-1"]
        }

        guard normalizedTrack.contains("ecg") else { return [] }

        if normalize(specialty).contains("applique") {
            if year == 2 {
                return [
                    "ecg-applied-2-statements",
                    "colles-ecg-appliquees-2",
                    "ecg-applied-annales-2025",
                    "ecg-applied-annales-2024",
                    "ecg-applied-annales-legendre",
                ]
            }
            return [
                "ecg-applied-1-statements",
                "colles-ecg-appliquees-1",
                "ecg-applied-annales-year-1",
            ]
        }

        if year == 2 {
            return [
                "ecg-advanced-2-statements",
                "colles-ecg-approfondies-2",
                "ecg-advanced-annales-2",
                "ecg-advanced-annales-2-drive",
                "ecg-advanced-maths-i-annales",
                "ecg-advanced-maths-ii-annales",
            ]
        }
        return [
            "ecg-advanced-1-statements",
            "colles-ecg-approfondies-1",
            "ecg-advanced-annales-1",
            "ecg-advanced-annales-1-kleber",
        ]
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

    /// Décompte du catalogue par chapitre, **exercices servis, colles et
    /// annales réunis** (`buildSubjectSuccessSummaries` de
    /// `src/utils/subjectSuccess.ts`). C'est le dénominateur de l'en-tête d'une
    /// matière : il couvre les trois natures de sujets, là où `chapterIndex`
    /// ne retient que la banque d'énoncés. Les banques de l'année affichée
    /// (`yearBundleIds`) portent déjà les colles et les annales, chaque banque
    /// comptant ses propres items.
    static func catalogCounts(
        manifest: DuelloAPI.ContentManifest,
        track: String,
        specialty: String,
        year: String
    ) -> [String: Int] {
        let bundles = Set(
            yearBundleIds(track: track, specialty: specialty, year: programYear(from: year))
        )
        var counts: [String: Int] = [:]
        for descriptor in manifest.chapters ?? [] where bundles.contains(descriptor.bundleId) {
            counts[descriptor.chapterId, default: 0] += descriptor.count
        }
        return counts
    }
}
