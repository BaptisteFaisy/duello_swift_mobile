import Foundation

// MARK: - Montants, dates et clés d'affiliation
//
// Portage de `src/utils/affiliate.ts` (`formatAffiliateAmount`,
// `parseAffiliateAmountMinor`, `createAffiliateIdempotencyKey`) et du
// formateur de dates de `src/features/affiliate/AffiliateWithdrawalSections.tsx`
// (`Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short',
// year: 'numeric' })`).
//
// Les montants sont rendus en euros au format français (`1 234,50 €`) et la
// saisie est relue en centimes **sans calcul flottant**, comme la source.

/// Formatage et relecture des montants et dates de l'espace affiliation.
///
/// Les formateurs statiques ne sont utilisés que depuis le fil principal (le
/// contrôleur et les vues), comme les formateurs de la source.
enum AffiliateFormatting {
    /// `EUR_FORMATTER` — `Intl.NumberFormat('fr-FR', { currency: 'EUR' })`.
    private static let euroFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// `DATE_FORMATTER` — jour, mois abrégé, année.
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    /// Analyseurs ISO-8601 : forme complète, forme à fractions de seconde, et
    /// forme réduite à la date (que `Date.parse` accepte aussi).
    private static let isoFormatters: [ISO8601DateFormatter] = {
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [standard, fractional]
    }()

    private static let dayOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// `formatAffiliateAmount` : centimes vers euros français. Renvoie `—`
    /// quand la valeur n'est pas un entier positif ou nul, comme la source.
    static func amount(_ amountMinor: Int) -> String {
        guard amountMinor >= 0 else { return "—" }
        let euros = NSNumber(value: Double(amountMinor) / 100)
        return euroFormatter.string(from: euros) ?? "—"
    }

    /// `affiliateAmountInputValue` : centimes vers saisie française (`12,50`).
    static func inputValue(_ amountMinor: Int) -> String {
        let cents = amountMinor % 100
        return "\(amountMinor / 100),\(cents < 10 ? "0" : "")\(cents)"
    }

    /// `parseAffiliateAmountMinor` : saisie française vers centimes. `nil` dès
    /// que la saisie n'est pas un montant strictement positif.
    static func minor(fromInput input: String) -> Int? {
        // Espaces insécables et fines compris : `String.isWhitespace` les couvre.
        var text = String(input.filter { !$0.isWhitespace })
        if text.hasSuffix("€") { text.removeLast() }
        guard !text.isEmpty else { return nil }

        var whole = text
        var fraction = ""
        if let separator = text.firstIndex(where: { $0 == "," || $0 == "." }) {
            whole = String(text[text.startIndex..<separator])
            fraction = String(text[text.index(after: separator)...])
            guard (1...2).contains(fraction.count) else { return nil }
        }
        guard !whole.isEmpty, whole.allSatisfy(isASCIIDigit),
              fraction.allSatisfy(isASCIIDigit),
              let euros = Int(whole)
        else { return nil }

        let cents = fraction.isEmpty ? 0 : (Int(fraction) ?? 0) * (fraction.count == 1 ? 10 : 1)
        let (base, overflow) = euros.multipliedReportingOverflow(by: 100)
        guard !overflow else { return nil }
        let (total, carry) = base.addingReportingOverflow(cents)
        guard !carry, total > 0 else { return nil }
        return total
    }

    /// `createAffiliateIdempotencyKey` : clé stable et rejouable, 100
    /// caractères au plus, sans identifiant de compte.
    static func idempotencyKey() -> String {
        String("affiliate-withdrawal-\(UUID().uuidString.lowercased())".prefix(100))
    }

    /// `Date.parse` : horodatage exploitable, `nil` sinon.
    static func isoDate(_ value: String) -> Date? {
        for formatter in isoFormatters {
            if let date = formatter.date(from: value) { return date }
        }
        return dayOnlyFormatter.date(from: value)
    }

    /// `DATE_FORMATTER.format(new Date(withdrawal.requestedAt))`.
    static func date(_ iso: String) -> String {
        guard let parsed = isoDate(iso) else { return iso }
        return shortDateFormatter.string(from: parsed)
    }

    /// Chiffre décimal ASCII, comme `\d` de la source.
    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }
}
