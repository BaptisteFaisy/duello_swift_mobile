//
//  RankingEloCohort.swift
//  Duello
//
//  Port de la partie « cohortes » de src/utils/subjectLeaderboard.ts (RN).
//
//  Le classement Elo n'oppose pas tous les élèves : chaque profil rejoint la
//  cohorte de sa filière et de son niveau. La même fonction décide de la
//  cohorte côté serveur (`cohort` de la requête) et côté client, où le filtre
//  est rejoué sur les lignes reçues pour qu'un serveur antérieur au paramètre
//  n'affiche jamais toutes les filières mélangées.
//
//  Cible : iOS 16.
//
import Foundation

/// Cohortes Elo reconnues (`ELO_LEADERBOARD_COHORTS`), dans l'ordre exact de la
/// source.
enum EloLeaderboardCohorts {
    static let all: [String] = [
        "ecg-maths-approfondies",
        "ecg-maths-appliquees",
        "ecg-option-non-renseignee",
        "bcpst",
        "mpsi-mp2i",
        "mp",
        "mpi",
        "pcsi-pc",
        "psi",
        "ptsi-pt",
        "b-l",
        "lycee-terminale",
        "lycee-premiere",
        "lycee-seconde",
    ]
}

/// Profil académique minimal pour choisir la cohorte
/// (`EloLeaderboardAcademicProfile`).
struct EloLeaderboardAcademicProfile {
    /// Champ historique : `ECG` ou `MPSI`.
    var track: String?
    var year: String?
    var specialty: String?
    /// Filière détaillée publiée par les versions récentes de l'application.
    var currentTrack: String?
}

/// Libellé académique replié en clé de comparaison (`normalizedAcademicLabel`) :
/// sans accents, en minuscules, tout ce qui n'est pas `a-z0-9` ramené à un
/// espace simple puis rogné.
func normalizedAcademicLabel(_ value: String?) -> String {
    let folded = (value ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
        .lowercased()
    var out = ""
    for character in folded {
        if character.unicodeScalars.count == 1,
           let scalar = character.unicodeScalars.first,
           (scalar.value >= 97 && scalar.value <= 122)
               || (scalar.value >= 48 && scalar.value <= 57) {
            out.append(character)
        } else {
            out.append(" ")
        }
    }
    return out.split(separator: " ").joined(separator: " ")
}

/// Clé d'option de mathématiques ECG (`leaderboardSpecialtyKey`) : les suffixes
/// ESH/HGG ne séparent plus deux profils, seules les options de maths comptent.
private func leaderboardSpecialtyKey(track: String?, specialty: String?) -> String {
    let normalizedTrack = normalizedAcademicLabel(track)
    let normalizedSpecialty = normalizedAcademicLabel(specialty)
    if normalizedTrack == "ecg" {
        if normalizedSpecialty.contains("appliqu") { return "maths appliquees" }
        if normalizedSpecialty.contains("approfond") { return "maths approfondies" }
    }
    return normalizedSpecialty
}

/// Cohorte ECG déduite de l'option de mathématiques (`ecgEloLeaderboardCohort`).
private func ecgEloLeaderboardCohort(specialty: String?) -> String {
    let option = leaderboardSpecialtyKey(track: "ECG", specialty: specialty)
    if option == "maths approfondies" { return "ecg-maths-approfondies" }
    if option == "maths appliquees" { return "ecg-maths-appliquees" }
    return "ecg-option-non-renseignee"
}

/// Cohorte lycée déduite de l'année (`lyceeEloLeaderboardCohort`), ou `nil`
/// quand l'année n'appartient pas au secondaire.
private func lyceeEloLeaderboardCohort(year: String?) -> String? {
    switch normalizedAcademicLabel(year) {
    case "terminale": return "lycee-terminale"
    case "1re", "premiere": return "lycee-premiere"
    case "2de", "seconde": return "lycee-seconde"
    default: return nil
    }
}

/// Relit une clé de cohorte reçue par l'API (`parseEloLeaderboardCohort`) :
/// `mp-mpi` remonte au tronc MPSI/MP2I, `pcsi`/`pc` à `pcsi-pc` ; toute autre
/// valeur inconnue est rejetée.
func parseEloLeaderboardCohort(_ value: String?) -> String? {
    let cohort = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if cohort == "mp-mpi" { return "mpsi-mp2i" }
    if cohort == "pcsi" || cohort == "pc" { return "pcsi-pc" }
    return EloLeaderboardCohorts.all.contains(cohort) ? cohort : nil
}

/// Cohorte Elo d'un profil (`eloLeaderboardCohortForProfile`).
///
/// Les deux années d'ECG sont réunies par option de mathématiques, BCPST1 et
/// BCPST2 partagent une cohorte, comme MPSI/MP2I, PCSI/PC et PTSI/PT ; MP, MPI,
/// PSI et B/L gardent chacune la leur. Au lycée, chaque niveau a son
/// classement. `currentTrack` prime, avec un repli sur le champ historique
/// `track` pour les instantanés antérieurs.
func eloLeaderboardCohortForProfile(_ profile: EloLeaderboardAcademicProfile) -> String? {
    let currentTrack = normalizedAcademicLabel(profile.currentTrack)
    if currentTrack == "lycee" {
        return lyceeEloLeaderboardCohort(year: profile.year)
    }
    switch currentTrack {
    case "ecg": return ecgEloLeaderboardCohort(specialty: profile.specialty)
    case "bcpst": return "bcpst"
    case "mpsi", "mp2i": return "mpsi-mp2i"
    case "pcsi", "pc": return "pcsi-pc"
    case "ptsi", "pt": return "ptsi-pt"
    case "psi": return "psi"
    case "mp": return "mp"
    case "mpi": return "mpi"
    case "b l": return "b-l"
    default: break
    }

    // Compatibilité avec les instantanés antérieurs à `currentTrack`.
    let legacyTrack = normalizedAcademicLabel(profile.track)
    if legacyTrack == "lycee" {
        return lyceeEloLeaderboardCohort(year: profile.year)
    }
    if legacyTrack == "ecg" {
        return ecgEloLeaderboardCohort(specialty: profile.specialty)
    }
    if legacyTrack == "mpsi" {
        return "mpsi-mp2i"
    }
    return nil
}

/// Vrai lorsque la ligne appartient à la cohorte demandée
/// (`leaderboardEntryMatchesEloCohort`).
func leaderboardEntryMatchesEloCohort(
    _ entry: LeaderboardEntry,
    cohort: String
) -> Bool {
    let profile = EloLeaderboardAcademicProfile(
        track: entry.track,
        year: entry.year,
        specialty: entry.specialty,
        currentTrack: entry.currentTrack
    )
    return eloLeaderboardCohortForProfile(profile) == cohort
}

/// Rejoue le filtre de cohorte sur les lignes reçues du serveur
/// (`filterSubjectLeaderboardEntriesByCohort`). Une ligne sans `currentTrack`
/// (ancien instantané, serveur antérieur à la filière détaillée) est écartée
/// plutôt que d'afficher une cohorte fausse ; `nil` conserve toutes les lignes.
func filterSubjectLeaderboardEntriesByCohort(
    _ entries: [LeaderboardEntry],
    cohort: String?
) -> [LeaderboardEntry] {
    guard let cohort else { return entries }
    return entries.filter { leaderboardEntryMatchesEloCohort($0, cohort: cohort) }
}
