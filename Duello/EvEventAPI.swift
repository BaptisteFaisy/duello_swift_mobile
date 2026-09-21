//
//  EvEventAPI.swift
//  Duello
//
//  Passerelle réseau des événements : inscriptions en salle d'attente, copies,
//  états de correction, classements publiés, vues de la carte et partages.
//
//  Fichier source Expo porté : `src/utils/eventApi.ts` (routes `/api/events/...`
//  du serveur social). Helper local : `DuelloAPI` n'expose pas ces routes et
//  n'est pas modifié dans ce lot.
//
//  Limite connue : la source demande `cache: 'no-store'` sur chaque lecture ;
//  `DuelloAPI.request` ne permet pas de fixer la politique de cache de la
//  requête, donc la réponse est relue à la politique du protocole — les routes
//  événement répondent sans cache côté serveur.
//
//  Cible : iOS 16.
//
import Foundation

enum EvEventAPI {
    /// Nombre de participants en salle d'attente ou sur le sujet.
    static func participants(eventId: String, token: String?) async throws -> Int {
        let data = try await DuelloAPI.request(path(eventId, "participants"), token: token)
        return max(0, whole(json(data)["participants"]))
    }

    /// Compteurs d'interactions : vues de la carte et partages.
    static func interactions(eventId: String, token: String?) async throws -> EvInteractionCounts {
        let data = try await DuelloAPI.request(path(eventId, "interactions"), token: token)
        return EvEventSanitizers.interactions(json(data))
    }

    /// Pose la vue de la carte pour le compte courant. La vue est enregistrée
    /// une seule fois côté serveur ; l'appel peut donc être répété sans gonfler
    /// le compteur, et un échec reste silencieux.
    static func recordView(eventId: String, token: String?) async {
        _ = try? await DuelloAPI.request(path(eventId, "view"), method: "POST", token: token)
    }

    /// Compte un partage d'événement pour le compte courant. Seul le premier
    /// partage fait entrer le compte dans le numéroteur.
    static func recordShare(eventId: String, token: String?) async {
        _ = try? await DuelloAPI.request(path(eventId, "share"), method: "POST", token: token)
    }

    /// Rejoint la salle d'attente ; idempotent, comme toute inscription.
    static func join(eventId: String, displayName: String, token: String?) async throws -> EvJoinState {
        let name = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        let body = try JSONSerialization.data(withJSONObject: ["displayName": name], options: [])
        let data = try await DuelloAPI.request(path(eventId, "join"), method: "POST", token: token, body: body)
        return EvJoinState(eventId: eventId, participants: max(0, whole(json(data)["participants"])))
    }

    /// Dépose la copie du participant ; le serveur borne l'instant de dépôt.
    static func submitCopy(
        eventId: String,
        answers: [String: String],
        photoUris: [String],
        submittedAt: Double,
        token: String?
    ) async throws -> Bool {
        let payload: [String: Any] = [
            "answers": EvEventSanitizers.answers(answers),
            "photoUris": photoUris.prefix(24).map { String($0.prefix(2_000)) },
            "submittedAt": submittedAt.rounded(.down),
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        let data = try await DuelloAPI.request(path(eventId, "submission"), method: "POST", token: token, body: body)
        return (json(data)["accepted"] as? Bool) ?? false
    }

    /// État de correction de l'événement et classement éventuellement publié.
    static func results(eventId: String, token: String?) async throws -> EvResultsState {
        let data = try await DuelloAPI.request(path(eventId, "results"), token: token)
        let object = json(data)
        return EvResultsState(
            eventId: eventId,
            finished: (object["finished"] as? Bool) ?? false,
            participants: max(0, whole(object["participants"])),
            gradedParticipants: max(0, whole(object["gradedParticipants"])),
            own: EvEventSanitizers.participation(object["own"]),
            leaderboard: EvEventSanitizers.leaderboard(object["leaderboard"]),
            solutionsAvailable: (object["solutionsAvailable"] as? Bool) ?? false,
            questions: EvEventSanitizers.questions(object["questions"])
        )
    }

    /// Chemin d'une route d'événement, sans barre oblique initiale ;
    /// l'identifiant est émondé comme `trimId` côté Expo.
    private static func path(_ eventId: String, _ suffix: String) -> String {
        "events/\(eventId.trimmingCharacters(in: .whitespacesAndNewlines))/\(suffix)"
    }

    /// Corps JSON d'une réponse, objet vide si la charge est illisible.
    private static func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
    }

    /// Entier borné d'une valeur JSON, `false` sur les booléens, zéro sinon.
    private static func whole(_ value: Any?) -> Int {
        if value is Bool { return 0 }
        if let double = value as? Double { return Int(max(0, double.rounded(.down))) }
        if let integer = value as? Int { return max(0, integer) }
        return 0
    }
}
