//
//  AdmPasswordPolicy.swift
//  Duello
//
//  Politique de mot de passe de l'application, portée de
//  `shared/new-password-policy.mjs` (importée par `src/admin/AdminApp.tsx`) :
//  longueur bornée et message affiché repris **mot pour mot**.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// `validNewPassword` / `NEW_PASSWORD_POLICY_MESSAGE` de
/// `shared/new-password-policy.mjs`.
enum AdmPasswordPolicy {
    /// `NEW_PASSWORD_MIN_LENGTH`.
    static let minLength = 8
    /// `NEW_PASSWORD_MAX_LENGTH`.
    static let maxLength = 128

    /// `NEW_PASSWORD_POLICY_MESSAGE` :
    /// « Choisis un mot de passe de 8 à 128 caractères. »
    static let message = "Choisis un mot de passe de \(minLength) à \(maxLength) caractères."

    /// `validNewPassword` : longueur comprise entre les deux bornes.
    static func isValid(_ value: String) -> Bool {
        value.count >= minLength && value.count <= maxLength
    }
}
