import Foundation

// Lecture d'un lien de réinitialisation de mot de passe entrant — porté depuis
// `src/utils/passwordResetLink.ts` (`passwordResetRequestFromUrl`).
//
// R1-AUTH (U08#1) — 2026-09-27 : le backend de développement définit un **App
// Link HTTPS** (`passwordResetAppUrl` de `config/duello-development.json` :
// `https://duello-development-api-relay.duello.workers.dev/reset-password/app`) ;
// ses paramètres voyagent dans le **fragment**
// (`https://…/reset-password/app#reset-password?email=…&token=…`). Le schéma
// personnalisé `duello-dev://reset-password?email=…&token=…` (paramètres en
// query) reste le **repli**, exactement comme `resetParams` du hook
// (`appResetParams ?? legacyNativeResetParams`). La branche `web`
// (`passwordResetWebLinkContext`) reste hors périmètre (V2).
//
// Cible : iOS 16. Aucune dépendance externe.

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

/// Contexte de lecture d'un lien de réinitialisation
/// (`PasswordResetLinkContext` de `passwordResetLink.ts`, branches `app` et
/// `legacy-native` ; la branche `web` n'est pas portée ici).
enum AcctSecResetLinkContext {
    /// App Link HTTPS : URL de base dédiée, paramètres dans le fragment ;
    /// `legacyScheme` autorise le repli sur le schéma personnalisé.
    case app(baseURL: String, legacyScheme: String?)
    /// Schéma personnalisé `scheme://reset-password?…` (paramètres en query).
    case legacyNative(scheme: String)
}

/// Extraction d'une demande de réinitialisation depuis un lien profond.
enum AcctSecResetLink {

    /// `RESET_ACTION` de `passwordResetLink.ts`.
    static let action = "reset-password"

    /// `passwordResetRequestFromUrl(value, context)` : essaie la branche `app`
    /// puis, si le contexte le prévoit, la branche `legacy-native`.
    static func request(
        from value: String,
        context: AcctSecResetLinkContext
    ) -> AcctSecResetRequest? {
        switch context {
        case let .app(baseURL, legacyScheme):
            if let items = appParams(value, baseURL: baseURL) {
                return request(fromItems: items)
            }
            guard let legacyScheme else { return nil }
            return request(from: value, scheme: legacyScheme)
        case let .legacyNative(scheme):
            return request(from: value, scheme: scheme)
        }
    }

    /// `passwordResetRequestFromUrl(value, { kind: 'legacy-native', scheme })` :
    /// accepte `scheme://reset-password?email=…&token=…` et rejette tout ce qui
    /// ne correspond pas exactement au contrat (schéma, action, jeton, adresse).
    static func request(from value: String, scheme: String) -> AcctSecResetRequest? {
        guard let components = URLComponents(string: value) else { return nil }
        guard let items = legacyNativeParams(components, scheme: scheme) else { return nil }
        return request(fromItems: items)
    }

    /// `passwordResetRequestFromUrl` : normalisation de l'adresse et validation
    /// du jeton, communes aux deux branches.
    private static func request(fromItems items: [URLQueryItem]) -> AcctSecResetRequest? {
        let email = (items.first { $0.name == "email" }?.value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let token = items.first { $0.name == "token" }?.value ?? ""

        guard email.count <= 320, AcctSecEmailValidation.isPlausibleEmail(email) else { return nil }
        guard isResetToken(token) else { return nil }
        return AcctSecResetRequest(email: email, token: token)
    }

    /// `appResetParams` : App Link `https:` de même origine et de même chemin
    /// que `baseURL`, sans identifiant, port, query ni fragment côté base, et
    /// sans query côté URL entrante ; les paramètres viennent du fragment.
    private static func appParams(_ value: String, baseURL: String) -> [URLQueryItem]? {
        guard let url = URLComponents(string: value),
              let base = URLComponents(string: baseURL) else { return nil }
        guard url.scheme?.lowercased() == "https",
              base.scheme?.lowercased() == "https" else { return nil }
        guard base.user == nil, base.password == nil,
              base.query == nil, base.fragment == nil else { return nil }
        guard url.user == nil, url.password == nil, url.query == nil else { return nil }
        guard url.host?.lowercased() == base.host?.lowercased(),
              url.port == base.port else { return nil }
        guard normalizedPath(url.path) == normalizedPath(base.path) else { return nil }
        return fragmentResetParams(url.fragment)
    }

    /// `fragmentResetParams` : `#reset-password?email=…&token=…`.
    private static func fragmentResetParams(_ fragment: String?) -> [URLQueryItem]? {
        guard let fragment, let separator = fragment.firstIndex(of: "?") else { return nil }
        guard fragment[fragment.startIndex..<separator] == action else { return nil }
        let query = String(fragment[fragment.index(after: separator)...])
        guard let items = URLComponents(string: "https://reset.invalid/?\(query)")?.queryItems
        else { return nil }
        return items
    }

    /// `normalizedPathname` : retire les « / » de fin, « / » si vide.
    private static func normalizedPath(_ path: String) -> String {
        var trimmed = path
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed.isEmpty ? "/" : trimmed
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
