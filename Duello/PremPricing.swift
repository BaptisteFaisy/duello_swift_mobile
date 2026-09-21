import Foundation

// MARK: - Prix Premium et remises de code promo

/// Portage de `shared/premium-pricing.mjs` : une seule définition des prix de
/// base, d'où se déduisent les étiquettes de remise, et la normalisation de la
/// saisie d'un code promo (`src/utils/promoCodeInput.ts`).
///
/// Le serveur renvoie le pourcentage de remise ; l'application en déduit le
/// prix réduit, le prix d'origine barré et le badge d'économie — jamais
/// l'inverse.

/// Étiquettes affichables d'une période remisée (`discountedPriceLabels`).
struct PremDiscount: Equatable {
    /// Prix réduit affichable, déjà formaté en euros.
    let price: String
    /// Prix d'origine, barré.
    let basePrice: String
    /// Badge d'économie, par exemple « −25 % ».
    let saving: String
}

/// Calculs de prix et de remise, alignés sur la source partagée.
enum PremPricing {
    /// `PREMIUM_BASE_PRICES` : prix de référence des deux périodes remisables.
    static let basePrices: [PremOfferId: Double] = [.weekly: 6.99, .annual: 182]

    /// `PREMIUM_PROMO_PERIODS` : l'offre gratuite n'est jamais remisée.
    static let promoPeriods: [PremOfferId] = [.weekly, .annual]

    /// `PROMO_INPUT_MAX_LENGTH` et la longueur minimale acceptée en envoi
    /// (`canSubmit` de `usePromoCode`).
    static let codeMaxLength = 32
    static let codeMinLength = 6

    private static let minPercentOff = 1
    private static let maxPercentOff = 90

    /// `PROMO_INPUT_PATTERN` : seuls les lettres, chiffres et tirets survivent.
    private static let allowedCodeCharacters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")

    /// `normalizePromoCodeInput` : majuscules, seuls `A-Z`, `0-9` et `-`
    /// survivent, tronqué à 32 caractères.
    static func normalizedCode(_ value: String) -> String {
        let upper = value.uppercased()
        let filtered = upper.filter { allowedCodeCharacters.contains($0) }
        return String(filtered.prefix(codeMaxLength))
    }

    /// `discountedEuroPrice` : prix réduit en euros, ou `nil` si l'entrée est
    /// invalide (pourcentage hors 1…90, période non remisable).
    static func discountedEuroPrice(_ period: PremOfferId, percentOff: Double) -> Double? {
        guard let base = basePrices[period], validPercentOff(percentOff) else { return nil }
        return roundEuro(base * (100 - percentOff) / 100)
    }

    /// `discountedPriceLabels` : `nil` dès que le code ou la période est invalide.
    static func discountLabels(_ period: PremOfferId, percentOff: Double) -> PremDiscount? {
        guard let base = basePrices[period],
              let discounted = discountedEuroPrice(period, percentOff: percentOff) else {
            return nil
        }
        return PremDiscount(
            price: formatEuro(discounted),
            basePrice: formatEuro(base),
            saving: savingLabel(percentOff)
        )
    }

    /// `−${percentOff} %` de la source.
    static func savingLabel(_ percentOff: Double) -> String {
        "−\(percentText(percentOff)) %"
    }

    /// `${percentOff}` de la source : un entier s'écrit sans décimale, une
    /// valeur décimale telle quelle. La borne écarte tout entier absurde avant
    /// la conversion.
    static func percentText(_ value: Double) -> String {
        let integral = value.isFinite && value.rounded() == value && abs(value) <= 1000
        return integral ? String(Int(value)) : String(value)
    }

    /// `validPercentOff` : un pourcentage entier recevable (`Number.isSafeInteger`).
    private static func validPercentOff(_ value: Double) -> Bool {
        value.isFinite
            && value.rounded() == value
            && value >= Double(minPercentOff)
            && value <= Double(maxPercentOff)
    }

    /// `Math.round(value * 100) / 100` de la source.
    private static func roundEuro(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// `Intl.NumberFormat('fr-FR', { minimumFractionDigits: 2 })` : deux
    /// décimales, virgule décimale, séparateur de milliers insécable.
    private static func formatEuro(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
