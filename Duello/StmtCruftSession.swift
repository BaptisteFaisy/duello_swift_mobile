import Foundation

/// En-têtes de session et consignes générales — port de `src/utils/statementCruft.ts`.
enum StmtCruftSession {
    static let concoursAdmissionLine =
        "^[([{]?\\s*concours\\s+d[’']admission(?:\\s+de)?\\s*\\d{0,4}\\s*[)\\]}]?\\s*[.!…]*\\s*$"
    static let sessionSlotLine =
        "^(?:(?:lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\\s+)?\\d{1,2}(?:er)?\\s+(?:janvier|février|mars|avril|mai|juin|juillet|ao[uû]t|septembre|octobre|novembre|décembre)\\s+\\d{4}\\s*,?\\s*(?:de\\s*)?\\d{1,2}\\s*h[.]?\\s*\\d{0,2}\\s*(?:[–—-]\\s*|\\s*(?:à|au)\\s*)\\s*\\d{1,2}\\s*h[.]?\\s*\\d{0,2}\\s*[.!]*$"
    static let sessionLabelLine =
        "^(?:bce|ecricome|prépa|marepared?|mrepared?|banque commune d['’][ée]preuves|math[ée]matiques(?:\\s+(?:i|ii|iii))?|option\\s+(?:scientifique|économique|economique))\\s*[.!?]*$"
    static let presentationConsigne =
        "^(?:[•&·*\\-–—]\\s*)?\\*{0,2}la\\s+présentation,\\s+la\\s+lisibilité[^*$]*?\\bcopies\\b[^*$]*?[.!?;:]?\\s*\\*{0,2}\\s*$"
    static let erreurEnonceConsigne =
        "^(?:[•&·*\\-–—]\\s*)?\\*{0,2}si\\s+au\\s+cours\\s+de\\s+l['’]épreuve[^*$]*?\\binitiatives\\b[^*$]*?\\bprendre\\b[^*$]*?[.!?;:]?\\s*\\*{0,2}\\s*$"
    static let programPerimeterLine =
        "^(?:Le problème utilise(?: uniquement)?\\b|Règle du jeu\\b|Aucun résultat(?: extérieur)?\\b|Aucune propriété\\b|Aucun déterminant\\b|Aucune connaissance\\b|Les objets nouveaux\\b|Les questions ne sont pas rangées\\b|Les résultats des questions\\b|De même, l'expression\\b|Cadre du programme\\b).*$"
    static let justificationConsigne =
        "^(?:[•&·*\\-–—]\\s*)?\\*{0,2}toute\\s+affirmation\\s+devra\\s+[eê]tre\\s+justifi[eé]e?\\*{0,2}\\s*[.!?]?\\s*(?:\\*{0,2}(?:les\\s+r[ée]sultats?\\s+d'une?\\s+question\\b[^*]*|on\\s+pourra\\s+utiliser\\b[^*]*)\\*{0,2}\\s*[.!?]?\\s*)?$"
    static let resultsReuseConsigne =
        "^\\*{0,2}les\\s+r[ée]sultats?\\s+d'une?\\s+question\\s+(?:peuvent|pourra|peut)\\s+[eê]tre\\s+utilis[ée]e?s?\\s+dans\\s+la\\s+suite[^*]*\\*{0,2}\\s*[.!?]?\\s*$"
    static let terminologyFrame =
        "^\\*{0,2}cette\\s+terminologie\\s+(?:est|reste)\\s+(?:propre|impos[ée]e|sp[ée]cifique)\\s+(?:au|du)\\s+probl[èe]me\\b[^*]*\\*{0,2}\\s*[.!?]?\\s*$"

    /// En-tête de sujet de concours isolé sur sa ligne.
    static func isSessionHeaderLine(_ trimmed: String) -> Bool {
        let bare = StmtCruftRules.undecorate(trimmed)
        return StmtRegex.contains(concoursAdmissionLine, in: bare, options: [.caseInsensitive])
            || StmtRegex.contains(sessionSlotLine, in: bare, options: [.caseInsensitive])
            || StmtRegex.contains(sessionLabelLine, in: bare, options: [.caseInsensitive])
    }

    /// Consigne générale reprise d'une année sur l'autre.
    static func isHeaderInstructionLine(_ trimmed: String) -> Bool {
        StmtRegex.contains(presentationConsigne, in: trimmed, options: [.caseInsensitive])
            || StmtRegex.contains(erreurEnonceConsigne, in: trimmed, options: [.caseInsensitive])
    }

    /// Marque une consigne d'astérisques simples, en retirant toute décoration `**`.
    static func markHeaderInstruction(_ trimmed: String) -> String {
        if !isHeaderInstructionLine(trimmed) { return trimmed }
        var bare = StmtRegex.replaceAll("^\\*+", in: trimmed, template: "")
        bare = StmtRegex.replaceAll("\\*+$", in: bare, template: "")
        return "*\(bare.trimmingCharacters(in: .whitespaces))*"
    }

    static func isProgramPerimeterLine(_ trimmed: String) -> Bool {
        let bare = StmtCruftRules.undecorate(trimmed)
        if bare.isEmpty || bare.count > 600 { return false }
        return StmtRegex.contains(programPerimeterLine, in: bare, options: [.caseInsensitive])
    }

    static func isJustificationConsigneLine(_ trimmed: String) -> Bool {
        let bare = StmtCruftRules.undecorate(trimmed)
        if bare.isEmpty || bare.count > 400 { return false }
        return StmtRegex.contains(justificationConsigne, in: bare, options: [.caseInsensitive])
    }

    static func isResultsReuseConsigneLine(_ trimmed: String) -> Bool {
        let bare = StmtCruftRules.undecorate(trimmed)
        if bare.isEmpty || bare.count > 300 { return false }
        return StmtRegex.contains(resultsReuseConsigne, in: bare, options: [.caseInsensitive])
    }

    static func isTerminologyFrameLine(_ trimmed: String) -> Bool {
        let bare = StmtCruftRules.undecorate(trimmed)
        if bare.isEmpty || bare.count > 400 { return false }
        return StmtRegex.contains(terminologyFrame, in: bare, options: [.caseInsensitive])
    }

    /// Vrai si la ligne est une mention éditoriale à retirer.
    static func isCruftLine(_ trimmed: String) -> Bool {
        isSessionHeaderLine(trimmed)
            || StmtCruftRules.isStandaloneDurationLine(trimmed)
            || StmtCruftRules.isMetadataHeadingLine(trimmed)
            || StmtCruftRules.isCalibratedProblemLine(trimmed)
            || StmtCruftRules.isTitleLine(trimmed)
            || StmtCruftRules.isCombinedMetadataLine(trimmed)
            || StmtCruftRules.isLatexSizeTitleLine(trimmed)
            || isProgramPerimeterLine(trimmed)
            || isJustificationConsigneLine(trimmed)
            || isResultsReuseConsigneLine(trimmed)
            || isTerminologyFrameLine(trimmed)
            || StmtCruftPages.isPageMarkerLine(trimmed)
            || StmtCruftPages.isTournezPageLine(trimmed)
            || StmtCruftPages.isOcrPageFooterLine(trimmed)
            || StmtCruftPages.isPageNumberingLine(trimmed)
    }
}
