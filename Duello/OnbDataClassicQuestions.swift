//
//  OnbDataClassicQuestions.swift
//  Duello
//
//  Registre éditorial des questions « classiques » (étoilées). Porté de l'app
//  Expo :
//    - src/data/classicQuestions.ts (`CLASSIC_QUESTION_IDS`,
//      `defineClassicQuestionRegistry`, `classicQuestionIds`,
//      `classicQuestionCount`, `isClassicQuestion`, `filterItemsByClassic`)
//    - src/utils/statementQuestions.ts (`annaleQuestionId`)
//
//  Une étoile cible un sujet et une question, avec les mêmes identifiants que
//  la progression de l'élève et le lecteur d'annales : les points sont retirés
//  (« 2.b » devient « 2b »). Aucune dépendance externe. Cible : iOS 16.
//

import Foundation

/// Questions classiques par sujet (`CLASSIC_QUESTION_REGISTRY`).
enum OnbDataClassicQuestions {
    /// Sujet étoilé (`ClassicQuestionSubject`) : identifiants stables et total.
    struct Subject: Equatable {
        /// Identifiants des questions validées comme méthodes classiques.
        let questionIds: [String]
        /// Nombre d'étoiles, toujours dérivé des identifiants (`totalStars`).
        var totalStars: Int { questionIds.count }
    }

    /// Registre de production (`CLASSIC_QUESTION_REGISTRY`).
    static let registry: [String: Subject] = buildRegistry(source)

    /// `classicQuestionIds` : identifiants classiques d'un sujet (vide si
    /// inconnu).
    static func classicQuestionIds(_ itemId: String?) -> [String] {
        guard let itemId, let subject = registry[itemId] else { return [] }
        return subject.questionIds
    }

    /// `classicQuestionCount` : nombre d'étoiles d'un sujet (0 si inconnu).
    static func classicQuestionCount(_ itemId: String?) -> Int {
        guard let itemId, let subject = registry[itemId] else { return 0 }
        return subject.totalStars
    }

    /// Le sujet porte-t-il au moins une étoile ? (`classicQuestionCount > 0`).
    static func containsClassic(_ itemId: String?) -> Bool {
        classicQuestionCount(itemId) > 0
    }

    /// `isClassicQuestion` : la question est-elle étoilée dans ce sujet ?
    static func isClassicQuestion(_ itemId: String?, _ questionId: String) -> Bool {
        classicQuestionIds(itemId).contains(questionId)
    }

    /// `filterItemsByClassic` : ne conserve que les sujets étoilés quand
    /// `classicsOnly` est vrai. `id` extrait l'identifiant d'item de chaque
    /// élément, le type des items n'étant pas imposé.
    static func filterItemsByClassic<T>(
        _ items: [T],
        classicsOnly: Bool,
        id: (T) -> String
    ) -> [T] {
        classicsOnly ? items.filter { containsClassic(id($0)) } : items
    }

    /// `annaleQuestionId` : retire les points d'un libellé de question
    /// (« 2.b » → « 2b »), identifiant stable partagé avec le lecteur.
    static func annaleQuestionId(_ label: String) -> String {
        label.replacingOccurrences(of: ".", with: "")
    }

    // MARK: Registre

    /// Construit le registre en normalisant et élaguant les identifiants. La
    /// source Expo lève une erreur sur une cible vide ou dupliquée ; ici, sans
    /// interrompre le programme, les entrées invalides sont écartées et les
    /// doublons internes réduits au premier, la source livrée étant déjà
    /// valide (166 sujets, 182 étoiles).
    private static func buildRegistry(_ source: [(String, [String])]) -> [String: Subject] {
        var registry: [String: Subject] = [:]
        for (rawItemId, rawIds) in source {
            let itemId = rawItemId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !itemId.isEmpty else { continue }
            var seen = Set<String>()
            var ids: [String] = []
            for raw in rawIds {
                let id = annaleQuestionId(raw.trimmingCharacters(in: .whitespacesAndNewlines))
                guard !id.isEmpty, seen.insert(id).inserted else { continue }
                ids.append(id)
            }
            guard !ids.isEmpty else { continue }
            registry[itemId] = Subject(questionIds: ids)
        }
        return registry
    }

    /// Source éditoriale (`CLASSIC_QUESTION_IDS`), libellés sous leur forme
    /// lisible ; `buildRegistry` les convertit dans l'identifiant stable.
    private static let source: [(String, [String])] = [
        ("suites::exercice::suites-exercice-9", ["1", "2"]),
        ("suites::exercice::suites-exercice-11", ["3"]),
        ("suites::exercice::suites-exercice-12", ["1"]),
        ("suites::exercice::suites-exercice-14", ["resolution"]),
        ("suites::exercice::suites-exercice-16", ["resolution"]),
        ("suites::exercice::suites-exercice-18", ["2"]),
        ("suites::exercice::suites-exercice-19", ["3"]),
        ("suites::exercice::suites-exercice-26", ["2"]),
        ("suites::exercice::suites-exercice-29", ["4"]),
        ("suites::exercice::suites-exercice-31", ["2.b"]),
        ("matrices::exercice::matrices-exercice-9", ["2"]),
        ("matrices::exercice::matrices-exercice-10", ["3"]),
        ("matrices::exercice::matrices-exercice-12", ["resolution"]),
        ("matrices::exercice::matrices-exercice-14", ["1"]),
        ("matrices::exercice::matrices-exercice-16", ["2"]),
        ("matrices::exercice::matrices-exercice-18", ["2"]),
        ("matrices::exercice::matrices-exercice-19", ["2.b"]),
        ("matrices::exercice::matrices-exercice-22", ["resolution"]),
        ("polynomes::exercice::polynomes-exercice-5", ["2.a"]),
        ("polynomes::exercice::polynomes-exercice-8", ["resolution"]),
        ("polynomes::exercice::polynomes-exercice-10", ["resolution"]),
        ("polynomes::exercice::polynomes-exercice-12", ["resolution"]),
        ("polynomes::exercice::polynomes-exercice-15", ["resolution"]),
        ("polynomes::exercice::polynomes-exercice-20", ["2.a"]),
        ("polynomes::exercice::polynomes-exercice-21", ["2"]),
        ("limites::exercice::limites-exercice-3", ["b"]),
        ("limites::exercice::limites-exercice-4", ["2.a"]),
        ("limites::exercice::limites-exercice-6", ["3"]),
        ("limites::exercice::limites-exercice-8", ["1", "2"]),
        ("limites::exercice::limites-exercice-9", ["a"]),
        ("limites::exercice::limites-exercice-11", ["9.c"]),
        ("ensembles::exercice::ensembles-exercice-4", ["4"]),
        ("ensembles::exercice::ensembles-exercice-6", ["2"]),
        ("ensembles::exercice::ensembles-exercice-8", ["1"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-3", ["resolution"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-5", ["1"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-7", ["resolution"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-9", ["resolution"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-10", ["2"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-11", ["1"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-14", ["2.a"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-15", ["3"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-19", ["2"]),
        ("probabilites-finies::exercice::probabilites-finies-exercice-22", ["1"]),
        ("continuite::exercice::continuite-exercice-4", ["resolution"]),
        ("continuite::exercice::continuite-exercice-6", ["2"]),
        ("continuite::exercice::continuite-exercice-7", ["resolution"]),
        ("continuite::exercice::continuite-exercice-8", ["1"]),
        ("continuite::exercice::continuite-exercice-10", ["2"]),
        ("continuite::exercice::continuite-exercice-11", ["4"]),
        ("continuite::exercice::continuite-exercice-12", ["5"]),
        ("introduction-espaces-vectoriels::exercice::introduction-espaces-vectoriels-exercice-2", ["resolution"]),
        ("introduction-espaces-vectoriels::exercice::introduction-espaces-vectoriels-exercice-5", ["2"]),
        ("introduction-espaces-vectoriels::exercice::introduction-espaces-vectoriels-exercice-9", ["2"]),
        ("introduction-espaces-vectoriels::exercice::introduction-espaces-vectoriels-exercice-14", ["resolution"]),
        ("introduction-espaces-vectoriels::exercice::introduction-espaces-vectoriels-exercice-16", ["1"]),
        ("introduction-espaces-vectoriels::exercice::introduction-espaces-vectoriels-exercice-20", ["1"]),
        ("introduction-espaces-vectoriels::exercice::introduction-espaces-vectoriels-exercice-21", ["resolution"]),
        ("introduction-espaces-vectoriels::exercice::introduction-espaces-vectoriels-exercice-23", ["2"]),
        ("derivabilite::exercice::derivabilite-exercice-7", ["1.a"]),
        ("derivabilite::exercice::derivabilite-exercice-8", ["4"]),
        ("derivabilite::exercice::derivabilite-exercice-9", ["2"]),
        ("derivabilite::exercice::derivabilite-exercice-10", ["3"]),
        ("derivabilite::exercice::derivabilite-exercice-13", ["resolution"]),
        ("derivabilite::exercice::derivabilite-exercice-16", ["resolution"]),
        ("derivabilite::exercice::derivabilite-exercice-17", ["4"]),
        ("derivabilite::exercice::derivabilite-exercice-18", ["3"]),
        ("derivabilite::exercice::derivabilite-exercice-19", ["3"]),
        ("derivabilite::exercice::derivabilite-exercice-20", ["2.b"]),
        ("derivabilite::exercice::derivabilite-exercice-21", ["resolution"]),
        ("derivabilite::exercice::derivabilite-exercice-26", ["3.b"]),
        ("variables-finies::exercice::variables-finies-exercice-5", ["resolution"]),
        ("variables-finies::exercice::variables-finies-exercice-6", ["3"]),
        ("variables-finies::exercice::variables-finies-exercice-7", ["2"]),
        ("variables-finies::exercice::variables-finies-exercice-8", ["1"]),
        ("variables-finies::exercice::variables-finies-exercice-9", ["4"]),
        ("variables-finies::exercice::variables-finies-exercice-13", ["resolution"]),
        ("variables-finies::exercice::variables-finies-exercice-14", ["resolution"]),
        ("variables-finies::exercice::variables-finies-exercice-15", ["1"]),
        ("variables-finies::exercice::variables-finies-exercice-17", ["3"]),
        ("variables-finies::exercice::variables-finies-exercice-18", ["2"]),
        ("variables-finies::exercice::variables-finies-exercice-19", ["4"]),
        ("variables-finies::exercice::variables-finies-exercice-23", ["1.a"]),
        ("variables-finies::exercice::variables-finies-exercice-24", ["resolution"]),
        ("variables-finies::exercice::variables-finies-exercice-25", ["3"]),
        ("variables-finies::exercice::variables-finies-exercice-26", ["3"]),
        ("applications-bijectives::exercice::applications-bijectives-exercice-7", ["resolution"]),
        ("applications-bijectives::exercice::applications-bijectives-exercice-8", ["2"]),
        ("applications-bijectives::exercice::applications-bijectives-exercice-10", ["resolution"]),
        ("applications-bijectives::exercice::applications-bijectives-exercice-11", ["2"]),
        ("applications-bijectives::exercice::applications-bijectives-exercice-13", ["resolution"]),
        ("applications-bijectives::exercice::applications-bijectives-exercice-17", ["4"]),
        ("integration::exercice::integration-exercice-6", ["2"]),
        ("integration::exercice::integration-exercice-7", ["resolution"]),
        ("integration::exercice::integration-exercice-8", ["2"]),
        ("integration::exercice::integration-exercice-9", ["3"]),
        ("integration::exercice::integration-exercice-10", ["3"]),
        ("integration::exercice::integration-exercice-11", ["2"]),
        ("integration::exercice::integration-exercice-12", ["3", "5"]),
        ("integration::exercice::integration-exercice-13", ["1", "2"]),
        ("integration::exercice::integration-exercice-16", ["resolution"]),
        ("integration::exercice::integration-exercice-18", ["5"]),
        ("integration::exercice::integration-exercice-19", ["4"]),
        ("integration::exercice::integration-exercice-20", ["c"]),
        ("integration::exercice::integration-exercice-22", ["resolution"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-7", ["3"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-9", ["2"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-10", ["3"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-13", ["4"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-14", ["3"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-17", ["3"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-18", ["3"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-20", ["3"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-22", ["3"]),
        ("applications-lineaires::exercice::applications-lineaires-exercice-23", ["3"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-7", ["1"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-8", ["2"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-9", ["1"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-10", ["3"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-17", ["4"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-19", ["6"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-20", ["2"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-21", ["1"]),
        ("matrices-applications-lineaires::exercice::applications-lineaires-matrices-exercice-22", ["resolution"]),
        ("couples-discrets::exercice::couples-exercice-2", ["3.a"]),
        ("couples-discrets::exercice::couples-exercice-3", ["3"]),
        ("couples-discrets::exercice::couples-exercice-4", ["4"]),
        ("couples-discrets::exercice::couples-exercice-6", ["4"]),
        ("couples-discrets::exercice::couples-exercice-8", ["2"]),
        ("couples-discrets::exercice::couples-exercice-9", ["7"]),
        ("couples-discrets::exercice::couples-exercice-10", ["2"]),
        ("couples-discrets::exercice::couples-exercice-11", ["5"]),
        ("couples-discrets::exercice::couples-exercice-13", ["2"]),
        ("couples-discrets::exercice::couples-exercice-15", ["2"]),
        ("couples-discrets::exercice::couples-exercice-16", ["1", "4"]),
        ("couples-discrets::exercice::couples-exercice-17", ["4"]),
        ("variables-densite::exercice::variables-densite-exercice-2", ["3"]),
        ("variables-densite::exercice::variables-densite-exercice-3", ["3"]),
        ("variables-densite::exercice::variables-densite-exercice-4", ["4.c"]),
        ("variables-densite::exercice::variables-densite-exercice-6", ["3", "4.a"]),
        ("variables-densite::exercice::variables-densite-exercice-7", ["3.a", "3.b"]),
        ("variables-densite::exercice::variables-densite-exercice-8", ["resolution"]),
        ("variables-densite::exercice::variables-densite-exercice-9", ["3"]),
        ("variables-densite::exercice::variables-densite-exercice-10", ["2.a"]),
        ("variables-densite::exercice::variables-densite-exercice-12", ["2.b"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-4", ["resolution"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-6", ["resolution"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-7", ["2"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-8", ["resolution"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-9", ["2"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-12", ["2"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-14", ["2"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-15", ["2.b"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-17", ["3.b"]),
        ("espaces-vectoriels::exercice::complements-algebre-exercice-18", ["3.b"]),
        ("fonctions-usuelles::exercice::convexite-exercice-1", ["1.b"]),
        ("fonctions-usuelles::exercice::convexite-exercice-5", ["2", "3", "5"]),
        ("fonctions-usuelles::exercice::convexite-exercice-10", ["2", "3"]),
        ("fonctions-usuelles::exercice::convexite-exercice-11", ["2"]),
        ("fonctions-usuelles::exercice::convexite-exercice-13", ["resolution"]),
        ("fonctions-usuelles::exercice::convexite-exercice-14", ["3"]),
        ("fonctions-usuelles::exercice::convexite-exercice-15", ["2"]),
        ("analyse-asymptotique::exercice::revisions-cb2-exercice-1", ["4.b", "5.c", "5.d"]),
        ("analyse-asymptotique::exercice::revisions-cb2-exercice-2", ["4.c", "5.a"]),
        ("analyse-asymptotique::exercice::revisions-cb2-exercice-3", ["2.c", "3.f", "4.c"]),
        ("analyse-asymptotique::exercice::revisions-cb2-exercice-5", ["1.b", "2.d"]),
    ]
}
