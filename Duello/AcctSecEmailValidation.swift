import Foundation

/// Contrôle d'adresse e-mail, aligné sur `validEmail` de
/// `ForgotPasswordScreen.tsx` : au plus 320 caractères, sans espace, de la
/// forme `local@domaine.tld`.
///
/// Trois écrans de mot de passe refaisaient ce contrôle. Deux le portaient en
/// privé (`AccountPasswordResetView.swift:125`,
/// `AcctSecPasswordResetForm.swift:295`) et le troisième l'appelait **sans
/// jamais le déclarer** (`AccountForgotPasswordView.swift:104`), ce qui ne
/// compilait pas. Ce fichier donne la version partagée ; les deux copies
/// privées restent en place, elles fonctionnent et les remplacer sortirait du
/// périmètre de la correction.
enum AcctSecEmailValidation {

    /// Vrai si l'adresse a la forme `local@domaine.tld`.
    static func isPlausibleEmail(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 320 else { return false }
        guard !value.contains(where: { $0.isWhitespace }) else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.firstIndex(of: ".") else { return false }
        let afterDot = domain.index(after: dot)
        return dot != domain.startIndex && afterDot < domain.endIndex
    }
}
