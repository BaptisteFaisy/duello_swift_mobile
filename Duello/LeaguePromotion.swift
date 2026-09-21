//
//  LeaguePromotion.swift
//  Duello
//
//  Détection d'une promotion de ligue Elo (`eloLeaguePromotion.ts`).
//
//  Fichiers source Expo portés (libellés et règles repris mot pour mot) :
//    - src/utils/eloLeaguePromotion.ts   (eloLeaguePromotionAfterSubjectResult)
//    - src/utils/subjectElo.ts           (averageSubjectElo, INITIAL_SUBJECT_ELO)
//
//  Réutilise `RankingEloLeagues.swift` (`EloLeague`, `eloLeague(for:track:)`)
//  et la cote de départ `ProgressStore.initialElo` (= `INITIAL_SUBJECT_ELO`).
//  Aucun type existant n'est redéclaré. Cible : iOS 16.
//
import Foundation

/// Promotion de ligue détectée (`EloLeaguePromotion`) : cote moyenne atteinte et
/// franchissement `from` → `to`.
struct LeaguePromotion: Hashable {
    /// Cote moyenne réellement affichée dans Défis après le résultat.
    let averageElo: Int
    /// Ligue quittée.
    let from: EloLeague
    /// Ligue atteinte.
    let to: EloLeague
}

/// `averageSubjectElo` : moyenne arrondie des cotes de matières, `nil` si le
/// joueur n'a encore aucune cote enregistrée.
///
/// `Math.round` (arrondi au plus proche) est reproduit par `rounded()` : les
/// cotes étant toujours positives, les deux règles coïncident.
func leagueAverageSubjectElo(_ subjectElos: [String: Int]) -> Int? {
    guard !subjectElos.isEmpty else { return nil }
    let total = subjectElos.values.reduce(0, +)
    return Int((Double(total) / Double(subjectElos.count)).rounded())
}

/// `eloLeaguePromotionAfterSubjectResult` : promotion sur la cote **moyenne**
/// réellement affichée dans Défis.
///
/// Une matière peut franchir seule un seuil sans faire monter la moyenne : ce
/// cas ne doit pas annoncer une nouvelle ligue au joueur. La cote de départ
/// (`INITIAL_SUBJECT_ELO`) reprend `ProgressStore.initialElo` ; `track` est la
/// filière du compte, comme `eloLeagueFor(elo, track)`.
func leaguePromotionAfterSubjectResult(
    subjectElos: [String: Int],
    subject: String,
    eloAfter: Int,
    track: String?
) -> LeaguePromotion? {
    let initialElo = ProgressStore.initialElo
    let previousAverage = leagueAverageSubjectElo(subjectElos) ?? initialElo

    var updatedElos = subjectElos
    updatedElos[subject] = eloAfter
    let nextAverage = leagueAverageSubjectElo(updatedElos) ?? initialElo

    let from = eloLeague(for: previousAverage, track: track)
    let to = eloLeague(for: nextAverage, track: track)
    guard to.minimumElo > from.minimumElo else { return nil }

    return LeaguePromotion(averageElo: nextAverage, from: from, to: to)
}
