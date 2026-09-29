//
//  EvEventSubjectFixtures.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : union des sujets
//  d'événements de test (fixtures `test-*`).
//
//  Fichier source Expo porté : `shared/event-catalog.mjs` (`EVENT_SUBJECTS`).
//  Le catalogue ne portait que 5 sujets (4 concours blancs + 1 oral ESCP) : les
//  35 sujets `test-*` manquants sont ajoutés ici, répartis en parties pour tenir
//  le budget de 500 lignes par fichier. `EvEventSubjectCatalog.all` les agrège.
//
//  Cible : iOS 16. Fichier de données statiques.
//
import Foundation

/// Sujets de test du catalogue partagé (`EVENT_SUBJECTS`, entrées `test-*`).
enum EvEventSubjectFixtures {
    /// Union des parties, dans l'ordre du fichier source.
    static let all: [EvEventSubject] =
        EvEventSubjectFixturesPart1.all
        + EvEventSubjectFixturesPart2.all
        + EvEventSubjectFixturesPart3.all
        + EvEventSubjectFixturesPart4.all
}
