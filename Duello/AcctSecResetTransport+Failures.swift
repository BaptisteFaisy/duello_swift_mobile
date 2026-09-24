//
//  AcctSecResetTransport+Failures.swift
//  Duello
//
//  Port de src/utils/authHttpError.ts (RN) — messages d'échec HTTP du transport
//  de réinitialisation : quota 429, erreur du serveur, repli.
//
//  Découpage (24/09/2026) : section extraite de `AcctSecResetTransport.swift`
//  (porté du même fichier source). `authHttpFailureMessage` est `internal` car
//  appelée depuis `+Request.swift`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

extension AcctSecResetTransport {

    // MARK: Échecs HTTP (authHttpError.ts)

    /// `authHttpFailure` : 429 → message de quota ; sinon l'erreur du serveur,
    /// à défaut le message de repli.
    static func authHttpFailureMessage(http: HTTPURLResponse, data: Data) -> String {
        if http.statusCode == 429 {
            return rateLimitMessage(retryAfterSeconds(http))
        }
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = payload["error"] as? String,
           !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return error.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Le service de mot de passe est indisponible."
    }

    /// `retryAfterSeconds` : en-tête numérique ou date HTTP.
    private static func retryAfterSeconds(_ http: HTTPURLResponse) -> Int? {
        guard let raw = http.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if let seconds = Double(raw), seconds >= 0 {
            return Int(seconds.rounded(.up))
        }
        guard let date = ISO8601DateFormatter.date(fromISO: raw) else { return nil }
        return max(0, Int(date.timeIntervalSinceNow.rounded(.up)))
    }

    /// `rateLimitMessage`.
    private static func rateLimitMessage(_ seconds: Int?) -> String {
        guard let seconds else {
            return "Trop de demandes ont été envoyées. Réessaie dans quelques minutes."
        }
        if seconds < 60 {
            return "Trop de demandes ont été envoyées. Réessaie dans quelques secondes."
        }
        let minutes = max(1, Int((Double(seconds) / 60).rounded(.up)))
        return "Trop de demandes ont été envoyées. Réessaie dans \(minutes) minute\(minutes > 1 ? "s" : "")."
    }
}
