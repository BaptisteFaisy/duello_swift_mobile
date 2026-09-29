//
//  AcctIncomingLike.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : prochain like reçu sur sa
//  propre performance.
//
//  Fichier source Expo porté (règle et libellés repris mot pour mot) :
//    - src/utils/notifications.ts (`nextIncomingLike`,
//      `PerformanceLikeNotification`, `formatTimeAgo` déjà porté ailleurs).
//
//  Il n'y a pas encore de serveur : `SOCIAL_PROFILES` est **vide** côté RN, donc
//  `nextIncomingLike` rend toujours `null` en pratique. Cette fonction simule
//  l'arrivée d'un like à chaque ouverture de « Mon compte », en piochant le
//  prochain membre public qui n'a pas encore liké ; c'est le seul point à
//  remplacer par un appel réseau le jour où le backend existe.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Performance affichée par une notification de like (`{ label, text }`).
struct AcctLikePerformance: Equatable {
    var label: String
    var text: String
}

/// Like reçu sur sa propre performance (`PerformanceLikeNotification`).
struct AcctPerformanceLikeNotification: Identifiable, Equatable {
    var id: String
    var actorId: String
    var actorName: String
    var performanceLabel: String
    var performanceText: String
    /// Instant d'arrivée, ISO 8601 (`new Date(now).toISOString()`).
    var createdAt: String
    var read: Bool
}

/// `nextIncomingLike` de `utils/notifications.ts`.
enum AcctIncomingLike {

    /// Prochain like reçu, ou `nil` quand tous les membres publics ont déjà liké
    /// (et toujours `nil` tant que `SOCIAL_PROFILES` reste vide).
    static func next(
        existing: [AcctNotification],
        performance: AcctLikePerformance,
        now: Double,
        profiles: [ReportSocialProfile] = []
    ) -> AcctPerformanceLikeNotification? {
        let alreadyLiked = Set(
            existing
                .filter { $0.kind == .performanceLike }
                .map { $0.actorId }
        )
        guard let actor = profiles.first(where: { $0.isPublic && !alreadyLiked.contains($0.id) })
        else { return nil }
        return AcctPerformanceLikeNotification(
            id: "like-\(actor.id)",
            actorId: actor.id,
            actorName: actor.displayName,
            performanceLabel: performance.label,
            performanceText: performance.text,
            createdAt: isoString(now),
            read: false
        )
    }

    /// `new Date(now).toISOString()` : ISO 8601 avec millisecondes.
    private static func isoString(_ now: Double) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date(timeIntervalSince1970: now / 1000))
    }
}
