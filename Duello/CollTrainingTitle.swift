//
//  CollTrainingTitle.swift
//  Duello
//
//  Intitulé éditorial court d'un sujet d'entraînement : les numéros et noms de
//  feuilles sont retirés, et le chapitre donne un repli quand aucune source ne
//  fournit de thème.
//
//  Fichiers source Expo portés :
//    - src/utils/trainingItemTitle.ts
//        `trainingItemTitle`, `chapterTheme`, `removeSourcePrefix`, les motifs
//        `SOURCE_ONLY_TITLE`, `SOURCE_PREFIX`, `SOURCE_REFERENCE_TITLE` et les
//        tables `CHAPTER_THEMES` / `CHAPTER_WORDS`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `trainingItemTitle` et ses replis de chapitre.
enum CollTrainingTitle {
    // MARK: - Motifs

    private static let sourceOnlyTitle = "(?i)^(?:(?:exercice|exo|sujet|colle|td|tp|interro|question(?: de cours| sans préparation)?|feuille d’exercices)\\s*)?[\\d.a-z°º_-]*$"
    private static let sourcePrefix = "(?i)^\\s*(?:(?:exercice|exo|sujet(?: de colle)?|colle|td|tp|interro|question(?: de cours| sans préparation)?|feuille d’exercices)(?:\\s+[a-zà-ÿ'’]+)*?\\s*(?:[a-z]{0,2}\\d[\\d.a-z°º_-]*\\s*(?:[·:—-]\\s*)?|[·:—-]\\s*))+"
    private static let sourceReferenceTitle = "(?i)^(?:d’après\\s+(?:l’)?)?(?:qsp|oral|escp|hec|edhec)\\b"
    private static let dsTitle = "(?i)^(?:ds(?=\\s|\\d)|devoir surveillé\\b)"
    private static let dsThemeSeparator = "\\s+—\\s+"
    private static let trailingSource = "(?i)\\s+(?:-|·)\\s+(?:d’après\\s+)?(?:qsp|oral|escp|hec|edhec)\\b.*$"
    private static let trailingYear = "(?i)\\s+\\(?(?:qsp|oral)\\s+(?:escp|hec)?\\s*\\d{4}\\)?$"
    private static let pythonTp = "(?i)^python\\s+—\\s+tp\\b.*$"
    private static let pythonInTitle = "(?i)\\bpython\\s+—\\s+tp\\b"
    private static let concoursBlanc = "(?i)^concours blanc\\b|^type maths\\b"
    private static let shorterSplit = "(?i)\\s+(?:selon|d’après|à partir de)\\s+|[,;]"
    private static let leadingNumber = "^\\s*\\d+(?:[.,]\\d+)*[.)]?\\s*"

    // MARK: - Tables de chapitres

    private static let chapterThemes: [String: String] = [
        "algebre-complements": "Compléments d’algèbre",
        "analyse-concours": "Analyse",
        "applications-lineaires": "Applications linéaires",
        "calcul-differentiel": "Calcul différentiel",
        "calcul-matriciel": "Calcul matriciel",
        "chaines-markov": "Chaînes de Markov",
        "complements-variables-aleatoires": "Variables aléatoires",
        "convergence-approximation": "Convergence et approximation",
        "couples-discrets": "Couples de variables discrètes",
        "endomorphismes-symetriques": "Endomorphismes symétriques",
        "fonctions-deux-variables": "Fonctions de deux variables",
        "fonctions-2-variables": "Fonctions de deux variables",
        "methodes-inversion": "Méthodes d’inversion",
        "monte-carlo": "Méthode de Monte-Carlo",
        "probabilites-generales": "Probabilités générales",
        "reduction-matrices": "Réduction des matrices",
        "simulation-couples": "Simulation de couples aléatoires",
        "simulation-discrete": "Simulation de lois discrètes",
        "simulation-va": "Simulation de variables aléatoires",
        "suites-series": "Suites et séries",
        "systemes-differentiels": "Systèmes différentiels",
        "variables-densite": "Variables à densité",
        "variables-discretes": "Variables discrètes",
        "variables-generales": "Variables aléatoires",
        "va-densite": "Variables à densité",
    ]

    private static let chapterWords: [String: String] = [
        "algebre": "algèbre",
        "aleatoires": "aléatoires",
        "asymptotique": "asymptotique",
        "continuite": "continuité",
        "denombrement": "dénombrement",
        "derivabilite": "dérivabilité",
        "derivation": "dérivation",
        "differentielles": "différentielles",
        "geometrie": "géométrie",
        "integration": "intégration",
        "lineaires": "linéaires",
        "numeriques": "numériques",
        "polynomes": "polynômes",
        "probabilites": "probabilités",
        "reels": "réels",
        "series": "séries",
    ]

    // MARK: - Intitulé

    /// `trainingItemTitle` : nom éditorial court, ou thème du chapitre en repli.
    static func itemTitle(chapterId: String, title rawTitle: String) -> String {
        let original = rawTitle
            .replacingOccurrences(of: "[\\u0000-\\u001f\\u007f]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isDsTitle = matches(original, dsTitle)
        let numberedDsWithoutTheme = isDsTitle && !matches(original, dsThemeSeparator)
        var title = removeSourcePrefix(original)
            .replacingOccurrences(of: trailingSource, with: "", options: .regularExpression)
            .replacingOccurrences(of: trailingYear, with: "", options: .regularExpression)
            .replacingOccurrences(of: pythonTp, with: "Python", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if numberedDsWithoutTheme || title.isEmpty
            || matches(title, sourceOnlyTitle)
            || matches(title, sourceReferenceTitle)
            || matches(title, concoursBlanc) {
            title = chapterTheme(chapterId)
        }
        if isDsTitle && matches(original, pythonInTitle) { title = "Python" }
        if isDsTitle, title.contains(",") {
            title = title.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? title
        }
        if title.count > 64 {
            let shorter = split(title, on: shorterSplit).first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let shorter, shorter.count >= 12 { title = shorter }
        }
        if title.count > 64 { title = chapterTheme(chapterId) }
        return title
    }

    /// `chapterTheme` : thème connu du chapitre, sinon titre reconstruit à partir
    /// de son identifiant.
    private static func chapterTheme(_ chapterId: String) -> String {
        var normalized = chapterId.replacingOccurrences(
            of: "^(?:appliquees|approfondies)-[12]-", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(
            of: "^python-(?:appliquees|approfondies)-[12]-", with: "", options: .regularExpression)
        if let known = chapterThemes[normalized] { return known }

        let words = normalized.split(separator: "-").filter { !$0.isEmpty }
            .map { chapterWords[String($0)] ?? String($0) }
        let title = words.joined(separator: " ")
        guard !title.isEmpty else { return "Notions du chapitre" }
        return String(title.prefix(1)).uppercased() + String(title.dropFirst())
    }

    /// `removeSourcePrefix` : préfère la partie thématique après un tiret long,
    /// puis retire le numéro et le nom de feuille en tête.
    private static func removeSourcePrefix(_ title: String) -> String {
        let dashParts = split(title, on: dsThemeSeparator)
        if dashParts.count > 1,
           let thematic = dashParts.last?.trimmingCharacters(in: .whitespacesAndNewlines),
           !thematic.isEmpty, !matches(thematic, sourceOnlyTitle) {
            return thematic
        }
        return title
            .replacingOccurrences(of: leadingNumber, with: "", options: .regularExpression)
            .replacingOccurrences(of: sourcePrefix, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Test d'un motif sur toute la chaîne (motifs ancrés par `^`/`$`).
    private static func matches(_ text: String, _ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Découpage par un motif, en conservant les fragments vides de la source.
    private static func split(_ text: String, on pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [text] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var parts: [String] = []
        var last = text.startIndex
        for match in regex.matches(in: text, options: [], range: range) {
            guard let matchRange = Range(match.range, in: text) else { continue }
            parts.append(String(text[last..<matchRange.lowerBound]))
            last = matchRange.upperBound
        }
        parts.append(String(text[last...]))
        return parts
    }
}
