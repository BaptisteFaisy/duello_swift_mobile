//
//  ReportSafetyAPI.swift
//  Duello
//
//  Lot « Report » — client local de la sécurité du profil : état des comptes
//  bloqués, blocage, déblocage et dépôt d'un signalement confidentiel.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/socialApi.ts (fetchUserSafetyState, blockSocialProfile,
//                              unblockSocialProfile, submitUserReport,
//                              parseUserSafetyState)
//
//  L'annuaire social n'est pas exposé par `DuelloAPI` : ce client local
//  réutilise le relais (`DuelloAPI.request`) sur `user-safety`, comme
//  `ExGLeaderboardClient` sur `exercise-leaderboard`. `DuelloAPI.swift` n'est
//  pas modifié.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Sécurité du profil (`/user-safety` de `utils/socialApi.ts`).
enum ReportSafetyAPI {

    /// `GET /user-safety` (`fetchUserSafetyState`) : liste privée des comptes
    /// bloqués par la session courante.
    static func fetchState(token: String?) async throws -> ReportSafetyState {
        try await DuelloAPI.request(ReportSafetyState.self, "user-safety", token: token)
    }

    /// `POST /user-safety/blocks` (`blockSocialProfile`) : rend immédiatement
    /// les deux comptes invisibles dans les surfaces sociales.
    static func block(targetId: String, token: String?) async throws -> ReportSafetyState {
        let body = try DuelloAPI.encodeBody(ReportSafetyTarget(targetId: targetId))
        return try await DuelloAPI.request(
            ReportSafetyState.self,
            "user-safety/blocks",
            method: "POST",
            token: token,
            body: body
        )
    }

    /// `DELETE /user-safety/blocks` (`unblockSocialProfile`) : retire uniquement
    /// le blocage créé par le compte courant.
    static func unblock(targetId: String, token: String?) async throws -> ReportSafetyState {
        let body = try DuelloAPI.encodeBody(ReportSafetyTarget(targetId: targetId))
        return try await DuelloAPI.request(
            ReportSafetyState.self,
            "user-safety/blocks",
            method: "DELETE",
            token: token,
            body: body
        )
    }

    /// `POST /user-safety/reports` (`submitUserReport`) : dépose un signalement
    /// confidentiel, sans notifier le compte ciblé.
    static func submitReport(
        targetId: String,
        reason: ReportReason,
        details: String,
        token: String?
    ) async throws {
        let payload = ReportSafetyReport(
            targetId: targetId,
            reason: reason.rawValue,
            details: details
        )
        let body = try DuelloAPI.encodeBody(payload)
        _ = try await DuelloAPI.request(
            "user-safety/reports",
            method: "POST",
            token: token,
            body: body
        )
    }
}

/// Corps `{ targetId }` de `POST` / `DELETE /user-safety/blocks`.
private struct ReportSafetyTarget: Encodable {
    var targetId: String
}

/// Corps `{ targetId, reason, details }` de `POST /user-safety/reports`.
private struct ReportSafetyReport: Encodable {
    var targetId: String
    var reason: String
    var details: String
}
