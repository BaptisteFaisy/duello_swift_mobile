//
//  AdmPromoForm.swift
//  Duello
//
//  Formulaire de création d'un code promo, porté de
//  `src/utils/promoCodeForm.ts` (utilisé par
//  `src/admin/AdminPromoCodesScreen.tsx`) : normalisation, génération
//  aléatoire et validation côté client, messages d'erreur repris **mot pour mot**.
//
//  Détail du source conservé tel quel : `CODE_BODY_LENGTH` vaut 8 et la série
//  est construite en **deux moitiés de 4 caractères** séparées par un tiret, soit
//  « RENTREE-4K7M-2P9X » (le commentaire d'origine annonçait une série unique de
//  4 caractères ; c'est le code qui fait foi).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Résultat de `parsePromoForm` : charge utile valide ou message d'erreur.
enum AdmPromoFormResult: Equatable {
    case valid(AdmPromoCodeCreateInput)
    case invalid(String)
}

/// `promoCodeForm.ts` : saisie du formulaire de code promo.
enum AdmPromoForm {
    /// `CODE_ALPHABET` : caractères non ambigus (I, O, 0 et 1 exclus).
    static let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    /// `CODE_PREFIXES` : préfixes thématiques lisibles et dicables.
    static let prefixes = [
        "RENTREE", "BIENVENUE", "NOEL", "ETE", "PRINTEMPS",
        "EXAMENS", "BONNECHANCE", "MERCI", "OFFRE", "DUELLO",
    ]
    /// `CODE_BODY_LENGTH` : longueur totale de la série, tiret compris.
    static let bodyLength = 8
    /// Bornes de validité du code côté serveur (`[A-Z0-9]{6,32}`).
    static let minCodeLength = 6
    static let maxCodeLength = 32
    /// Bornes de la remise et des options (`parsePromoForm`).
    static let minPercent = 1
    static let maxPercent = 90
    static let maxRedemptionsLimit = 100_000
    static let minExpiryDays = 1
    static let maxExpiryDays = 3650

    /// `normalizePromoCodeInput` : majuscules, espaces et tirets retirés.
    static func normalize(_ value: String) -> String {
        value.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    /// `generatePromoCode` : préfixe thématique puis deux moitiés de série.
    static func generateCode() -> String {
        let prefix = prefixes.randomElement() ?? "OFFRE"
        let half = max(1, bodyLength / 2)
        return "\(prefix)-\(randomBody(length: half))-\(randomBody(length: half))"
    }

    /// `parsePromoForm` : valide la saisie et construit la charge utile.
    static func parse(
        code: String,
        label: String,
        percent: String,
        maxRedemptions: String,
        expiresInDays: String,
        now: Date = Date()
    ) -> AdmPromoFormResult {
        let normalized = normalize(code)
        guard normalized.count >= minCodeLength, normalized.count <= maxCodeLength,
              normalized.range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil else {
            return .invalid("Le code doit contenir entre 6 et 32 lettres ou chiffres.")
        }
        guard let percentValue = number(percent),
              percentValue >= minPercent, percentValue <= maxPercent else {
            return .invalid("La remise doit être entre 1 et 90 %.")
        }
        guard let redemptions = parseRedemptions(maxRedemptions) else {
            return .invalid("Limite d'utilisations invalide.")
        }
        guard let expiresAt = parseExpiry(expiresInDays, now: now) else {
            return .invalid("Expire dans : nombre de jours entre 1 et 3650.")
        }
        return .valid(
            AdmPromoCodeCreateInput(
                code: normalized,
                label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                percentOff: percentValue,
                maxRedemptions: redemptions,
                expiresAt: expiresAt
            )
        )
    }

    /// `Limite d'utilisations` : absente = illimité, sinon 1 à 100 000.
    private static func parseRedemptions(_ raw: String) -> Int?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .some(nil) }
        guard let value = number(trimmed), value >= 1 else { return nil }
        return .some(min(value, maxRedemptionsLimit))
    }

    /// `Expire dans` : absente = sans expiration, sinon 1 à 3650 jours.
    private static func parseExpiry(_ raw: String, now: Date) -> Double?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .some(nil) }
        guard let days = number(trimmed),
              days >= minExpiryDays, days <= maxExpiryDays else { return nil }
        return .some(now.timeIntervalSince1970 * 1000 + Double(days) * 86_400_000)
    }

    /// `Number(value.trim())` du source : accepte les entiers écrits avec une
    /// partie décimale nulle (« 10.0 ») et rejette tout le reste.
    private static func number(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(trimmed) { return value }
        guard let decimal = Double(trimmed),
              decimal.rounded() == decimal,
              abs(decimal) <= 9_007_199_254_740_991 else { return nil }
        return Int(decimal)
    }

    /// `CODE_BODY_LENGTH / 2` caractères tirés dans `CODE_ALPHABET`.
    private static func randomBody(length: Int) -> String {
        let characters = Array(alphabet)
        var body = ""
        for _ in 0..<length {
            body.append(characters.randomElement() ?? "X")
        }
        return body
    }
}
