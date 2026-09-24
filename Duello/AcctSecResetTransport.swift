//
//  AcctSecResetTransport.swift
//  Duello
//
//  Port de src/utils/passwordResetHttp.ts (chemin `reset` uniquement) et de
//  src/utils/passwordResetAuthentication.ts (RN) — transport réseau de la
//  complétion de réinitialisation.
//
//  C'est la couture honnête du chemin nominal : `AcctSecPasswordResetForm.swift`
//  ne distinguait pas les issues (`sendReset` lançait un `DirectoryError`
//  générique). Ici sont reproduites la classification de la source —
//  délai 8 s, 5xx sur `reset` → issue inconnue, panne/timeout réseau → issue
//  inconnue, charge utile invalide ou identité non concordante → session
//  inutilisable — et la lecture des réponses.
//
//  La requête est faite directement sur `URLSession` (et non via
//  `DuelloAPI.request`) pour tenir le délai de 8 s et distinguer panne réseau,
//  timeout et refus HTTP. Aucun fichier existant n'est modifié.
//
//  Découpage (24/09/2026) : ce fichier porte la réponse décodée, le délai et le
//  contrôle d'identité. La requête HTTP et la lecture des réponses vivent dans
//  `AcctSecResetTransport+Request.swift` ; les messages d'échec HTTP dans
//  `AcctSecResetTransport+Failures.swift`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Réponse décodée de `POST /auth/password/reset`
/// (`PasswordResetResponse & { accepted }` de `passwordResetHttp.ts`).
struct PasswordResetResponse {
    var accepted: Bool
    var session: ServerSession?
    var account: RecoveredServerAccount?
}

/// Transport de la réinitialisation (`passwordResetHttp` + `resetServerPassword`).
enum AcctSecResetTransport {
    /// `PASSWORD_RESET_TIMEOUT_MS` (8 000 ms).
    static let timeoutSeconds: Double = 8

    /// `requirePasswordResetAuthentication` : la session et le compte doivent
    /// exister **et** porter la même adresse que la demande.
    static func requirePasswordResetAuthentication(
        expectedEmail: String,
        response: PasswordResetResponse
    ) throws -> PasswordResetAuthentication {
        guard let session = response.session,
              let account = response.account,
              passwordResetIdentityMatches(
                  expected: expectedEmail,
                  sessionEmail: session.email,
                  accountEmail: account.email
              ) else {
            throw PasswordResetAuthenticationUnavailableError()
        }
        return PasswordResetAuthentication(session: session, account: account)
    }

    /// `passwordResetIdentityMatches` : même adresse normalisée, non vide.
    private static func passwordResetIdentityMatches(
        expected: String,
        sessionEmail: String,
        accountEmail: String
    ) -> Bool {
        let target = LoginScrCredential.normalize(expected)
        return !target.isEmpty
            && LoginScrCredential.normalize(sessionEmail) == target
            && LoginScrCredential.normalize(accountEmail) == target
    }
}
