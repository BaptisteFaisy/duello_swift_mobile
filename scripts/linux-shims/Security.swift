// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// Reproduit l'API `Security`/Keychain utilisée par `Duello/SessionStore.swift`
// (framework Apple absent sous Linux) afin de pouvoir contrôler les TYPES des
// fichiers portables avec `swiftc`. Aucune de ces fonctions n'est exécutée :
// elles ne servent qu'à satisfaire le vérificateur de types.
import Foundation
import CoreFoundation

public typealias OSStatus = Int32

public let kSecClass: String = "class"
public let kSecClassGenericPassword: String = "genp"
public let kSecAttrService: String = "svce"
public let kSecAttrAccount: String = "acct"
public let kSecValueData: String = "v_Data"
public let kSecReturnData: String = "r_Data"
public let kSecMatchLimit: String = "m_Limit"
public let kSecMatchLimitOne: String = "m_LimitOne"

public let errSecSuccess: OSStatus = 0
public let errSecItemNotFound: OSStatus = -25300

@discardableResult
public func SecItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<AnyObject?>?) -> OSStatus { errSecSuccess }

@discardableResult
public func SecItemUpdate(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus { errSecSuccess }

@discardableResult
public func SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<AnyObject?>?) -> OSStatus { errSecSuccess }

@discardableResult
public func SecItemDelete(_ query: CFDictionary) -> OSStatus { errSecSuccess }
