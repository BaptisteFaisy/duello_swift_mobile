//
//  RankingWeeklyXpEntries.swift
//  Duello
//
//  Relecture du classement XP hebdomadaire renvoyé par le serveur.
//
//  Fichier source Expo porté (libellés et règles de validité repris mot pour mot) :
//    - src/utils/weeklyXpLeaderboard.ts
//        `WEEKLY_XP_CURRENT_TRACKS`, `isCurrentTrack`, `parseWeeklyXpEntries`,
//        `weeklyXpRank`.
//
//  Limite documentée : `LeaderboardEntry` (le type de ligne du port) ne porte
//  pas de `photoUri` ; la photo d'une ligne XP reste donc hors du portage
//  (`rankedWeeklyRows` pose déjà `photoUri: nil`, `RankingRowBuilder.swift`).
//
//  Le serveur renvoie déjà une liste anonymisée ; elle est relue ici avant
//  affichage, exactement comme le classement Elo, afin qu'une réponse
//  inattendue ne puisse pas rattacher une ligne privée à une identité.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `utils/weeklyXpLeaderboard.ts` : relecture et rang du classement XP hebdo.
enum RankingWeeklyXp {

    /// `WEEKLY_XP_CURRENT_TRACKS` : filières réellement suivies acceptées.
    static let currentTracks: Set<String> = [
        "MPSI", "MP2I", "PCSI", "PTSI", "MP", "MPI", "PC", "PT", "PSI",
        "BCPST", "B/L", "ECG", "Lycée",
    ]

    /// Années acceptées par `parseWeeklyXpEntries`.
    static let validYears: Set<String> = [
        "2de", "1re", "Terminale", "1re année", "2e année", "3e année",
    ]

    /// `parseWeeklyXpEntries` : relit la réponse distante et efface à nouveau
    /// toute identité d'une ligne privée. Une ligne invalide est écartée seule.
    static func parseEntries(_ value: [[String: Any]]) -> [LeaderboardEntry] {
        value.compactMap(parseEntry)
    }

    /// Une ligne brute : identifiant valide et XP fini requis, puis identité
    /// selon que la ligne est anonyme ou non.
    private static func parseEntry(_ entry: [String: Any]) -> LeaderboardEntry? {
        let isAnonymous = (entry["isAnonymous"] as? Bool) == true
        guard let id = entry["id"] as? String, hasValidId(id, anonymous: isAnonymous) else {
            return nil
        }
        guard let rawXp = entry["xp"] as? Double, rawXp.isFinite else { return nil }
        let xp = max(0, rawXp.rounded())

        guard !isAnonymous else {
            return LeaderboardEntry(
                id: id,
                displayName: "Anonyme",
                prepName: "",
                xp: xp,
                isAnonymous: true
            )
        }
        return identifiedEntry(entry, id: id, xp: xp)
    }

    /// Ligne identifiée : nom, filière (`MPSI`/`ECG`/`Lycée`) et année requis.
    private static func identifiedEntry(
        _ entry: [String: Any],
        id: String,
        xp: Double
    ) -> LeaderboardEntry? {
        guard let displayName = entry["displayName"] as? String,
              !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let track = entry["track"] as? String,
              track == "MPSI" || track == "ECG" || track == "Lycée",
              let year = entry["year"] as? String,
              validYears.contains(year)
        else { return nil }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prep = (entry["prepName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let specialty = (entry["specialty"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let currentTrack = entry["currentTrack"] as? String
        return LeaderboardEntry(
            id: id,
            displayName: String(name.prefix(80)),
            prepName: String(prep.prefix(120)),
            track: track,
            currentTrack: (currentTrack.map(currentTracks.contains) == true) ? currentTrack : nil,
            specialty: String(specialty.prefix(120)),
            year: year,
            xp: xp
        )
    }

    /// `weeklyXpRank` : rang déduit du score seul — chaque ligne à score
    /// strictement supérieur compte, même à total identique les rangs restent
    /// individuels.
    static func weeklyXpRank(_ entries: [LeaderboardEntry], xp: Double) -> Int {
        let rounded = max(0, Int((xp.isFinite ? xp : 0).rounded()))
        let higher = entries.filter { entry in
            guard let value = entry.xp, value.isFinite else { return false }
            return max(0, Int(value.rounded())) > rounded
        }.count
        return higher + 1
    }

    /// `hasValidId` : `anonymous-<n>` pour une ligne privée, `member-<hex>` pour
    /// une ligne identifiée.
    private static func hasValidId(_ id: String, anonymous: Bool) -> Bool {
        if anonymous {
            guard id.hasPrefix("anonymous-") else { return false }
            let suffix = id.dropFirst("anonymous-".count)
            guard let first = suffix.first, first.isNumber, first != "0" else { return false }
            return suffix.allSatisfy(\.isNumber)
        }
        guard id.hasPrefix("member-") else { return false }
        let suffix = id.dropFirst("member-".count)
        guard !suffix.isEmpty else { return false }
        return suffix.allSatisfy { $0.isNumber || ("a"..."f").contains($0) }
    }
}
