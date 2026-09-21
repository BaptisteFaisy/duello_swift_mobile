import Foundation

// MARK: - Lecture défensive du JSON d'affiliation
//
// Portage des garde-fous de `src/utils/affiliate.ts` : la source travaille sur
// `unknown` (`record`, `safeMinor`, `isoTimestamp`, `optionalText`) et refuse
// toute valeur approchée. Toute lecture inattendue renvoie `nil`, jamais une
// valeur de remplacement — un solde faux serait pire qu'un solde absent.

/// Lecture de valeurs JSON non typées, alignée sur `src/utils/affiliate.ts`.
enum AffRaw {
    /// `record` : objet JSON uniquement (ni tableau, ni scalaire, ni `null`).
    static func record(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    /// `safeMinor` : entier positif ou nul. Un nombre non entier (`12.5`) est
    /// refusé ; `100.0` vaut 100, comme `Number.isSafeInteger(100.0)` en
    /// JavaScript.
    static func minor(_ value: Any?) -> Int? {
        guard let number = value as? Int, number >= 0 else { return nil }
        return number
    }

    /// `isoTimestamp` : horodatage reconnu comme une date.
    static func iso(_ value: Any?) -> String? {
        guard let text = value as? String, AffiliateFormatting.isoDate(text) != nil else {
            return nil
        }
        return text
    }

    /// `optionalText` : texte utile, `nil` quand la clé est absente, nulle ou
    /// vide.
    static func text(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }

    /// `AffiliatePayoutMode` : `off`, `shadow`, `sandbox` ou `live`.
    static func mode(_ value: Any?) -> AffPayoutMode? {
        guard let raw = value as? String else { return nil }
        return AffPayoutMode(rawValue: raw)
    }

    /// Environnement d'un retrait : `shadow`, `sandbox` ou `live`, jamais `off`.
    static func payoutEnvironment(_ value: Any?) -> AffPayoutMode? {
        guard let mode = mode(value), mode != .off else { return nil }
        return mode
    }

    /// `AFFILIATE_PUBLIC_ID` : `member-` suivi d'hexadécimal minuscule.
    static func isPublicId(_ value: String) -> Bool {
        let prefix = "member-"
        guard value.hasPrefix(prefix) else { return false }
        let suffix = value.dropFirst(prefix.count)
        return !suffix.isEmpty && suffix.allSatisfy { isLowercaseHexDigit($0) }
    }

    /// `AFFILIATE_WITHDRAWAL_ID` : UUID canonique (la source accepte les deux
    /// casses, son expression régulière étant insensible à la casse).
    static func isWithdrawalId(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 5, parts.map(\.count) == [8, 4, 4, 4, 12] else { return false }
        return parts.allSatisfy { part in part.allSatisfy { $0.isHexDigit && $0.isASCII } }
    }

    /// Chiffre hexadécimal minuscule, comme `[a-f0-9]`.
    private static func isLowercaseHexDigit(_ character: Character) -> Bool {
        character.isASCII && character.isHexDigit && !character.isUppercase
    }
}
