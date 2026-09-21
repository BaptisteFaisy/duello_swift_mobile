import Foundation

/// Vérification de disponibilité d'un pseudo (pseudo libre, sans réservation).
///
/// Porté de `src/utils/usernameAvailability.ts` (verdict `verified` /
/// `unverified`, délai de 6 s, messages) et de `src/utils/username.ts`
/// (normalisation NFKC, bornes 3–24). Diagnostic HTTP repris de
/// `src/utils/authHttpError.ts`. Endpoint : `POST /auth/username/available`.
///
/// Le délai court de la source (6 s) impose une requête locale plutôt que
/// `DuelloAPI.request` (délai fixe de 20 s) ; aucun type de `DuelloAPI` n'est
/// modifié.
enum AcctSecUsernameAvailability {
    /// Verdict d'une vérification. `unverified` couvre le délai dépassé et la
    /// panne réseau : le parcours continue alors sans pré-contrôle, car bloquer
    /// l'écran sur un incident passager serait définitif.
    enum Outcome: Equatable {
        case verified
        case unverified
    }

    /// Verdict explicite du serveur (pseudo pris 409, requête invalide 400),
    /// alignée sur `UsernameAvailabilityError`.
    struct AvailabilityError: LocalizedError {
        let message: String
        let status: Int?
        let code: String?
        let retryAfterSeconds: Int?

        var errorDescription: String? { message }
    }

    /// Bornes de `username.ts` (`USERNAME_MIN_LENGTH` / `USERNAME_MAX_LENGTH`).
    static let minLength = 3
    static let maxLength = 24

    /// `USERNAME_AVAILABILITY_TIMEOUT_MS` de la source, en secondes.
    private static let timeoutSeconds: TimeInterval = 6

    // MARK: Normalisation et validation (voir `username.ts`)

    /// `trim` puis NFKC (`normalizeUsername`).
    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCompatibilityMapping
    }

    /// `isValidUsername` : longueur 3–24 et alphabet `\p{L}\p{N}._-`.
    static func isValid(_ value: String) -> Bool {
        let username = normalize(value)
        guard username.count >= minLength, username.count <= maxLength else { return false }
        return username.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar)
                || CharacterSet.decimalDigits.contains(scalar)
                || scalar == "."
                || scalar == "_"
                || scalar == "-"
        }
    }

    // MARK: Vérification réseau

    /// Vérifie qu'un pseudo est libre sans le réserver. Un relais lent ne rend
    /// pas de verdict : délai dépassé ou coupure réseau ⇒ `unverified`. Seul un
    /// verdict explicite du serveur (409 / 400) lève une `AvailabilityError`.
    static func ensureAvailable(_ value: String, token: String?) async throws -> Outcome {
        let username = normalize(value)
        var request = URLRequest(url: DuelloAPI.baseURL.appendingPathComponent("auth/username/available"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? DuelloAPI.encodeBody(["username": username])

        let data: Data
        let http: HTTPURLResponse
        do {
            let (payload, response) = try await URLSession.shared.data(for: request)
            guard let typed = response as? HTTPURLResponse else { return .unverified }
            data = payload
            http = typed
        } catch {
            return .unverified
        }

        let decoded = try? DuelloAPI.decoder.decode(AvailablePayload.self, from: data)
        if http.statusCode == 200, decoded?.available == true {
            return .verified
        }
        let fallback = http.statusCode == 200
            ? "Le serveur n’a pas confirmé la disponibilité de ce pseudo."
            : "Impossible de vérifier ce pseudo pour le moment."
        let diagnostic = Self.failure(for: http, data: data, fallback: fallback)
        if http.statusCode == 409 || http.statusCode == 400 {
            throw diagnostic
        }
        return .unverified
    }

    /// Titre d'alerte associé à une erreur, aligné sur
    /// `usernameAvailabilityAlertTitle`.
    static func alertTitle(for error: Error) -> String {
        if let availability = error as? AvailabilityError, availability.status == 409 {
            return "Pseudo indisponible"
        }
        return "Vérification du pseudo impossible"
    }

    // MARK: Diagnostic HTTP (voir `authHttpError.ts`)

    private struct AvailablePayload: Decodable {
        var available: Bool?
    }

    private struct ErrorPayload: Decodable {
        var error: String?
        var code: String?
    }

    private static func failure(
        for response: HTTPURLResponse,
        data: Data,
        fallback: String
    ) -> AvailabilityError {
        let payload = try? DuelloAPI.decoder.decode(ErrorPayload.self, from: data)
        let retryAfter = retryAfterSeconds(from: response)
        let message: String
        if response.statusCode == 429 {
            message = rateLimitMessage(seconds: retryAfter)
        } else if let text = payload?.error?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            message = text
        } else {
            message = fallback
        }
        let code = payload?.code?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AvailabilityError(
            message: message,
            status: response.statusCode,
            code: (code?.isEmpty == false) ? code : nil,
            retryAfterSeconds: retryAfter
        )
    }

    private static func retryAfterSeconds(from response: HTTPURLResponse) -> Int? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if let seconds = Double(raw), seconds.isFinite, seconds >= 0 {
            return Int(seconds.rounded(.up))
        }
        guard let date = httpDateFormatter.date(from: raw) else { return nil }
        return max(0, Int(date.timeIntervalSinceNow.rounded(.up)))
    }

    private static func rateLimitMessage(seconds: Int?) -> String {
        guard let seconds else {
            return "Trop de demandes ont été envoyées. Réessaie dans quelques minutes."
        }
        if seconds < 60 {
            return "Trop de demandes ont été envoyées. Réessaie dans quelques secondes."
        }
        let minutes = max(1, Int((Double(seconds) / 60).rounded(.up)))
        let plural = minutes > 1 ? "s" : ""
        return "Trop de demandes ont été envoyées. Réessaie dans \(minutes) minute\(plural)."
    }

    /// Analyseur des dates HTTP (`Retry-After` en forme RFC 1123), équivalent
    /// de `Date.parse` côté JS.
    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE',' dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}
