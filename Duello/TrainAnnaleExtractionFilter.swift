import Foundation

/**
 * Filtre des extraits d'annales dans la section Exercices.
 *
 * Les banques d'exercices ECG mélangent des énoncés de cours/TD et des sujets
 * repris tels quels des concours (énoncés d'annales). La section Exercices ne
 * doit montrer que les premiers : les sujets de concours restent disponibles
 * dans la section Annales, et les colles ne sont pas concernées.
 *
 * Deux signaux, validés par audit éditorial corpus par corpus :
 *  1. familles de clés connues comme recueils d'annales (banques montées
 *     depuis le Drive « Annales » / « Calculs d'annales » ou DS repris
 *     verbatim d'un sujet de concours) ;
 *  2. en-tête d'attribution en ouverture du titre ou de l'énoncé
 *     (« Edhec 2018 », « HEC 2014 », « Extrait de EML 2016 », « D'après
 *     EDHEC 2023 »…). Le signal est borné en position : une mention de
 *     concours au milieu d'un propos de cours (« voir EDHEC 2008 ») n'est
 *     PAS un extrait d'annale.
 */

struct TrainAnnaleExtractionSeed: Equatable {
    var key: String
    var title: String?
    var statement: String?
}

/// Recueils entièrement constitués d'annales ou de sujets repris verbatim.
let ANNALE_KEY_PREFIXES = [
    // Recueils « Annales » et « Calculs d'annales » du Drive maths ECG.
    "mathsecg-annales-",
    "mathsecg-calculs-",
    // DS LETPA repris verbatim du sujet ESSEC 2022 (les DS0/DS1, créations
    // maison, restent des exercices de classe).
    "letpa-ds2-essec-2022",
]

/**
 * Nom de concours suivi d'une millésime : la forme canonique d'une
 * attribution d'énoncé. Fenêtre courte entre nom et année pour éviter les
 * rapprochements hasardeux à travers la phrase.
 */
let CONCOURS_NAME_YEAR = try! NSRegularExpression(
    pattern: "\\b(?:hec|essec|escp(?:e)?|edhec|em\\s?lyon|eml|ecricome)\\b[^.\\n]{0,24}?\\b(?:19|20)\\d{2}\\b",
    options: [.caseInsensitive]
)

/** Longueur d'ouverture d'énoncé dans laquelle une attribution est credible.
 * Au-delà, une mention de concours relève du propos de cours (« fréquente aux
 * concours (Edhec 2016 par exemple) ») et ne signale pas un extrait d'annale. */
let ATTRIBUTION_OPENING_LENGTH = 90

private func keyMatches(_ key: String) -> Bool {
    let normalized = key.lowercased()
    return ANNALE_KEY_PREFIXES.contains { normalized.hasPrefix($0) }
}

private func openingAttribution(_ text: String?) -> Bool {
    guard let text = text else { return false }
    let opening = String(text.prefix(ATTRIBUTION_OPENING_LENGTH))
    let range = NSRange(opening.startIndex..., in: opening)
    return CONCOURS_NAME_YEAR.firstMatch(in: opening, options: [], range: range) != nil
}

/**
 * Vrai si l'énoncé est un extrait d'annale (sujet de concours repris tel
 * quel) et doit donc être masqué dans la section Exercices.
 */
func isAnnaleExtraction(_ seed: TrainAnnaleExtractionSeed) -> Bool {
    // Les sujets historiques ESSEC « Maths I-III » ont été découpés en exercices
    // unitaires et dispatchés dans les chapitres ECG2 : ce sont des exercices de
    // chapitre, pas des extraits d'annales repris tels quels.
    if seed.key.hasPrefix("maths-i-iii-") { return false }
    if keyMatches(seed.key) { return true }
    if openingAttribution(seed.title) { return true }
    return openingAttribution(seed.statement)
}

/// Variante tableau : ne garde que les énoncés qui ne sont pas des annales.
func dropAnnaleExtractions(_ seeds: [TrainAnnaleExtractionSeed]) -> [TrainAnnaleExtractionSeed] {
    return seeds.filter { !isAnnaleExtraction($0) }
}
