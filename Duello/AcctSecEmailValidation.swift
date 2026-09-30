import Foundation

/// Contrôle d'adresse e-mail, aligné sur `validEmail` de
/// `ForgotPasswordScreen.tsx:28-30` : au plus 320 caractères et la forme
/// `^\S+@\S+\.\S+$` — au moins un caractère de chaque côté de l'arobase, puis
/// un point suivi d'au moins un caractère, sans espace.
///
/// ⚠️ La source n'exige **pas** un unique `@` : `\S+` peut couvrir un `@`
/// supplémentaire (`a@b@c.d` est valide). L'ancien contrôle « exactement un
/// arobase » (`split == 2`) divergeait donc de la référence.
///
/// Trois écrans de mot de passe refaisaient ce contrôle. Deux le portaient en
/// privé (`AccountPasswordResetView.swift:125`,
/// `AcctSecPasswordResetForm.swift:295`) et le troisième l'appelait **sans
/// jamais le déclarer** (`AccountForgotPasswordView.swift:104`), ce qui ne
/// compilait pas. Ce fichier donne la version partagée ; les deux copies
/// privées restent en place, elles fonctionnent et les remplacer sortirait du
/// périmètre de la correction.
enum AcctSecEmailValidation {

    /// `validEmail` de la source : `value.length <= 320 && /^\S+@\S+\.\S+$/.test(value)`.
    static func isPlausibleEmail(_ value: String) -> Bool {
        guard value.count <= 320 else { return false }
        return value.range(of: "^\\S+@\\S+\\.\\S+$", options: .regularExpression) != nil
    }
}
