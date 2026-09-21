import Foundation

// MARK: - Ligues Elo (subjectElo.ts)

/// Ligues Elo d'une filière : identifiant, libellé et seuil d'accès.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car `RankingSubjectLeaderboard` manipule le type — mêmes
/// propriétés.
struct EloLeague: Identifiable, Hashable {
    let id: String
    let label: String
    let minimumElo: Int
}

/// Ligues de commerce de Duello Dev (`ELO_LEAGUES`), du plus bas au plus haut.
private let ecricomeEloLeagues: [EloLeague] = [
    EloLeague(id: "ecricome", label: "ECRICOME", minimumElo: 0),
    EloLeague(id: "emlyon", label: "EMLYON", minimumElo: 1000),
    EloLeague(id: "edhec", label: "EDHEC", minimumElo: 1200),
    EloLeague(id: "escp", label: "ESCP", minimumElo: 1400),
    EloLeague(id: "essec", label: "ESSEC", minimumElo: 1600),
    EloLeague(id: "hec", label: "HEC", minimumElo: 1800),
]

/// Ligues des filières scientifiques (`ENGINEERING_ELO_LEAGUES`).
private let engineeringEloLeagues: [EloLeague] = [
    EloLeague(id: "ensae-paris", label: "ENSAE Paris", minimumElo: 0),
    EloLeague(id: "telecom-paris", label: "Télécom Paris", minimumElo: 1000),
    EloLeague(id: "ponts-paristech", label: "Ponts ParisTech", minimumElo: 1200),
    EloLeague(id: "mines-paris-psl", label: "Mines Paris – PSL", minimumElo: 1400),
    EloLeague(id: "centralesupelec", label: "CentraleSupélec", minimumElo: 1600),
    EloLeague(id: "ens-ulm", label: "ENS Ulm", minimumElo: 1700),
    EloLeague(id: "x", label: "École polytechnique", minimumElo: 1800),
]

/// Ligues propres à B/L (`BL_ELO_LEAGUES`).
private let blEloLeagues: [EloLeague] = [
    EloLeague(id: "ensae-paris", label: "ENSAE", minimumElo: 0),
    EloLeague(id: "ens-paris-saclay", label: "ENS Paris-Saclay", minimumElo: 1000),
    EloLeague(id: "essec", label: "ESSEC", minimumElo: 1200),
    EloLeague(id: "ens-lyon", label: "ENS de Lyon", minimumElo: 1400),
    EloLeague(id: "hec", label: "HEC Paris", minimumElo: 1600),
    EloLeague(id: "ens-ulm", label: "ENS Ulm", minimumElo: 1800),
]

/// Ligues propres à BCPST (`BCPST_ELO_LEAGUES`).
private let bcpstEloLeagues: [EloLeague] = [
    EloLeague(id: "vetagro-sup", label: "VetAgro Sup", minimumElo: 0),
    EloLeague(id: "institut-agro", label: "Institut Agro", minimumElo: 1000),
    EloLeague(id: "enva", label: "ENVA", minimumElo: 1200),
    EloLeague(id: "agroparistech-bcpst", label: "AgroParisTech", minimumElo: 1400),
    EloLeague(id: "ens-ulm", label: "ENS Ulm", minimumElo: 1600),
    EloLeague(id: "x", label: "École polytechnique", minimumElo: 1800),
]

/// Filière réduite à ses lettres et chiffres, en capitales, pour comparer
/// « B/L » et « BL » sans dépendre de la casse ou de la ponctuation.
private func compactAcademicTrack(_ track: String?) -> String {
    let normalized = (track ?? "").uppercased()
    return String(normalized.filter { $0.isLetter || $0.isNumber })
}

/// Série de ligues correspondant à la famille académique du compte
/// (`eloLeaguesForTrack`) : B/L, BCPST, commerce (ECG ou vide) puis sciences.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé par `RankingSubjectLeaderboard` — corps inchangé.
func eloLeagues(forTrack track: String?) -> [EloLeague] {
    let compact = compactAcademicTrack(track)
    if compact.hasPrefix("BL") { return blEloLeagues }
    if compact.hasPrefix("BCPST") { return bcpstEloLeagues }
    let keepsCommerce = compact.isEmpty || compact.hasPrefix("ECG")
    return keepsCommerce ? ecricomeEloLeagues : engineeringEloLeagues
}

/// Ligue atteinte pour une cote et une filière (`eloLeagueFor`) : la plus haute
/// dont le seuil est franchi, la plus basse à défaut.
///
/// Extrait de l'ancien `RankingsView.swift` : était `private`, élargi à
/// `internal` car appelé par `RankingSubjectLeaderboard` — corps inchangé.
func eloLeague(for elo: Int, track: String?) -> EloLeague {
    let rounded = max(0, elo)
    let leagues = eloLeagues(forTrack: track)
    return leagues.reversed().first { rounded >= $0.minimumElo } ?? leagues[0]
}
