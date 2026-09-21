import Foundation

// Routage d'un tap sur une bannière système.
//
// Source Expo portée : `src/components/PushNotificationTapHandler.tsx`
// (fonction `route` et extraction de `data`).
//
// Pur et portable : la lecture du payload ne dépend d'aucune API système, ce
// qui permet de la tester sans `UserNotifications`. La souscription réelle au
// tap est posée par `PushNotifNative` (non portable).

// MARK: - Destination

/// Destination d'un tap sur une notification poussée.
enum PushNotifTap: Equatable {
    /// Un membre a commencé à suivre le profil (`new-follower`).
    case newFollower(actorId: String)
    /// Invitation de défi reçue (`challenge-invitation`).
    case challengeInvitation(invitationId: String?)
    /// Un défi a été refusé/indisponible (`challenge-unavailable`).
    case challengeUnavailable
}

// MARK: - Routeur

/// Routeur pur, calqué sur `route()` de `PushNotificationTapHandler.tsx`.
enum PushNotifRouter {

    /// Lit `data.kind` dans le payload et renvoie la destination, ou `nil` si
    /// l'alerte ne concerne pas la navigation Duello.
    static func route(userInfo: [AnyHashable: Any]) -> PushNotifTap? {
        let kind = userInfo["kind"] as? String ?? ""
        switch kind {
        case "new-follower":
            guard let actorId = userInfo["actorId"] as? String,
                  actorId.hasPrefix("member-") else { return nil }
            return .newFollower(actorId: actorId)
        case "challenge-invitation":
            return .challengeInvitation(invitationId: userInfo["invitationId"] as? String)
        case "challenge-unavailable":
            return .challengeUnavailable
        default:
            return nil
        }
    }
}
