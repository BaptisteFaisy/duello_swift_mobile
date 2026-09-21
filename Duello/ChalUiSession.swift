//
//  ChalUiSession.swift
//  Duello
//
//  Lot 11-A — types de session de l'écran Défis : la section d'accueil ouverte
//  et les règles de partie.
//
//  Fichiers source Expo portés (noms et valeurs repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx (plage 166-410) :
//      `ChallengeHomeSection`, `MATCH_REVEAL_MS`, `PLAYERS_PER_CHALLENGE`.
//
//  Réutilise sans les recréer (portés ailleurs dans ce dépôt, lot 11-C) :
//    - `RunningSession` de la source est déjà porté (`ChalRunRoundState`) ;
//    - `SessionResult` de la source est déjà porté (`ChalRunResult`) ;
//    - `formatElo` de la source est déjà porté (`ChalRunFormat.elo`,
//      `groupedNumber`).
//  Aucun de ces symboles n'est donc redéfini ici (unicité des types).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Espace ouvert en tête de l'écran Défis (`ChallengeHomeSection`).
///
/// Les défis restent l'accueil : l'ajout des événements ne déplace aucun geste
/// existant par défaut. Le pager Défis / Événements et le swipe partagent ce
/// même état.
enum ChalUiChallengeHomeSection: String, CaseIterable, Equatable {
    case challenges
    case events

    /// Section d'ouverture (`useState<ChallengeHomeSection>('challenges')`).
    static let opening: ChalUiChallengeHomeSection = .challenges

    /// Rang de page du pager, dans l'ordre des sections.
    var pageIndex: Int {
        switch self {
        case .challenges: return 0
        case .events: return 1
        }
    }

    /// Section correspondant à une page du pager
    /// (`handleHomeSectionPageSelected`) : la page 1 est Événements, le reste
    /// retombe sur Défis.
    static func forPage(_ page: Int) -> ChalUiChallengeHomeSection {
        page == 1 ? .events : .challenges
    }
}

/// Règles de partie de l'écran Défis (constantes nommées, jamais en dur).
enum ChalUiChallengeRules {
    /// Temps d'affichage de l'adversaire trouvé avant l'ouverture automatique de
    /// l'exercice (`MATCH_REVEAL_MS`), en millisecondes.
    static let matchRevealMs = 900

    /// Le même délai en nanosecondes, pour `Task.sleep(nanoseconds:)`.
    static var matchRevealNanoseconds: UInt64 { UInt64(matchRevealMs) * 1_000_000 }

    /// Un défi oppose deux joueurs (`PLAYERS_PER_CHALLENGE`). Limite temporaire,
    /// en attendant le multijoueur.
    static let playersPerChallenge = 2

    /// Effectif annoncé au joueur (« 2 joueurs »).
    static var playersLabel: String { "\(playersPerChallenge) joueurs" }
}
