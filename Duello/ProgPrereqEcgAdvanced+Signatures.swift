//
//  ProgPrereqEcgAdvanced+Signatures.swift
//  Duello
//
//  Phase 1a — section extraite de `ProgPrereqEcgAdvanced.swift` : empreinte
//  déterministe d'une banque et table des banques ECG approfondies déjà relues
//  (`REVIEWED_ADVANCED_BANK_SIGNATURES`, recopiée à l'identique).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `ReviewableAdvancedItem` : élément de banque entrant dans l'empreinte.
///
/// Couture : `ProgPrereq.Exercise` ne porte ni `id` (→ son `key`) ni `questions`
/// (→ `questionIds`, que seul le porteur de la banque connaît). Le pont est fait
/// par l'appelant : `id ← exercise.key`, `questionIds ←` les questions de la
/// banque. On ne fabrique aucune donnée.
struct AdvancedSignatureItem {
    var id: String
    var title: String
    var statement: String?
    var solution: String?
    var questionIds: [String]
}

extension ProgPrereqEcgAdvanced {

    /// `advancedPrerequisiteSignature` : empreinte FNV-1a 32 bits, légère et
    /// déterministe (non cryptographique). Champs joints par U+001F, entrées par
    /// U+001E, sur les unités UTF-16.
    static func signature(_ items: [AdvancedSignatureItem]) -> String {
        let fieldSeparator = "\u{001f}"
        var source: [UInt16] = []
        for (index, item) in items.enumerated() {
            if index > 0 { source.append(contentsOf: "\u{001e}".utf16) }
            let fields = [
                item.id,
                item.title,
                item.statement ?? "",
                item.solution ?? "",
                item.questionIds.joined(separator: ","),
            ]
            source.append(contentsOf: fields.joined(separator: fieldSeparator).utf16)
        }
        var hash: UInt32 = 0x811c9dc5
        for unit in source {
            hash ^= UInt32(unit)
            hash = hash &* 0x01000193
        }
        return String(format: "%08x", hash)
    }

    /// `REVIEWED_ADVANCED_BANK_SIGNATURES` : une entrée n'est ajoutée qu'après
    /// relecture de la banque correspondante.
    static let reviewedAdvancedBankSignatures: [String: String] = [
        "ecg-approfondies-1:exercice:raisonnement": "de0853a1",
        "ecg-approfondies-1:colle:raisonnement": "b002b995",
        "ecg-approfondies-1:exercice:ensembles-applications": "747e1632",
        "ecg-approfondies-1:exercice:suites": "c4958bcf",
        "ecg-approfondies-1:colle:suites": "8622d708",
        "ecg-approfondies-1:exercice:limites-continuite": "a7e540b6",
        "ecg-approfondies-1:colle:limites-continuite": "b41c0171",
        "ecg-approfondies-1:exercice:fonctions-usuelles": "f1848eec",
        "ecg-approfondies-1:colle:fonctions-usuelles": "291fafcc",
        "ecg-approfondies-1:exercice:derivation": "b10aeb04",
        "ecg-approfondies-1:colle:derivation": "51d5df77",
        "ecg-approfondies-1:exercice:integration": "3179b144",
        "ecg-approfondies-1:colle:integration": "2fe710c7",
        "ecg-approfondies-1:exercice:analyse-asymptotique": "cd590cee",
        "ecg-approfondies-1:colle:analyse-asymptotique": "63092e85",
        "ecg-approfondies-1:exercice:series": "3bdf239a",
        "ecg-approfondies-1:colle:series": "486e7a65",
        "ecg-approfondies-1:exercice:integrales-impropres": "bf7afda5",
        "ecg-approfondies-1:exercice:derivation-successive": "a79e48af",
        "ecg-approfondies-1:exercice:taylor-developpements-limites": "9a548843",
        "ecg-approfondies-1:exercice:matrices": "474f6a79",
        "ecg-approfondies-1:colle:matrices": "a2a83805",
        "ecg-approfondies-1:exercice:systemes-lineaires": "c82aeeec",
        "ecg-approfondies-1:exercice:polynomes": "d555db47",
        "ecg-approfondies-1:colle:polynomes": "1ad1cba1",
        "ecg-approfondies-1:exercice:espaces-vectoriels": "d8671761",
        "ecg-approfondies-1:colle:espaces-vectoriels": "7154317a",
        "ecg-approfondies-1:exercice:applications-lineaires": "3dd3abf4",
        "ecg-approfondies-1:colle:applications-lineaires": "26ff5f9c",
        "ecg-approfondies-1:exercice:matrices-applications-lineaires": "043dacc0",
        "ecg-approfondies-1:exercice:espaces-probabilises-finis": "cb63eb95",
        "ecg-approfondies-1:colle:espaces-probabilises-finis": "28516d9b",
        "ecg-approfondies-1:exercice:espaces-probabilises": "6a755d9b",
        "ecg-approfondies-1:colle:espaces-probabilises": "34bac9ff",
        "ecg-approfondies-1:exercice:variables-discretes": "71357181",
        "ecg-approfondies-1:colle:variables-discretes": "f30a8213",
        "ecg-approfondies-1:exercice:couples-discrets": "f9057921",
        "ecg-approfondies-1:exercice:variables-densite": "d3513fd3",
        "ecg-approfondies-1:exercice:python-approfondies-1-boucles": "66f4f0ab",
        "ecg-approfondies-1:exercice:python-approfondies-1-fonctions": "bcd986ae",
        "ecg-approfondies-1:exercice:python-approfondies-1-matrices": "94659be3",
        "ecg-approfondies-1:exercice:python-approfondies-1-graphiques": "d1a10ae5",
        "ecg-approfondies-1:exercice:python-approfondies-1-probabilites": "0ba9059f",
        "ecg-approfondies-1:exercice:python-approfondies-1-introduction": "26c72604",
        "ecg-approfondies-2:exercice:analyse-concours": "16c8ad50",
        "ecg-approfondies-2:exercice:familles-sommables": "3cf364a1",
        "ecg-approfondies-2:exercice:fonctions-plusieurs-variables": "debb9795",
        "ecg-approfondies-2:exercice:calcul-differentiel": "d3a328b7",
        "ecg-approfondies-2:exercice:algebre-complements": "40f1a76c",
        "ecg-approfondies-2:exercice:changement-base-trace": "1803d050",
        "ecg-approfondies-2:exercice:valeurs-propres": "19bc5fb9",
        "ecg-approfondies-2:exercice:diagonalisation": "89cf4f10",
        "ecg-approfondies-2:exercice:algebre-bilineaire": "f4217bdd",
        "ecg-approfondies-2:exercice:endomorphismes-symetriques": "dc0ac896",
        "ecg-approfondies-2:exercice:complements-variables-aleatoires": "c6e0c4d2",
        "ecg-approfondies-2:exercice:variables-densite": "f80c4dcf",
        "ecg-approfondies-2:exercice:couples-vecteurs": "02f61e99",
        "ecg-approfondies-2:exercice:convergences": "fd84117b",
        "ecg-approfondies-2:exercice:estimation-ponctuelle": "02ca8342",
        "ecg-approfondies-2:exercice:integration-annee-2": "cc710b1f",
        "ecg-approfondies-2:exercice:python-approfondies-2-suites-series": "3549119d",
        "ecg-approfondies-2:exercice:python-approfondies-2-simulation-va": "395af2ed",
        "ecg-approfondies-2:exercice:python-approfondies-2-methodes-inversion": "c443cacb",
        "ecg-approfondies-2:exercice:python-approfondies-2-va-densite": "b7c799a5",
        "ecg-approfondies-2:exercice:python-approfondies-2-fonctions-2-variables": "b687eeb6",
        "ecg-approfondies-2:exercice:python-approfondies-2-monte-carlo": "260b9d62",
        "ecg-approfondies-2:exercice:python-approfondies-2-statistiques": "9b320fce",
        "annale:ecg-approfondies-2-mansuy-ds1": "706ff94d",
        "annale:ecg-approfondies-2-mansuy-ds2": "7c46d5d0",
        "annale:ecg-approfondies-2-mansuy-ds3": "9fe65210",
        "annale:ecg-approfondies-2-mansuy-ds4": "d3fb3a59",
        "annale:ecg-approfondies-2-mansuy-ds5": "a507e81b",
        "annale:ecg-approfondies-2-mansuy-ds6": "3e4d7f8c",
        "annale:ecg-approfondies-2-mansuy-ds7": "474514e4",
        "annale:ecg-approfondies-2-mansuy-ds8": "46bdcca1",
        "annale:ecg-approfondies-2-mansuy-ds9": "210513ae",
        "annale:ecg-approfondies-2-mansuy-ds10": "ed756c87",
        "annale:ecg-approfondies-2-mansuy-ds11": "c1fc06af",
        "annale:ecg-approfondies-2-mansuy-ds12-1": "3bf836c5",
        "annale:ecg-approfondies-2-mansuy-ds12-2": "489b0554",
        "annale:ecg-approfondies-2-mansuy-ds13": "fcabaa3a",
        "annale:ecg-approfondies-2-mansuy-ds14": "dc0c5f1b",
        "annale:ecg-approfondies-2-mansuy-ds15": "2d877424",
        "annale:ecg-approfondies-2-mansuy-ds16": "d6b635cb",
        "annale:escp-oral-2023-sujet-1-2": "1c6cc720",
        "annale:escp-oral-2023-sujet-1-11": "dcedc291",
        "annale:escp-oral-2023-sujet-1-17": "6fe52313",
        "annale:escp-oral-2023-sujet-1-18": "86e14567",
        "annale:escp-oral-2023-sujet-2-1": "c5cb1e0a",
        "annale:escp-oral-2023-sujet-2-4": "7e7f1316",
        "annale:escp-oral-2023-sujet-2-6": "87dea137",
        "annale:escp-oral-2023-sujet-2-7": "ca95e197",
        "annale:escp-oral-2023-sujet-2-8": "596ebb2b",
        "annale:escp-oral-2023-sujet-2-9": "551897b5",
        "annale:escp-oral-2023-sujet-2-11": "1e463f86",
        "annale:escp-oral-2023-sujet-2-12": "e56d2530",
        "annale:escp-oral-2023-sujet-3-3": "64e543b4",
        "annale:escp-oral-2023-sujet-3-12": "97d95b61",
        "annale:escp-oral-2022-sujet-1-7": "4746a787",
        "annale:escp-oral-2022-sujet-1-55": "d70dbd6d",
        "annale:escp-oral-2022-sujet-3-9": "102f810a",
        "annale:escp-oral-2022-sujet-3-10": "431a0400",
        "annale:escp-oral-2022-sujet-3-17": "6ac3a431",
        "annale:escp-oral-2022-sujet-3-19": "f98b4b74",
        "annale:escp-oral-2022-sujet-3-25": "d3523212",
        "annale:escp-oral-2022-sujet-3-53": "ca604cbb",
        "annale:escp-oral-2022-sujet-3-59": "c9623137",
        "annale:escp-oral-2022-sujet-3-61": "c8212ded",
        "annale:escp-oral-2021-sujet-3-9": "a3472188",
        "annale:escp-oral-2021-sujet-3-13": "0782d55c",
        "annale:escp-oral-2021-sujet-3-16": "01b5aa08",
        "annale:escp-oral-2021-sujet-3-18": "a45cc498",
        "annale:escp-oral-2021-sujet-3-19": "a5e34e9c",
        "annale:escp-oral-2019-sujet-3-2": "d2f01428",
        "annale:escp-oral-2019-sujet-3-3": "a149d105",
        "annale:escp-oral-2019-sujet-3-18": "b5fb887f",
        "annale:escp-oral-2019-sujet-3-19": "d6642e9a",
        "annale:escp-oral-2019-sujet-3-21": "910ef0f2",
        "annale:escp-oral-2018-sujet-2-2": "c7fa83ec",
        "annale:escp-oral-2018-sujet-2-7": "d79af740",
        "annale:escp-oral-2018-sujet-3-2": "4e9e8281",
        "annale:escp-oral-2018-sujet-3-10": "c44ea23f",
        "annale:escp-oral-2018-sujet-3-11": "b18760f9",
        "annale:escp-oral-2018-sujet-3-13": "a48ae559",
        "annale:escp-oral-2018-sujet-3-16": "49dd3d17",
        "annale:escp-oral-2018-sujet-3-17": "448a7016",
        "annale:escp-oral-2025-sujet-1-1": "b959ade5",
        "annale:escp-oral-2025-sujet-1-2": "f4367144",
        "annale:escp-oral-2025-sujet-2-1": "fd5387fc",
        "annale:escp-oral-2025-sujet-2-2": "17a41fde",
        "annale:escp-oral-2025-sujet-2-3": "6e00ebe9",
        "annale:escp-oral-2025-sujet-2-4": "0f757837",
        "annale:escp-oral-2025-sujet-2-5": "ef4a80a8",
        "annale:escp-oral-2025-sujet-3-1": "ad85af37",
        "annale:escp-oral-2025-sujet-3-2": "a8f10d22",
        "annale:escp-oral-2025-sujet-3-3": "e66db2cd",
        "annale:escp-oral-2025-sujet-3-4": "64b499f4",
        "annale:escp-oral-2025-sujet-3-5": "edaba7ef",
        "annale:escp-oral-2025-sujet-3-6": "acb12b3f",
        "annale:escp-oral-2025-sujet-3-7": "cf491f85",
        "annale:escp-oral-2025-sujet-3-8": "7a02847e",
        "annale:escp-oral-2025-qsp-1": "5a0827fe",
        "annale:escp-oral-2025-qsp-2": "30e421f1",
        "annale:escp-oral-2025-qsp-3": "19b822e9",
    ]
}
