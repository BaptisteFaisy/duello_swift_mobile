import Foundation

/// Point d'entrée de la mise en page d'énoncé — port de
/// `src/utils/statementLayout.ts`.
///
/// Ce type ne fait que rassembler les briques (segmentation, repères, titres,
/// nettoyage du document) derrière une façade stable, sans dupliquer de logique.
enum StmtLayout {
    /// Blocs de lecture d'un énoncé (`statementLayoutRows`).
    static func rows(_ statement: String) -> [StmtLayoutRow] {
        StmtLayoutRows.statementLayoutRows(statement)
    }

    /// Lignes classées d'un énoncé (`statementDisplayLines`).
    static func displayLines(_ statement: String) -> [StmtDisplayLine] {
        StmtLayoutRows.statementDisplayLines(statement)
    }

    /// Respiration à insérer avant un repère (`statementGapBefore`).
    static func gapBefore(_ rows: [StmtLayoutRow], _ index: Int) -> StmtGap {
        StmtLayoutRows.statementGapBefore(rows, index)
    }

    /// Vrai si la ligne nomme un exercice, une partie ou un problème.
    static func isHeading(_ text: String) -> Bool {
        StmtLayoutHeadings.isStatementHeading(text)
    }

    /// Sépare le numéro d'ouverture du reste de la ligne (`splitQuestionMarker`).
    static func splitQuestionMarker(_ text: String) -> (marker: String, rest: String) {
        StmtLayoutHeadings.splitQuestionMarker(text)
    }

    /// Titre de partie déballé de son gras Markdown (`splitPartieHeading`).
    static func splitPartieHeading(_ text: String) -> String? {
        StmtLayoutHeadings.splitPartieHeading(text)
    }

    /// Fragments de gras et d'italique d'une ligne (`splitEmphasisSpans`).
    static func emphasisSpans(_ line: String) -> [StmtEmphasisSpan] {
        StmtLatexEmphasis.splitEmphasisSpans(line)
    }

    /// Nettoyage mathématique commun (`mathDocumentForDisplay`).
    static func documentForDisplay(_ text: String) -> String {
        StmtLatexPython.mathDocumentForDisplay(text)
    }

    /// Texte d'une fiche d'exercice isolée (`exerciseDocumentForDisplay`).
    static func exerciseDocumentForDisplay(_ text: String) -> String {
        StmtLayoutDocument.exerciseDocumentForDisplay(text)
    }

    /// Recollage des lignes logiques (`normalizeStatementLineBreaks`).
    static func normalizeStatementLineBreaks(_ statement: String) -> String {
        StmtLayoutLines.normalizeStatementLineBreaks(statement)
    }
}
