//
//  ExGLeaderboardStatuses.swift
//  Duello
//
//  Statuts scolaires du classement d'exercice, complétés depuis l'annuaire des
//  profils.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/exerciseLeaderboard.ts
//        `ExerciseLeaderboardAcademicStatus`,
//        `parseExerciseLeaderboardAcademicStatus`,
//        `enrichExerciseLeaderboardAcademicStatuses`.
//
//  Le client du classement (`ExGExerciseLeaderboard.swift`) documentait cet
//  enrichissement comme « non repris » ; ce module le porte, à raccorder à la
//  lecture de l'annuaire (`AcctSearchDirectory`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `utils/exerciseLeaderboard.ts` : statuts scolaires d'un classement d'exercice.
enum ExGLeaderboardStatuses {

    /// `parseExerciseLeaderboardAcademicStatus` : « A intégré » doit rester un
    /// statut explicite — une ancienne « 3e année » désigne un cube/5/2 et ne
    /// doit jamais être assimilée à une intégration.
    static func parseAcademicStatus(_ value: String?) -> String? {
        guard let value, value == "1re année" || value == "2e année" || value == "A intégré" else {
            return nil
        }
        return value
    }

    /// `enrichExerciseLeaderboardAcademicStatuses` : complète le statut des
    /// lignes qui n'en portent pas, à partir de l'annuaire des profils
    /// (`id`, `year`, `academicStatus`).
    static func enrich(
        _ entries: [ExGLeaderboardEntry],
        profiles: [[String: Any]]
    ) -> [ExGLeaderboardEntry] {
        var statusById: [String: String] = [:]
        for profile in profiles {
            guard let id = profile["id"] as? String else { continue }
            let status = parseAcademicStatus(profile["academicStatus"] as? String)
                ?? parseAcademicStatus(profile["year"] as? String)
            if let status { statusById[id] = status }
        }
        return entries.map { entry in
            if let existing = entry.academicStatus, !existing.isEmpty { return entry }
            var copy = entry
            copy.academicStatus = statusById[entry.id]
            return copy
        }
    }
}
