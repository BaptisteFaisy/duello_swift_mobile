import Foundation

// MARK: - Code promo (réseau)

/// Portage de `src/utils/promoCodeApi.ts` : activation d'un code promo avec la
/// session du compte courant, et traduction des refus connus.
///
/// La source adresse le compte local par `accountId` (`duelloApiRequest`) ; le
/// portage s'authentifie avec le jeton de session, seule identité disponible
/// ici. Le code n'est jamais journalisé ni conservé hors du formulaire.

/// Réponse serveur d'une activation réussie (`PromoCodeResult`).
struct PremPromoResult: Decodable, Equatable {
    /// `false` quand ce compte avait déjà activé ce code.
    let applied: Bool
    /// Pourcentage de remise : la source accepte un `number` quelconque, seule
    /// l'étiquette de remise exige un entier (`validPercentOff`).
    let percentOff: Double
    let usedAt: Double
}

/// Enveloppe de `POST /premium/promo-code` : `{ "promo": { … } }`.
struct PremPromoEnvelope: Decodable {
    let promo: PremPromoResult?
}

/// Erreur locale, alignée sur `DuelloApiError('Réponse du code promo illisible.')`.
enum PremPromoError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Réponse du code promo illisible."
        }
    }
}

/// `applyPromoCodeForAccount` et `promoCodeFailureMessage`.
enum PremPromoService {
    /// Active un code promo pour le compte de la session.
    static func applyPromoCode(code: String, token: String?) async throws -> PremPromoResult {
        let body = try DuelloAPI.encodeBody(["code": code])
        let envelope = try await DuelloAPI.request(
            PremPromoEnvelope.self,
            "premium/promo-code",
            method: "POST",
            token: token,
            body: body
        )
        guard let promo = envelope.promo else { throw PremPromoError.unreadable }
        return promo
    }

    /// `promoCodeFailureMessage` : les refus connus sont traduits sans exposer
    /// le détail technique de la réponse.
    ///
    /// Le champ `code` de la source n'est pas porté par `DirectoryError` : les
    /// refus documentés (`registered-account-required`, `promo-code-invalid`)
    /// sont reconnus par leur statut HTTP, 403 et 400.
    static func failureMessage(for error: Error) -> String {
        if let promoError = error as? PremPromoError {
            return promoError.errorDescription ?? defaultMessage
        }
        // Une forme inattendue (`promo` mal typé, corps racine illisible) est
        // exactement ce que la source refuse : elle porte le même message que
        // `PremPromoError.unreadable`, jamais le message générique.
        if error is DecodingError {
            return "Réponse du code promo illisible."
        }
        guard let directory = error as? DirectoryError else { return defaultMessage }
        switch directory.status ?? 0 {
        case 403:
            return "Connecte-toi à un compte Duello pour utiliser un code promo."
        case 400:
            return "Ce code promo est invalide, expiré ou a atteint sa limite."
        case 429:
            return "Trop de tentatives ont été effectuées. Attends un instant, puis réessaie."
        default:
            let message = directory.message.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? defaultMessage : message
        }
    }

    /// `DEFAULT_PROMO_ERROR`.
    private static let defaultMessage =
        "Impossible d’appliquer ce code promo pour le moment. Vérifie ta connexion, puis réessaie."
}
