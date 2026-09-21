//
//  OfflContentHash.swift
//  Duello
//
//  Empreinte SHA-256 et helpers JSON du contenu hors ligne.
//
//  Fichiers source Expo portés : `src/content/sha256.ts` (empreinte hexadécimale
//  de vérification) et les accès `unknown`/`JSON.parse`/`JSON.stringify` de
//  `src/content/contentStore.ts` et `src/content/contentCache.ts`.
//
//  `CryptoKit` fournit `SHA256` sur iOS 16 ; les entrées JSON restent
//  hétérogènes (tableaux ou objets) et sont manipulées via `JSONSerialization`,
//  comme le `unknown` de la source.
//
//  Cible : iOS 16.
//
import CryptoKit
import Foundation

/// Empreinte SHA-256 en hexadécimal (64 caractères minuscules).
enum OfflContentHash {
    static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hex(_ text: String) -> String {
        hex(Data(text.utf8))
    }
}

/// Conversions JSON tolérantes pour des entrées de forme inconnue.
enum OfflContentJSON {
    /// Tableau JSON, ou `nil` si le texte n'est pas un tableau valide.
    static func array(_ serialized: String) -> [Any]? {
        guard let data = serialized.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [Any]
    }

    /// Sérialisation compacte d'un objet JSON valide (tableau ou objet).
    static func string(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
