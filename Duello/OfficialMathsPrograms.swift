//
//  OfficialMathsPrograms.swift
//  Duello
//
//  Port de `src/data/officialMathsPrograms.ts` (RN) — catalogue des programmes
//  officiels de mathématiques, par filière et par année.
//
//  C'est la seule source des adresses des textes officiels : le prof IA les
//  reçoit dans sa fenêtre de contexte (`ProfStudentContext.swift`), et aucune
//  vue ne réécrit un libellé. Une entrée porte `url == nil` tant que l'adresse
//  officielle n'est pas connue : le prof reçoit alors le libellé sans lien,
//  plutôt qu'une adresse inventée.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Année couverte par une entrée : année de prépa (`1`/`2`), ou classe de
/// lycée (`2de`/`1re`/`Terminale`) — `MathsProgramScope` de la source.
enum OfficialMathsProgramScope: Equatable, Hashable {
    /// Année de classe préparatoire (`ProgramYear`).
    case programYear(Int)
    /// Classe du lycée (`LyceeYear`).
    case lyceeYear(String)
}

/// Une entrée du catalogue (`MathsProgram`).
struct OfficialMathsProgram: Equatable {
    /// Filière telle que Duello l'écrit dans le parcours de l'élève.
    let track: String
    /// Année de prépa, ou classe du lycée.
    let scope: OfficialMathsProgramScope
    /// Option d'ECG (`appliquees`/`approfondies`), absente des autres filières.
    let option: String?
    /// Programme de mathématiques suivi en terminale, absent quand la classe
    /// n'a qu'un seul programme de maths.
    let lyceeOption: String?
    /// Intitulé complet, tel qu'il est écrit au prof.
    let label: String
    /// Adresse du texte officiel ; `nil` tant qu'elle n'est pas connue.
    let url: String?
}

// MARK: - Adresses officielles

/// Annexe du programme de MPSI/MP2I (prepping inter-établissements).
private let programmePreparing = "https://prepas.org/ups.php?document=69"

/// Programmes du lycée : annexes du ministère. Ces adresses encodent leur titre
/// et dépassent deux cent cinquante caractères : le relais leur réserve un
/// plafond à part, sinon il les couperait et transmettrait un lien mort.
private let programmeTerminaleSpecialiteMaths =
    "https://www.education.gouv.fr/sites/default/files/document/Annexe%20–%20Programme%20de%20l%26%23039%3Benseignement%20de%20spécialité%20de%20mathématiques%20de%20la%20classe%20terminale%20de%20la%20voie%20générale-515414.pdf"
private let programmeTerminaleMathsComplementaires =
    "https://www.education.gouv.fr/sites/default/files/document/Annexe%20–%20Programme%20de%20l%26%23039%3Benseignement%20optionnel%20de%20mathématiques%20complémentaires%20de%20la%20classe%20terminale%20de%20la%20voie%20générale-515417.pdf"
private let programmeTerminaleMathsExpertes =
    "https://eduscol.education.gouv.fr/sites/default/files/document/spe264annexe1158825pdf-84165.pdf"
private let programmePremiereSpecialiteMaths =
    "https://www.education.gouv.fr/sites/default/files/document/Annexe%20–%20Programme%20d%26%23039%3Benseignement%20de%20spécialité%20de%20mathématiques%20de%20la%20classe%20de%20première%20de%20la%20voie%20générale-515408.pdf"
private let programmeSeconde =
    "https://www.education.gouv.fr/sites/default/files/document/Annexe%20–%20Programme%20d%26%23039%3Benseignement%20de%20mathématiques%20de%20la%20classe%20de%20seconde%20générale%20et%20technologique-515402.pdf"

/// `MATHS_PROGRAMS` : catalogue complet, dans l'ordre de la source.
let MATHS_PROGRAMS: [OfficialMathsProgram] = [
    OfficialMathsProgram(
        track: "ECG", scope: .programYear(1), option: "approfondies",
        lyceeOption: nil, label: "ECG 1re année — mathématiques approfondies",
        url: "https://cache.media.education.gouv.fr/file/SPE1-MEN-MESRI-4-2-2021/64/0/spe776_annexe_1373640.pdf"),
    OfficialMathsProgram(
        track: "ECG", scope: .programYear(1), option: "appliquees",
        lyceeOption: nil, label: "ECG 1re année — mathématiques appliquées",
        url: "https://cache.media.education.gouv.fr/file/SPE1-MEN-MESRI-4-2-2021/64/0/spe776_annexe_1373640.pdf"),
    OfficialMathsProgram(
        track: "ECG", scope: .programYear(2), option: "approfondies",
        lyceeOption: nil, label: "ECG 2e année — mathématiques approfondies",
        url: "https://cache.media.education.gouv.fr/file/SPE1-MEN-MESRI-4-2-2021/64/0/spe776_annexe_1373640.pdf"),
    OfficialMathsProgram(
        track: "ECG", scope: .programYear(2), option: "appliquees",
        lyceeOption: nil, label: "ECG 2e année — mathématiques appliquées",
        url: "https://cache.media.education.gouv.fr/file/SPE1-MEN-MESRI-4-2-2021/64/0/spe776_annexe_1373640.pdf"),
    OfficialMathsProgram(
        track: "MPSI", scope: .programYear(1), option: nil,
        lyceeOption: nil, label: "MPSI 1re année", url: programmePreparing),
    OfficialMathsProgram(
        track: "MP2I", scope: .programYear(1), option: nil,
        lyceeOption: nil, label: "MP2I 1re année", url: programmePreparing),
    OfficialMathsProgram(
        track: "MP", scope: .programYear(2), option: nil, lyceeOption: nil,
        label: "MP 2e année",
        url: "https://cache.media.education.gouv.fr/file/31/08/5/ensecsup702_annexes_1417085.pdf"),
    OfficialMathsProgram(
        track: "MPI", scope: .programYear(2), option: nil, lyceeOption: nil,
        label: "MPI 2e année",
        url: "https://cache.media.education.gouv.fr/file/31/08/5/ensecsup702_annexes_1417085.pdf"),
    OfficialMathsProgram(
        track: "PCSI", scope: .programYear(1), option: nil, lyceeOption: nil,
        label: "PCSI 1re année",
        url: "https://cache.media.education.gouv.fr/file/SPE1-MEN-MESRI-4-2-2021/65/0/spe780_annexe_1373650.pdf"),
    OfficialMathsProgram(
        track: "PC", scope: .programYear(2), option: nil, lyceeOption: nil,
        label: "PC 2e année", url: "https://prepas.org/ups.php?document=91"),
    OfficialMathsProgram(
        track: "PTSI", scope: .programYear(1), option: nil, lyceeOption: nil,
        label: "PTSI 1re année",
        url: "https://cache.media.education.gouv.fr/file/SPE1-MEN-MESRI-4-2-2021/65/2/spe781_annexe_1373652.pdf"),
    OfficialMathsProgram(
        track: "PT", scope: .programYear(2), option: nil, lyceeOption: nil,
        label: "PT 2e année", url: "https://prepas.org/ups.php?document=95"),
    OfficialMathsProgram(
        track: "PSI", scope: .programYear(2), option: nil, lyceeOption: nil,
        label: "PSI 2e année", url: "https://prepas.org/ups.php?document=93"),
    OfficialMathsProgram(
        track: "BCPST", scope: .programYear(1), option: nil, lyceeOption: nil,
        label: "BCPST 1re année",
        url: "https://cache.media.education.gouv.fr/file/20/94/8/ensecsup111_annexes_1407948.pdf"),
    OfficialMathsProgram(
        track: "BCPST", scope: .programYear(2), option: nil, lyceeOption: nil,
        label: "BCPST 2e année",
        url: "https://cache.media.education.gouv.fr/file/20/94/8/ensecsup111_annexes_1407948.pdf"),
    OfficialMathsProgram(
        track: "B/L", scope: .programYear(1), option: nil, lyceeOption: nil,
        label: "B/L 1re année",
        url: "https://apml-maths.com/wp-content/uploads/2026/06/Programme-maths-BL-2026-joe_20260416.pdf"),
    OfficialMathsProgram(
        track: "B/L", scope: .programYear(2), option: nil, lyceeOption: nil,
        label: "B/L 2e année",
        url: "https://apml-maths.com/wp-content/uploads/2026/06/Programme-maths-BL-2026-joe_20260416.pdf"),
    OfficialMathsProgram(
        track: "Lycée", scope: .lyceeYear("2de"), option: nil, lyceeOption: nil,
        label: "Seconde — programme de mathématiques", url: programmeSeconde),
    OfficialMathsProgram(
        track: "Lycée", scope: .lyceeYear("1re"), option: nil, lyceeOption: nil,
        label: "Première — spécialité mathématiques", url: programmePremiereSpecialiteMaths),
    OfficialMathsProgram(
        track: "Lycée", scope: .lyceeYear("Terminale"), option: nil,
        lyceeOption: "Spécialité mathématiques",
        label: "Terminale — spécialité mathématiques", url: programmeTerminaleSpecialiteMaths),
    OfficialMathsProgram(
        track: "Lycée", scope: .lyceeYear("Terminale"), option: nil,
        lyceeOption: "Maths complémentaires",
        label: "Terminale — mathématiques complémentaires",
        url: programmeTerminaleMathsComplementaires),
    OfficialMathsProgram(
        track: "Lycée", scope: .lyceeYear("Terminale"), option: nil,
        lyceeOption: "Maths expertes",
        label: "Terminale — mathématiques expertes", url: programmeTerminaleMathsExpertes),
    OfficialMathsProgram(
        track: "Lycée", scope: .lyceeYear("Terminale"), option: nil,
        lyceeOption: OnbFlowAcademic.lyceeSpePlusExpertesValue,
        label: "Terminale — spécialité mathématiques et mathématiques expertes",
        // Deux textes à la fois : aucune adresse unique ne les résumerait. Le
        // libellé nomme les deux programmes, et le prof trouve chacun sur les
        // deux entrées voisines.
        url: nil),
]

// MARK: - Recherche

/// Ce que l'écran sait du parcours affiché (`MathsProgramQuery`).
struct OfficialMathsProgramQuery {
    /// Filière de l'année affichée, après `academicProgramSelection`.
    var track: String
    /// Année affichée ; ignorée dès qu'une classe de lycée est fournie.
    var programYear: Int
    /// Classe du lycée, quand la filière suivie en est une.
    var lyceeYear: String?
    /// Parcours de mathématiques d'ECG : `appliquees` ou `approfondies`.
    var mathsOption: String?
    /// Spécialité de mathématiques suivie en terminale.
    var lyceeOption: String?
}

/// L'option qui distingue deux programmes, ou `nil` s'il n'y en a qu'un
/// (`programOption`).
private func mathsProgramOption(_ program: OfficialMathsProgram, isLycee: Bool) -> String? {
    isLycee ? program.lyceeOption : program.option
}

/// Programme officiel du parcours affiché (`findMathsProgram`).
///
/// L'option demandée l'emporte ; à défaut, la filière retombe sur son programme
/// unique — c'est le cas de MPSI, dont l'option (informatique, sciences
/// industrielles) ne change pas le programme de mathématiques. Une filière
/// absente du catalogue ne rend pas d'erreur : `nil`, et le prof reçoit
/// l'intitulé de repli construit par l'appelant, sans lien à faux.
func findMathsProgram(_ query: OfficialMathsProgramQuery) -> OfficialMathsProgram? {
    let isLycee = query.lyceeYear != nil
    let scope: OfficialMathsProgramScope = query.lyceeYear.map { .lyceeYear($0) }
        ?? .programYear(query.programYear)
    let demandee = isLycee ? query.lyceeOption : query.mathsOption
    let candidats = MATHS_PROGRAMS.filter {
        $0.track == query.track && $0.scope == scope
    }
    if let demandee {
        if let exact = candidats.first(where: {
            mathsProgramOption($0, isLycee: isLycee) == demandee
        }) {
            return exact
        }
    }
    return candidats.first { mathsProgramOption($0, isLycee: isLycee) == nil }
}
