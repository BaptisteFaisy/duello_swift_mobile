//
//  AnnServedBank.swift
//  Duello
//
//  Banque d'annales **servie** (`ecg-*-annales-*.json`) → entrées du lecteur.
//
//  Le manifeste de contenu ne décrit les banques d'annales que dans ses
//  `bundles` : `chapters` ne porte que les banques d'énoncés `*-statements`.
//  `TrainingCatalogView.loadAnnaleItems()` filtrait `chapters` et ne pouvait
//  donc rien charger — les annales servies restaient vides (écart 06#3) ; cette
//  unité décode les banques entières, hors du manifeste de chapitres.
//
//  Les banques servies n'ont pas toutes la même forme (`getTrackAnnaleItems`
//  de `data/chapterItems.ts`, banques publiées par `scripts/build-embedded-floor.mjs`) :
//    • banques avancées (`ecg-advanced-annales-*`) : `id` + `chapterId`,
//      `badges`, `roles`, `annaleTypes`, `theme`, `source` ;
//    • banque appliquée de 1re année (`ecg-applied-annales-year-1`) : `key` +
//      `primaryChapterId`, `number`, `domains`, `durationHours` ;
//    • banques appliquées 2024/2025/legendre : `key` seul, avec barème et
//      commentaires officiels.
//  Un décodeur unique, entièrement facultatif hors titre, couvre les trois ;
//  aucun champ n'est inventé.
//
//  Cible iOS 16, aucune dépendance externe.
//
import Foundation

/// Décodage d'une banque d'annales servie en entrées de lecteur (`AnnEntry`).
enum AnnServedBank {

    /// Sujet d'annale servi, tel que la banque le publie (`ChapterItem` réduit
    /// aux champs lus par la liste et le lecteur).
    struct Item: Decodable {
        var id: String?
        var key: String?
        var chapterId: String?
        var primaryChapterId: String?
        var kind: String?
        var title: String
        var difficulty: Int?
        var badges: [String]?
        var roles: [String]?
        var annaleTypes: [String]?
        var notions: [String]?
        var theme: String?
        var programStatus: String?
        var source: String?
        var domains: [String]?
        var number: Int?
        var durationHours: Int?
        /// Badge de durée des DS Legendre (`duration` : « DS 2h » / « DS 4h »).
        var duration: String?
        var sourceUrl: String?
        var solutionUrl: String?
        var markingSchemeUrl: String?
        var commentsUrl: String?
        var statement: String?
        var solution: String?
        var markingScheme: String?
        var comments: String?

        /// Identifiant d'item : `id` des banques avancées, `key` des appliquées.
        var itemId: String { id ?? key ?? title }
    }

    /// Entrées de lecteur d'une banque servie (`annaleItems` de la source),
    /// dans l'ordre de la banque.
    static func entries(_ items: [Item]) -> [AnnEntry] {
        items.map(entry)
    }

    /// Entrée de lecteur d'un sujet servi (`ChapterItem` → `openAnnaleItem`).
    static func entry(_ item: Item) -> AnnEntry {
        AnnEntry(
            id: item.itemId,
            title: item.title,
            source: item.source,
            badges: badges(of: item),
            annaleTypes: item.annaleTypes ?? [],
            theme: theme(of: item),
            difficulty: difficulty(of: item),
            statement: item.statement,
            solution: item.solution,
            markingScheme: item.markingScheme,
            comments: item.comments,
            questions: questions(of: item),
            programStatus: AnnProgramStatus(rawValue: item.programStatus ?? ""),
            sourceUrl: item.sourceUrl
        )
    }

    /// Badges d'épreuve : ceux de la banque avancée (`badges`), sinon la durée
    /// servie — `duration` des DS Legendre, `durationHours` des DS de 1re année
    /// (« DS 2h » / « DS 4h »), « DS 4h » par défaut des DS de 2e année
    /// (`displayedAnnaleBadges`, `ecgAppliedYear1Annales`, `ecgAppliedYear2Annales2024`).
    private static func badges(of item: Item) -> [String] {
        if let badges = item.badges { return badges }
        if let duration = item.duration { return [duration] }
        if let hours = item.durationHours { return [hours == 2 ? "DS 2h" : "DS 4h"] }
        return ["DS 4h"]
    }

    /// Difficulté : celle des banques avancées, sinon déduite de la durée du
    /// devoir (2 h → 3, 4 h → 4) comme `ecgAppliedYear1Annales`.
    private static func difficulty(of item: Item) -> Int {
        if let difficulty = item.difficulty { return difficulty }
        if let hours = item.durationHours { return hours == 2 ? 3 : 4 }
        return 4
    }

    /// Thème d'annale : celui que le sujet déclare, sinon son premier domaine
    /// servi (`domains` des banques appliquées, `itemThemes` de la source).
    /// Les banques avancées portent `theme` ; les appliquées, `domains`.
    private static func theme(of item: Item) -> AnnTheme? {
        if let raw = item.theme, let theme = AnnTheme(rawValue: raw) { return theme }
        guard let domain = item.domains?.first else { return nil }
        return theme(label: domain)
    }

    /// Domaine libellé (« Analyse ») → thème d'annale (`ANNALE_THEME_LABELS`).
    private static func theme(label: String) -> AnnTheme? {
        switch label {
        case "Analyse": return .analyse
        case "Algèbre": return .algebre
        case "Probabilités": return .probabilites
        default: return nil
        }
    }

    /// Questions retranscrites de l'énoncé (`statementQuestions` de la source).
    /// Vide quand l'énoncé n'en déclare pas.
    private static func questions(of item: Item) -> [AnnQuestion] {
        StmtQuestions.extractStatementQuestions(item.statement ?? "").map { question in
            AnnQuestion(
                id: question.id,
                label: question.label,
                alternativeId: question.alternativeId,
                alternativeGroupId: question.alternativeGroupId
            )
        }
    }
}
