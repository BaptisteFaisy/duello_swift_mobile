//
//  EvEventPresence.swift
//  Duello
//
//  Présence live d'un événement — modèles, protocole serveur et passerelle
//  réseau. Suites : `EvEventPresenceStore.swift` (état observé),
//  `EvEventPresenceClient.swift` (socket dédiée),
//  `EvEventPresenceViews.swift` (rail et feuille).
//
//  Port de src/utils/presenceProtocol.ts (type `event-presence`, lecture d'un
//  présent, compteur `isPresenceCount`) et de src/utils/eventApi.ts
//  (`fetchEventPresence`, `fetchEventViewers`) ; consommé par
//  src/hooks/useEventPresence.ts.
//
//  Limite assumée (24/09/2026) : le protocole de la socket globale
//  (`SocPresenceProtocol.event`, `PresenceViews.swift`) ne reconnaît pas le type
//  `event-presence` et n'est pas modifié (règle « nouveaux fichiers seulement ») ;
//  la lecture de ce message vit donc ici, à côté du reste du protocole.
//
//  Cible : iOS 16.
//
import Foundation

// MARK: - Modèles

/// Un compte actuellement sur la page d'un événement (`EventPresenceViewer`).
struct EvEventPresenceViewer: Identifiable, Equatable {
    var id: String
    /// Prénom affiché (le pseudo Duello).
    var displayName: String
    /// Miniature JPEG autonome, ou `nil` sans photo.
    var photoUri: String?
}

/// Instantané de présence d'un événement (`EventPresenceSnapshot`) : présents,
/// vues cumulées et partages cumulés.
struct EvEventPresenceSnapshot: Equatable {
    var viewers: [EvEventPresenceViewer]
    var views: Int
    var shares: Int
}

/// Message `event-presence` du serveur (`EventPresenceEvent`) : la photographie
/// des présents et des compteurs, rediffusée à chaque arrivée, départ, vue ou
/// partage.
struct EvEventPresenceEvent: Equatable {
    var eventId: String
    var viewers: [EvEventPresenceViewer]
    var views: Int
    var shares: Int
}

/// Message de la socket utile à un événement : la socket dédiée ignore les
/// changements de présence globale (`presence`) comme les erreurs.
enum EvEventPresenceMessage: Equatable {
    /// Le serveur a authentifié la socket : `watch-event` peut être envoyé.
    case ready
    /// Instantané de l'événement observé.
    case event(EvEventPresenceEvent)
}

// MARK: - Protocole

/// Lecture des messages de la socket de présence (`presenceProtocol.ts`).
enum EvEventPresenceProtocol {
    /// Relit un message du serveur sans jamais accepter une forme inattendue
    /// (`parsePresenceServerEvent`, branche `event-presence`).
    static func message(from raw: String) -> EvEventPresenceMessage? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let value = object as? [String: Any],
              let type = value["type"] as? String
        else { return nil }

        if type == "ready" { return .ready }
        guard type == "event-presence",
              let eventId = value["eventId"] as? String, !eventId.isEmpty,
              let entries = value["viewers"] as? [Any],
              let views = count(value["views"]),
              let shares = count(value["shares"])
        else { return nil }

        return .event(
            EvEventPresenceEvent(
                eventId: eventId,
                viewers: entries.compactMap(EvEventPresenceProtocol.viewer),
                views: views,
                shares: shares
            )
        )
    }

    /// Relit un présent ; `nil` lorsque la forme est inattendue
    /// (`parseEventPresenceViewer`).
    static func viewer(_ value: Any) -> EvEventPresenceViewer? {
        guard let object = value as? [String: Any],
              let id = object["id"] as? String, !id.isEmpty,
              let displayName = object["displayName"] as? String, !displayName.isEmpty
        else { return nil }
        let photo = object["photoUri"] as? String
        return EvEventPresenceViewer(id: id, displayName: displayName, photoUri: photo)
    }

    /// Un compteur de vues ou de partages : entier positif ou nul ; `nil` sinon
    /// (booléens et fractions refusés, comme `isPresenceCount`).
    static func count(_ value: Any?) -> Int? {
        guard let value, !(value is Bool), let number = value as? NSNumber else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double >= 0, double.rounded(.down) == double else { return nil }
        return Int(double)
    }
}

// MARK: - Passerelle réseau

/// Routes de présence d'un événement (`fetchEventPresence`, `fetchEventViewers`).
///
/// Les routes vivent sous `/api/events/:id/…` et la session courante est passée
/// explicitement : `DuelloAPI` ne porte pas ces routes et n'est pas modifié dans
/// ce lot (`EvEventAPI` reste intact).
enum EvEventPresenceAPI {
    /// Instantané au repos : présents, vues et partages, sans attendre la socket
    /// (`fetchEventPresence`).
    static func snapshot(eventId: String, token: String?) async throws -> EvEventPresenceSnapshot {
        let body = json(try await DuelloAPI.request(path(eventId, "presence"), token: token))
        return EvEventPresenceSnapshot(
            viewers: viewers(body["viewers"]),
            views: EvEventPresenceProtocol.count(body["views"]) ?? 0,
            shares: EvEventPresenceProtocol.count(body["shares"]) ?? 0
        )
    }

    /// Personnes ayant ouvert la page de l'événement, pour la feuille des vues
    /// (`fetchEventViewers`).
    static func viewers(eventId: String, token: String?) async throws -> [EvEventPresenceViewer] {
        let body = json(try await DuelloAPI.request(path(eventId, "viewers"), token: token))
        return viewers(body["viewers"])
    }

    /// Liste relue d'une charge `viewers`, vide si la forme est inattendue.
    private static func viewers(_ value: Any?) -> [EvEventPresenceViewer] {
        guard let entries = value as? [Any] else { return [] }
        return entries.compactMap(EvEventPresenceProtocol.viewer)
    }

    /// Chemin d'une route d'événement ; l'identifiant est émondé (`trimId`).
    private static func path(_ eventId: String, _ suffix: String) -> String {
        "events/\(eventId.trimmingCharacters(in: .whitespacesAndNewlines))/\(suffix)"
    }

    /// Corps JSON d'une réponse, objet vide si la charge est illisible.
    private static func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
    }
}
