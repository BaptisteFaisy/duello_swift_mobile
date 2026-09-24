//
//  AcctLocalRegistry+JSON.swift
//  Duello
//
//  Port de src/utils/auth.ts (RN) — lecture JSON tolérante du registre local :
//  un nombre entier ou flottant se lit de la même façon, un champ absent vaut
//  `nil`, comme `JSON.parse` de la source.
//
//  Découpage (24/09/2026) : section extraite de `AcctLocalRegistry.swift`
//  (porté du même fichier source).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

// MARK: - Aides JSON tolérantes

/// Lecture JSON tolérante, alignée sur `JSON.parse` de la source : un nombre
/// entier ou flottant se lit de la même façon, un champ absent vaut `nil`.
enum AcctLocalRegistryJSON {
    static func object(_ raw: String?) -> [String: Any]? {
        guard let raw, let data = raw.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return value as? [String: Any]
    }

    static func array(_ raw: String?) -> [[String: Any]]? {
        guard let raw, let data = raw.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return value as? [[String: Any]]
    }

    static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        return nil
    }

    static func bool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }
}
