import Foundation

// Lecture d'un lien de réinitialisation de mot de passe entrant — porté depuis
// `src/utils/passwordResetLink.ts` (`passwordResetRequestFromUrl`, branche
// `legacy-native`).
//
// Le backend de développement ne définit pas de `DUELLO_PASSWORD_RESET_APP_URL`
// (seulement un schéma, `duello-dev`) : `passwordResetLink` du serveur émet donc
// un lien à schéma personnalisé,
// `duello-dev://reset-password?email=…&token=…`, que l'app reçoit par
// `onOpenURL` (cf. `CFBundleURLTypes` de `Info.plist`).

/// Demande de réinitialisation extraite d'un lien entrant
/// (`PasswordResetRequest` de `passwordResetLink.ts`).
struct AcctSecResetRequest: Equatable, Identifiable {
    /// Adresse normalisée (minuscules, sans espaces).
    var email: String
    /// Jeton opaque, transmis **brut** à `POST /auth/password/reset`.
    var token: String

    /// Identité de la vue présentée en plein écran (`fullScreenCover(item:)`).
    var id: String { token }
}

/// Extraction d'une demande de réinitialisation depuis un lien profond.
enum AcctSecResetLink {

    /// `RESET_ACTION` de `passwordResetLink.ts`.
    static let action = "reset-password"

    /// `passwordResetRequestFromUrl(value, { kind: 'legacy-native', scheme })` :
    /// accepte `scheme://reset-password?email=…&token=…` et rejette tout ce qui
    /// ne correspond pas exactement au contrat (schéma, action, jeton, adresse).
    static func request(from value: String, scheme: String) -> AcctSecResetRequest? {
        guard let components = URLComponents(string: value) else { return nil }
        guard let items = legacyNativeParams(components, scheme: scheme) else { return nil }

        let email = (items.first { $0.name == "email" }?.value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let token = items.first { $0.name == "token" }?.value ?? ""

        guard email.count <= 320, AcctSecEmailValidation.isPlausibleEmail(email) else { return nil }
        guard isResetToken(token) else { return nil }
        return AcctSecResetRequest(email: email, token: token)
    }

    /// `legacyNativeResetParams` : schéma exact, aucun identifiant, port ni
    /// fragment ; l'action est le nom d'hôte, à défaut le premier segment du
    /// chemin. Renvoie les paramètres de requête si l'URL est conforme.
    private static func legacyNativeParams(
        _ components: URLComponents,
        scheme: String
    ) -> [URLQueryItem]? {
        guard components.scheme?.lowercased() == scheme.lowercased() else { return nil }
        guard components.user == nil, components.password == nil else { return nil }
        guard components.port == nil, components.fragment == nil else { return nil }

        let host = components.host ?? ""
        let path = components.path
        if !host.isEmpty, path != "", path != "/" { return nil }

        let action = host.isEmpty ? String(path.drop(while: { $0 == "/" })) : host
        guard action == Self.action else { return nil }
        return components.queryItems ?? []
    }

    /// `RESET_TOKEN_PATTERN` : `^[a-zA-Z0-9_-]{32,128}$`.
    private static func isResetToken(_ value: String) -> Bool {
        guard (32...128).contains(value.count) else { return false }
        return value.allSatisfy { character in
            character.isASCII
                && (character.isLetter || character.isNumber
                    || character == "_" || character == "-")
        }
    }
}
