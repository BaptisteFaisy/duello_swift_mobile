import Foundation

/// Règles éditoriales du nettoyage d'énoncé — port de `src/utils/statementCruft.ts`
/// (métadonnées, durées, titres rédactionnels).
///
/// Le retrait opère sur des lignes complètes, jamais à l'intérieur d'une
/// formule : une phrase qui contient fortuitement l'un de ces mots reste
/// intacte.
enum StmtCruftRules {
    static let maxMetadataLineLength = 200
    static let maxTitleLineLength = 140
    static let maxCombinedMetadataLineLength = 320

    /// Mots-têtes d'une méta-donnée dont la valeur peut suivre.
    static let measuredHeadings =
        "^(?:duree|durée|temps|difficulte|difficulté|niveau|chapitre|sources?|bareme|barème|calculatrice|documents?|materiel|matériel)s?(?![\\p{L}\\p{N}])"

    /// Têtes de rubrique qui ne portent jamais de contenu sur leur propre ligne.
    static let rubricHeadings =
        "^(énoncé|enonce|corrigé|corrige|correction|consigne)s?(?![\\p{L}\\p{N}])"

    static let rubricEnonceTail =
        "^(?:[—–-]\\s*)?(?:exercice|problème)?\\s*\\d*|[—–-]\\s*\\S.*$"

    static let rubricCorrigeTail =
        "^(?:détaillée?|détaillés?|de\\s+l['’]?exercice\\b.*|[—–-]\\s*(?:exercice\\s*)?\\d*|proposée?|proposés?|\\d*|(?:mis\\s+en\\s+ligne|rédigés?)\\b.*|[—–-]\\s*\\S.*)\\s*[.!?]*$"

    static let rubricConsigneTail =
        "^(?:générales?|préliminaires?|de\\s+rédaction|de\\s+passage)?\\s*[.!?]*$"

    /// « Fin du problème », « Fin de l'énoncé », « Fin du corrigé », « Fin ».
    static let standaloneFin =
        "^fin(?:\\s+(?:du|des|la)\\s+[\\p{L}'’-]+|\\s*de\\s+l['’][\\p{L}'’-]+)?[.!\\s]*$"

    /// Ligne réduite à une expression de durée (segment réinterpolé) :
    /// « 1 h 15 », « 2 h », « 1h30 », « 3 heures », « 45 min ».
    static let standaloneDurationLine: String = {
        let segment = "\\d{1,2}\\s*(?:h|heures?)\\s*\\d{0,2}\\s*(?:min(?:utes?)?)?|\\d{1,3}\\s*min(?:utes?)?"
        return "^(?:[&•·*\\-–—]\\s*)?(?:environ\\s+|~\\s*)?(?:(?:\\d{1,3}\\s*(?:à|–|—|-|et|ou)\\s*)?(?:\(segment)))(?:\\s*(?:à|–|—|-|et|ou)\\s*(?:\(segment)))?[.!?]*$"
    }()

    static let calibratedProblemLine =
        "^(?:exercice|problème)\\s+(?:très\\s+difficile|d'entraînement|de\\s+type)(?![\\p{L}\\p{N}]).*$"
    static let calibrationMarker =
        "(?<![\\p{L}\\p{N}])(?:durée|difficulté|calibrage|niveau|questions?)(?![\\p{L}\\p{N}])"
    static let exerciseTitleLine =
        "^(?:exercice|problème)\\s*(?:n[°ºo]\\s*)?\\d+(?:\\.\\d+)*\\s*[—–-]\\s*\\S.*$"
    static let problemTitleLine = "^problème\\s*[—–-]\\s*\\S.*$"
    static let combinedMetadataLine =
        "^(?:exercice\\s*(?:n[°ºo]\\s*)?\\d+(?:\\.\\d+)*|problèmes?|niveaux?|durées?|difficultés?)(?![\\p{L}])"
    static let combinedNiveau = "\\bniveau\\s*[:：]"
    static let combinedDuree = "\\bdurée\\s*(?:indicative|cible|visée|maximale)?\\s*[:：]"
    static let nestedMetadataMarker =
        "(?<![\\p{L}\\p{N}])(?:durée|difficulté|niveau|calculatrice|barème)(?![\\p{L}\\p{N}])\\s*(?:indicative|cible|visée|maximale)?\\s*[:：]"
    static let latexSizeTitleLine = "^\\{\\s*\\\\large\\b[^\\n]*\\}\\s*$"

    /// Décore la ligne de ses attributs Markdown (titre, gras) et de sa ponctuation.
    static func undecorate(_ line: String) -> String {
        var value = StmtRegex.replaceAll("^[#{\\s]+", in: line, template: "")
        value = StmtRegex.replaceAll("^\\*\\*", in: value, template: "")
        value = StmtRegex.replaceAll("\\*\\*", in: value, template: "")
        return value.trimmingCharacters(in: .whitespaces)
    }

    /// Ligne de durée nue : courte, sans autre mot que l'expression elle-même.
    static func isStandaloneDurationLine(_ trimmed: String) -> Bool {
        let bare = undecorate(trimmed)
        if bare.count > 40 { return false }
        return StmtRegex.contains(standaloneDurationLine, in: bare, options: [.caseInsensitive])
    }

    /// Poids des mots entre le mot-tête et sa valeur (« de », « la » comptent double).
    static func weightedWords(_ text: String) -> Int {
        let outils = "^(?:de|du|des|la|le|les|l|un|une|au|aux|à|a|en|et|ou|par|pour|sur|très|tres|trop|peu|plus|moins|d|n|s|c|j|m|t)$"
        return StmtRegex.replaceAll("[\\s'’-]+", in: text, template: "\u{0001}")
            .split(separator: "\u{0001}", omittingEmptySubsequences: true)
            .reduce(0) { total, rawWord in
                let word = StmtRegex.replaceAll("[^\\p{L}]", in: String(rawWord), template: "")
                return total + (StmtRegex.contains(outils, in: word, options: [.caseInsensitive]) ? 2 : 1)
            }
    }

    /// Vrai si la queue du mot-tête ressemble à une valeur de méta-donnée.
    static func isMetadataValue(_ tail: String) -> Bool {
        if StmtRegex.replaceAll("[.!\\s]", in: tail, template: "").isEmpty { return true }
        if StmtRegex.contains(nestedMetadataMarker, in: tail, options: [.caseInsensitive]) { return true }
        guard let colon = StmtRegex.firstMatch("[:：]", in: tail) else {
            return weightedWords(tail) <= 4
        }
        let qualifier = (tail as NSString).substring(to: colon.range.location)
        if !StmtRegex.contains("^[\\s\\p{L}'’;—–-]*$", in: qualifier) { return false }
        return weightedWords(qualifier) <= 4
    }

    /// Vrai si la ligne est une méta-donnée éditoriale complète.
    static func isMetadataHeadingLine(_ trimmed: String) -> Bool {
        if trimmed.count > maxMetadataLineLength { return false }
        let bare = undecorate(trimmed)
        if bare.isEmpty { return false }

        if StmtRegex.contains(standaloneFin, in: bare, options: [.caseInsensitive]) { return true }

        if let measured = StmtRegex.groups(measuredHeadings, in: bare, options: [.caseInsensitive]) {
            let tail = String(bare.dropFirst(measured[0].count))
            if let colon = StmtRegex.firstMatch("[:：]", in: tail) {
                let ns = tail as NSString
                let qualifier = ns.substring(to: colon.range.location)
                let value = ns.substring(from: colon.range.location + colon.range.length)
                    .trimmingCharacters(in: .whitespaces)
                if StmtRegex.contains("^[\\s\\p{L}'’-]*$", in: qualifier),
                   !value.isEmpty, value.count <= 60,
                   StmtRegex.contains(standaloneDurationLine, in: undecorate(value), options: [.caseInsensitive]) {
                    return true
                }
            }
            return isMetadataValue(tail)
        }

        if let rubric = StmtRegex.groups(rubricHeadings, in: bare, options: [.caseInsensitive]) {
            let tail = String(bare.dropFirst(rubric[0].count)).trimmingCharacters(in: .whitespaces)
            let head = rubric[1].lowercased(with: Locale(identifier: "fr-FR"))
            if head.hasPrefix("énonc") || head.hasPrefix("enonc") {
                return StmtRegex.contains(rubricEnonceTail, in: tail, options: [.caseInsensitive])
            }
            if head.hasPrefix("corrig") || head.hasPrefix("correct") {
                return StmtRegex.contains(rubricCorrigeTail, in: tail, options: [.caseInsensitive])
            }
            return StmtRegex.contains(rubricConsigneTail, in: tail, options: [.caseInsensitive])
        }

        return false
    }

    /// En-tête calibré d'un problème d'entraînement.
    static func isCalibratedProblemLine(_ trimmed: String) -> Bool {
        if trimmed.count > maxMetadataLineLength { return false }
        let bare = undecorate(trimmed)
        if !StmtRegex.contains(calibratedProblemLine, in: bare, options: [.caseInsensitive]) { return false }
        return StmtRegex.contains(calibrationMarker, in: bare, options: [.caseInsensitive])
    }

    /// Ligne de titre rédactionnelle (« Exercice 12 — … »).
    static func isTitleLine(_ trimmed: String) -> Bool {
        let bareProbe = undecorate(trimmed)
        let hasNested = StmtRegex.contains(nestedMetadataMarker, in: bareProbe, options: [.caseInsensitive])
        if trimmed.count > (hasNested ? maxCombinedMetadataLineLength : maxTitleLineLength) { return false }
        let bare = undecorate(trimmed)
        if StmtRegex.contains("[.]\\s*$", in: bare) { return false }
        return StmtRegex.contains(exerciseTitleLine, in: bare, options: [.caseInsensitive])
            || StmtRegex.contains(problemTitleLine, in: bare, options: [.caseInsensitive])
    }

    /// Ligne combinée « Exercice 17 — … Niveau : … durée indicative : … ».
    static func isCombinedMetadataLine(_ trimmed: String) -> Bool {
        if trimmed.count > maxCombinedMetadataLineLength { return false }
        let bare = undecorate(trimmed)
        if !StmtRegex.contains(combinedMetadataLine, in: bare, options: [.caseInsensitive]) { return false }
        return StmtRegex.contains(combinedNiveau, in: bare, options: [.caseInsensitive])
            && StmtRegex.contains(combinedDuree, in: bare, options: [.caseInsensitive])
    }

    /// Ligne LaTeX de titrage dupliquant le titre de la fiche (« {\large …} »).
    static func isLatexSizeTitleLine(_ trimmed: String) -> Bool {
        StmtRegex.contains(latexSizeTitleLine, in: trimmed, options: [.caseInsensitive])
    }
}
