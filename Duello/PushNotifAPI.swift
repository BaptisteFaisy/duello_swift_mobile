import Foundation

// Helpers réseau locaux pour l'inscription des jetons de notification poussée.
//
// Sources Expo portées : `registerPushNotificationToken` et
// `unregisterPushNotificationToken` de `src/utils/socialApi.ts`.
//
// L'endpoint `/push-tokens` n'est pas exposé par `DuelloAPI` : helper **local**
// dans ce fichier, sans modifier `DuelloAPI.swift`. Le corps reprend
// `{ userId, token }` où `userId` est l'identifiant public du profil
// (`publicProfileId`). Aucun envoi si l'e-mail est vide, comme côté Expo.

// MARK: - API des jetons

/// Appels serveur d'inscription/désinscription d'un jeton (`/push-tokens`).
enum PushNotifAPI {

    /// Corps envoyé au serveur : identifiant public + jeton.
    private struct TokenBody: Encodable {
        var userId: String
        var token: String
    }

    /// `POST /push-tokens` — inscrit le jeton pour ce profil.
    static func registerToken(profile: UserProfile, token: String) async throws {
        let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        let body = try DuelloAPI.encodeBody(
            TokenBody(userId: DuelloAPI.publicProfileId(email: email), token: token)
        )
        _ = try await DuelloAPI.request("push-tokens", method: "POST", body: body)
    }

    /// `DELETE /push-tokens` — révoque le jeton pour ce profil.
    static func unregisterToken(profile: UserProfile, token: String) async throws {
        let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return }
        let body = try DuelloAPI.encodeBody(
            TokenBody(userId: DuelloAPI.publicProfileId(email: email), token: token)
        )
        _ = try await DuelloAPI.request("push-tokens", method: "DELETE", body: body)
    }
}
