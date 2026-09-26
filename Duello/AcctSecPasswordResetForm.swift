import Foundation

// Helpers de réinitialisation de mot de passe — portés depuis
// `src/utils/passwordResetApi.ts` (`resetServerPassword`),
// `passwordResetHttp.ts` et `passwordResetIdentity.ts`.
//
// V1 L2 (U04#3) — 2026-09-26 : ce fichier portait une **seconde**
// implémentation de l'écran « Nouveau mot de passe » (`AcctSecPasswordResetForm`,
// en trois étapes demande / code / mot de passe) branchée sur le lien entrant en
// plus de `PasswordResetView` (`AccountPasswordResetView.swift`). Le point
// d'entrée est dédoublé : le lien entrant ouvre désormais le **seul**
// `PasswordResetView` (`DuelloApp.onOpenURL`). L'écran dupliqué est retiré ; le
// fichier conserve les helpers réseau et la vérification d'identité, partagés
// avec `PasswordResetView`.
//
// Cible : iOS 16. Aucune dépendance externe.

/// `resetServerPassword` de `passwordResetApi.ts` : `POST /auth/password/reset`
/// puis `requirePasswordResetAuthentication` (session + compte récupérés, ou
/// erreur explicite si l'identité ne correspond pas).
enum AcctSecPasswordReset {

    /// Envoie le nouveau mot de passe et renvoie la session ouverte.
    static func sendReset(
        email: String,
        token: String,
        password: String
    ) async throws -> ServerSession {
        let body = try DuelloAPI.encodeBody([
            "email": email,
            "token": token,
            "password": password,
        ])
        let data = try await DuelloAPI.request(
            "auth/password/reset",
            method: "POST",
            body: body
        )
        let payload = try? DuelloAPI.decoder.decode(AcctSecResetResponse.self, from: data)
        guard let session = payload?.session,
              let account = payload?.account,
              AcctSecResetIdentity.matches(
                  expected: email,
                  sessionEmail: session.email,
                  accountEmail: account.email
              ) else {
            throw DirectoryError(
                message: "Le mot de passe a changé, mais la nouvelle session Duello est inutilisable."
            )
        }
        return session
    }
}

/// Réponse de `POST /auth/password/reset` : la session ouverte après le
/// changement de mot de passe et le compte récupéré, ou `null` si l'identité
/// ne correspond pas (`PasswordResetResponse` de `passwordResetHttp.ts`).
private struct AcctSecResetResponse: Decodable {
    var accepted: Bool?
    var session: ServerSession?
    var account: AcctSecResetAccount?
}

/// Compte récupéré renvoyé par `POST /auth/password/reset` ; seul l'e-mail est
/// lu ici, le reste du profil relevant du socle `SessionStore`.
private struct AcctSecResetAccount: Decodable {
    var email: String
}

/// Concordance d'identité de réinitialisation (`passwordResetIdentityMatches`
/// de `utils/passwordResetIdentity.ts`) : l'adresse demandée doit coïncider
/// avec celles de la session et du compte renvoyés par le serveur.
private enum AcctSecResetIdentity {
    static func matches(expected: String, sessionEmail: String, accountEmail: String) -> Bool {
        let target = normalize(expected)
        return !target.isEmpty
            && normalize(sessionEmail) == target
            && normalize(accountEmail) == target
    }

    /// `normalizeEmail` de `utils/accountIdentity.ts`.
    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
