import Foundation

/// Un item de banque tel que lu par les règles d'ouverture et de corrigé.
///
/// Port de `ChapterItem` (`src/data/chapterItems.ts`) réduit aux champs
/// effectivement consultés par `chapterItemBasics.ts` : les règles ci-dessous
/// ne regardent ni le titre ni l'identifiant, seulement la disponibilité de la
/// source et du corrigé.
struct TrainChapterItemBasic: Equatable {
    var sourceAsset: Int?
    var sourceUrl: String?
    var statement: String?
    var solution: String?
    var solutionPage: Int?
    var solutionAsset: Int?
    var solutionUrl: String?
    var isPlaceholder: Bool

    init(
        sourceAsset: Int? = nil,
        sourceUrl: String? = nil,
        statement: String? = nil,
        solution: String? = nil,
        solutionPage: Int? = nil,
        solutionAsset: Int? = nil,
        solutionUrl: String? = nil,
        isPlaceholder: Bool = false
    ) {
        self.sourceAsset = sourceAsset
        self.sourceUrl = sourceUrl
        self.statement = statement
        self.solution = solution
        self.solutionPage = solutionPage
        self.solutionAsset = solutionAsset
        self.solutionUrl = solutionUrl
        self.isPlaceholder = isPlaceholder
    }
}

/// Port de `src/data/chapterItemBasics.ts` : ce que le lecteur sait ouvrir, ce
/// qui a un corrigé consultable, et la banque à servir pour un parcours.
///
/// `hasAnnaleBank` (onglet Annales) n'est pas redéfini ici : il est déjà porté
/// par `SubjTrainingModeCatalog.hasAnnaleBank` (`SubjTrainingMode.swift`).
enum TrainChapterItemBasics {

    /// Un item que le lecteur sait ouvrir : PDF embarqué, lien, ou énoncé fourni.
    static func canOpenChapterItem(_ item: TrainChapterItemBasic) -> Bool {
        item.sourceAsset != nil || item.sourceUrl != nil || !(item.statement ?? "").isEmpty
    }

    /// Vrai lorsque le corrigé de l'item est consultable dans le lecteur.
    static func chapterItemHasSolution(_ item: TrainChapterItemBasic) -> Bool {
        if !(item.solution ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if item.solutionPage == nil { return false }
        return item.solutionAsset != nil
            || item.solutionUrl != nil
            || item.sourceAsset != nil
            || item.sourceUrl != nil
    }

    /// Items dont l'énoncé est réellement disponible, sans la liste type.
    static func availableChapterItems(_ items: [TrainChapterItemBasic]) -> [TrainChapterItemBasic] {
        items.filter { !$0.isPlaceholder }
    }

    /// Filières dont les banques réelles sont servies à l'application.
    ///
    /// Le lycée en fait partie depuis la Seconde ; `chapterItemScope` restreint
    /// ensuite la banque au niveau réellement suivi.
    static func hasRealChapterBanks(_ track: String) -> Bool {
        track == "ECG" || track == "MPSI" || track == "Lycée"
    }

    /// Banque à servir à l'année affichée, `nil` hors filière pourvue.
    ///
    /// Le lycée sert les trois niveaux dont le corpus est monté ; les autres
    /// options gardent leur liste type. Le niveau se lit dans la spécialité,
    /// seule information disponible à ce niveau de l'appel.
    static func chapterItemScope(track: String, year: Int, specialty: String = "") -> String? {
        if !hasRealChapterBanks(track) { return nil }
        if track == "Lycée" { return TrainContent.lyceeScope(forSpecialty: specialty) }
        if track == "MPSI" { return year == 1 ? "mpsi-1" : "mp-2" }
        if specialty.lowercased().contains("appliqu") {
            return year == 1 ? "ecg-appliquees-1" : "ecg-appliquees-2"
        }
        return year == 1 ? "ecg-approfondies-1" : "ecg-approfondies-2"
    }

    /// Convertit le mode d'entraînement de l'écran en type d'item de la banque.
    static func kindFromMode(_ mode: String) -> TrainExerciseKind {
        if mode == "colles" { return .colle }
        if mode == "dissertations" { return .dissertation }
        return .exercise
    }
}
