import Foundation
import Security

// Accès au trousseau iOS avec accessibilité configurable. Le `Keychain` partagé
// (`SessionStore.swift`) n'expose que les entrées par défaut ; la source Expo
// (`expo-secure-store`) fixe une accessibilité précise selon l'usage
// (`WHEN_UNLOCKED_THIS_DEVICE_ONLY` pour l'IDFV dans `deviceRegistration.ts`,
// `AFTER_FIRST_UNLOCK` pour la preuve de reconnexion dans `deviceRecovery.ts`).
// Ce helper local la reproduit sans toucher au type partagé.

/// Lecture / écriture / suppression d'entrées du trousseau, avec accessibilité.
enum DevRegKeychain {
    /// Enregistre une donnée (met à jour l'entrée existante, sinon la crée).
    static func save(_ data: Data, service: String, account: String, accessible: CFString) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = accessible
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    /// Lit une donnée, ou `nil` si l'entrée est absente ou illisible.
    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }

    /// Supprime une entrée (sans échouer si elle est déjà absente).
    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
