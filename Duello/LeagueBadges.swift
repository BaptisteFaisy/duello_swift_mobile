//
//  LeagueBadges.swift
//  Duello
//
//  Catalogue des blasons de ligue et adresses des PNG (`leagueBadges.ts`).
//
//  Fichiers source Expo portés (libellés et noms de fichiers repris mot pour mot) :
//    - src/utils/leagueBadges.ts    (LEAGUE_BADGES, URL, taille d'affichage)
//
//  Limite assumée : la source embarque les blasons par `require('../../assets/
//  league-badges/…')` (assets natifs, sélection de densité par Metro). Ces PNG
//  ne sont pas embarqués dans l'app Swift ; le portage s'appuie sur les mêmes
//  fichiers servis à distance (`LEAGUE_BADGE_BASE_URL`), lus par `AsyncImage`.
//  Les cartes natives par densité (`leagueBadgeSourceForLeague`,
//  `leagueSearchBadgeSourceForLeague`) sont donc hors périmètre : sans bundle
//  d'assets, `leagueBadgeUrlForLeague` est la seule source exploitable.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI

/// Blasons de ligue : identifiants et noms de fichiers servis (`leagueBadges.ts`).
enum LeagueBadges {
    /// Racine des PNG servis (`LEAGUE_BADGE_BASE_URL`).
    static let baseURL = "https://duello-android-download.duello.workers.dev/png"

    /// Un blason : identifiant de ligue et noms de fichiers (`LEAGUE_BADGES`).
    struct Badge: Hashable {
        let key: String
        let filename: String
        let leaderboardFilename: String
    }

    /// `LEAGUE_BADGES`, dans l'ordre exact de la source : commerce, écoles
    /// d'ingénieurs, puis familles B/L et BCPST.
    static let catalog: [Badge] = [
        Badge(key: "edhec",
              filename: "league-edhec-laurier-v1.png",
              leaderboardFilename: "league-edhec-laurier-v2.png"),
        Badge(key: "hec",
              filename: "league-hec-laurier-v1.png",
              leaderboardFilename: "league-hec-laurier-v2.png"),
        Badge(key: "essec",
              filename: "league-essec-laurier-v1.png",
              leaderboardFilename: "league-essec-laurier-v2.png"),
        Badge(key: "escp",
              filename: "league-escp-laurier-v1.png",
              leaderboardFilename: "league-escp-laurier-v2.png"),
        Badge(key: "emlyon",
              filename: "league-emlyon-laurier-v1.png",
              leaderboardFilename: "league-emlyon-laurier-v2.png"),
        Badge(key: "ecricome",
              filename: "league-ecricome-laurier-v1.png",
              leaderboardFilename: "league-ecricome-laurier-v2.png"),
        Badge(key: "x",
              filename: "blasons-ingenieurs/ecole-polytechnique.png",
              leaderboardFilename: "blasons-ingenieurs/ecole-polytechnique.png"),
        Badge(key: "ens-ulm",
              filename: "blasons-ingenieurs/ens-ulm.png",
              leaderboardFilename: "blasons-ingenieurs/ens-ulm.png"),
        Badge(key: "centralesupelec",
              filename: "blasons-ingenieurs/centralesupelec.png",
              leaderboardFilename: "blasons-ingenieurs/centralesupelec.png"),
        Badge(key: "mines-paris-psl",
              filename: "blasons-ingenieurs/mines-paris-psl.png",
              leaderboardFilename: "blasons-ingenieurs/mines-paris-psl.png"),
        Badge(key: "ponts-paristech",
              filename: "blasons-ingenieurs/ponts-paristech.png",
              leaderboardFilename: "blasons-ingenieurs/ponts-paristech.png"),
        Badge(key: "telecom-paris",
              filename: "blasons-ingenieurs/telecom-paris.png",
              leaderboardFilename: "blasons-ingenieurs/telecom-paris.png"),
        Badge(key: "ensae-paris",
              filename: "blasons-ingenieurs/ensae-paris.png",
              leaderboardFilename: "blasons-ingenieurs/ensae-paris.png"),
        Badge(key: "ens-lyon",
              filename: "blasons-bl/ens-lyon-engineering-v1.png",
              leaderboardFilename: "blasons-bl/ens-lyon-engineering-v1.png"),
        Badge(key: "ens-paris-saclay",
              filename: "blasons-bl/ens-paris-saclay-engineering-v1.png",
              leaderboardFilename: "blasons-bl/ens-paris-saclay-engineering-v1.png"),
        Badge(key: "espci-paris",
              filename: "blasons-bl/espci-paris.png",
              leaderboardFilename: "blasons-bl/espci-paris.png"),
        Badge(key: "chimie-paristech",
              filename: "blasons-bl/chimie-paristech.png",
              leaderboardFilename: "blasons-bl/chimie-paristech.png"),
        Badge(key: "agroparistech",
              filename: "blasons-bl/agroparistech.png",
              leaderboardFilename: "blasons-bl/agroparistech.png"),
        Badge(key: "agroparistech-bcpst",
              filename: "blasons-bcpst/agroparistech-engineering-v1.png",
              leaderboardFilename: "blasons-bcpst/agroparistech-engineering-v1.png"),
        Badge(key: "enva",
              filename: "blasons-bcpst/enva-engineering-v1.png",
              leaderboardFilename: "blasons-bcpst/enva-engineering-v1.png"),
        Badge(key: "institut-agro",
              filename: "blasons-bcpst/institut-agro-engineering-v1.png",
              leaderboardFilename: "blasons-bcpst/institut-agro-engineering-v1.png"),
        Badge(key: "vetagro-sup",
              filename: "blasons-bcpst/vetagro-sup-engineering-v1.png",
              leaderboardFilename: "blasons-bcpst/vetagro-sup-engineering-v1.png"),
    ]

    /// Blason d'une ligue, ou `nil` si l'identifiant est inconnu.
    static func badge(forLeague id: String) -> Badge? {
        catalog.first { $0.key == id }
    }

    /// `leagueBadgeUrlForLeague` : adresse du blason, `nil` si inconnu.
    static func badgeURL(forLeague id: String) -> URL? {
        guard let entry = badge(forLeague: id) else { return nil }
        return URL(string: "\(baseURL)/\(entry.filename)")
    }

    /// `leagueLeaderboardBadgeUrlForLeague` : adresse du blason de classement.
    static func leaderboardBadgeURL(forLeague id: String) -> URL? {
        guard let entry = badge(forLeague: id) else { return nil }
        return URL(string: "\(baseURL)/\(entry.leaderboardFilename)")
    }

    /// `leagueBadgeDisplaySize` : la source arrondit la taille de base ; le
    /// cadrage des blasons Laurier est déjà cohérent d'une école à l'autre.
    /// `id` reste dans la signature pour rester aligné sur la source.
    static func displaySize(forLeague id: String, baseSize: Double) -> Double {
        _ = id
        return baseSize.rounded()
    }
}

// MARK: - Vue

/// Blason d'une ligue servi à distance (`leagueBadgeSourceForLeague` de la
/// source Expo, ramené ici à sa seule forme exploitable : l'image distante).
///
/// Sans PNG embarqué, le blason passe par `CachedRemoteImage` (`AsyncImage`
/// remplacé par le cache partagé) ; un identifiant inconnu retombe sur le
/// symbole bouclier, comme les autres vues de blason de l'application.
struct LeagueBadgeImage: View {
    /// Identifiant de ligue (`EloLeague.id`, `WeeklyXpLeague.id`).
    let leagueId: String
    /// Côté du blason, en points.
    let size: CGFloat

    var body: some View {
        if let url = LeagueBadges.badgeURL(forLeague: leagueId) {
            CachedRemoteImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: "shield")
                .font(.system(size: size * 0.7, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
        }
    }
}
