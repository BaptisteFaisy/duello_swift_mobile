//
//  DictRelayConfig.swift
//  Duello
//
//  Résolution de la configuration du relais ASR premium : adresse effective
//  (`resolveRelayEndpoint`) et jeton de session Duello (`currentServerSessionToken`),
//  plus les libellés d'état et d'erreur du service vocal.
//
//  Porté de `src/utils/relayEndpoint.ts` (`resolveConfiguredRelayEndpoint`,
//  `sanitizeRelayOverride`), de `src/utils/serverSessionToken.ts`
//  (`currentServerSessionToken`), de `src/utils/mathOcrSettings.ts`
//  (`loadMathOcrSettings`) et de `src/hooks/webDictationPresentation.ts`
//  (`webDictationServiceError`).
//
//  Le jeton est relu directement au stockage, sans passer par l'état observé de
//  l'interface, exactement comme la source (`currentServerSessionToken`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

extension DictRelayConfig {
    /// Configuration premium effective, ou `nil` hors mode `premium`
    /// (`loadMathOcrSettings` puis `resolveRelayEndpoint`).
    static func resolve(defaults: UserDefaults = .standard) -> DictRelayConfig? {
        let session = currentServerSession()
        let token = session.map(validToken) ?? ""
        let accountId = ConsentPremiumGate.accountId(email: session?.email ?? "")
        let settings = KbSupOcrSettingsStore.load(
            accountId: accountId,
            token: token,
            defaults: defaults
        )
        guard settings.mode == .premium else { return nil }
        return DictRelayConfig(endpoint: resolveEndpoint(settings.endpoint), token: settings.token)
    }

    /// `resolveConfiguredRelayEndpoint` : une adresse saisie n'est retenue que
    /// si elle reste sur l'origine du build, sinon `${DUELLO_API_URL}/relay`.
    static func resolveEndpoint(_ configured: String) -> String {
        let api = DuelloAPI.baseURL.absoluteString
        let override = sanitize(configured, apiUrl: api)
        return override.isEmpty ? trimmed(api) + "/relay" : override
    }

    /// `sanitizeRelayOverride` : vide si l'adresse n'est pas sur l'origine de
    /// l'API suivie par le build (le jeton ne doit jamais partir ailleurs).
    static func sanitize(_ endpoint: String, apiUrl: String) -> String {
        let configured = trimmed(endpoint)
        guard !configured.isEmpty,
              let candidate = URL(string: configured),
              let api = URL(string: apiUrl),
              let scheme = candidate.scheme,
              let host = candidate.host,
              scheme == api.scheme,
              host == api.host,
              candidate.port == api.port
        else { return "" }
        return configured
    }

    /// Retire les espaces extérieurs et les barres obliques finales (`trimEndpoint`).
    static func trimmed(_ endpoint: String) -> String {
        var value = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    /// Session serveur courante, relue au trousseau — `currentServerSessionToken`
    /// lit de même le stockage sans charger la configuration réseau.
    static func currentServerSession() -> ServerSession? {
        guard let data = Keychain.read(service: SessionStore.service, account: SessionStore.account),
              let session = try? JSONDecoder().decode(ServerSession.self, from: data)
        else { return nil }
        return session
    }

    /// Jeton `dus_…` encore valide, sinon chaîne vide.
    static func validToken(_ session: ServerSession) -> String {
        guard session.token.hasPrefix("dus_"),
              let expires = ISO8601DateFormatter.date(fromISO: session.expiresAt),
              expires > Date()
        else { return "" }
        return session.token
    }
}

/// Libellés d'état et d'erreur du service vocal — `webDictationPresentation.ts`.
enum DictRelayText {
    /// Repli local quand le partage IA n'a pas été autorisé.
    static let sansPartage =
        "Aucun audio transmis par Duello : reconnaissance du téléphone utilisée."
    /// Repli local quand le service vocal échoue en cours de flux.
    static let serviceIndisponible =
        "Le service vocal est indisponible. Reconnaissance du téléphone utilisée."

    /// `webDictationServiceError` : message selon le code d'erreur du relais.
    static func messageErreur(code: String, message: String) -> String {
        switch code {
        case "unauthorized":
            return "Ta session Duello a expiré. Reconnecte-toi, puis réessaie la dictée."
        case "premium-required":
            return "La dictée IA nécessite un abonnement Premium actif."
        default:
            return message.isEmpty
                ? "Le service vocal est momentanément indisponible. Réessaie dans quelques instants."
                : message
        }
    }
}
