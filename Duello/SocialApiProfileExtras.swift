//
//  SocialApiProfileExtras.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : endpoints sociaux
//  complémentaires absents de `DuelloAPI` (exploits d'exercices très durs,
//  journal d'usage).
//
//  Fichier source Expo porté (routes, corps et règles repris mot pour mot) :
//    - src/utils/socialApi.ts (`fetchVeryHardExerciseAchievements` →
//      `GET /very-hard-exercise-successes`, `publishUsageAnalytics` →
//      `PUT /usage`).
//
//  L'annuaire social n'est pas exposé par `DuelloAPI` : ce client local réutilise
//  le relais (`DuelloAPI.request`). `DuelloAPI.swift` n'est pas modifié.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// `VeryHardExerciseAchiever` : identité publique d'un élève ayant réussi un
/// exercice de niveau 5 ou 6.
struct VeryHardExerciseAchiever: Equatable {
    var id: String
    var displayName: String
    var photoUri: String?
}

/// `fetchVeryHardExerciseAchievements` / `publishUsageAnalytics` de
/// `utils/socialApi.ts`.
enum SocialApiProfileExtras {

    /// Nombre d'identifiants demandés par appel (`chunks` de 40).
    static let achievementsChunkSize = 40
    /// Plafond d'identifiants retenus (`slice(0, 200)`).
    static let achievementsLimit = 200

    /// `fetchVeryHardExerciseAchievements` : identités publiques à afficher sur
    /// les cartes des niveaux 5 et 6, regroupées par identifiant d'exercice.
    static func fetchVeryHardExerciseAchievements(
        exerciseIds: [String],
        token: String?
    ) async throws -> [String: [VeryHardExerciseAchiever]] {
        var seen = Set<String>()
        var wanted: [String] = []
        for raw in exerciseIds {
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            wanted.append(id)
            if wanted.count == achievementsLimit { break }
        }
        guard !wanted.isEmpty else { return [:] }

        var merged: [String: [VeryHardExerciseAchiever]] = [:]
        for start in stride(from: 0, to: wanted.count, by: achievementsChunkSize) {
            let end = min(start + achievementsChunkSize, wanted.count)
            let chunk = Array(wanted[start..<end])
            let data = try await DuelloAPI.request(
                "very-hard-exercise-successes",
                token: token,
                query: [URLQueryItem(name: "ids", value: chunk.joined(separator: ","))]
            )
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            guard let raw = object["achievements"] as? [String: Any] else { continue }
            for (key, value) in raw {
                merged[key] = parseAchievers(value)
            }
        }
        return merged
    }

    /// `publishUsageAnalytics` : publie le journal d'usage du compte. Aucun envoi
    /// sans e-mail ni nom d'affichage, comme la source.
    static func publishUsageAnalytics(
        email: String,
        displayName: String,
        usage: [String: Any],
        token: String?
    ) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedName.isEmpty else { return }
        let body: [String: Any] = [
            "userId": DuelloAPI.publicProfileId(email: trimmedEmail),
            "registrationEmail": trimmedEmail.lowercased(),
            "usage": usage,
        ]
        let payload = try JSONSerialization.data(withJSONObject: body, options: [])
        _ = try await DuelloAPI.request("usage", method: "PUT", token: token, body: payload)
    }

    /// Lit une liste d'exploits, en écartant les entrées sans identité.
    private static func parseAchievers(_ value: Any?) -> [VeryHardExerciseAchiever] {
        guard let list = value as? [Any] else { return [] }
        return list.compactMap { entry in
            guard let object = entry as? [String: Any],
                  let id = object["id"] as? String, !id.isEmpty else { return nil }
            let name = (object["displayName"] as? String) ?? ""
            let photo = object["photoUri"] as? String
            return VeryHardExerciseAchiever(id: id, displayName: name, photoUri: photo)
        }
    }
}
