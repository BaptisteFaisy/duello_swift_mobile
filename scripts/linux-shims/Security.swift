// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// Reproduit l'API `Security`/Keychain utilisée par `Duello/SessionStore.swift`
// (framework Apple absent sous Linux) afin de pouvoir contrôler les TYPES des
// fichiers portables avec `swiftc`. Aucune de ces fonctions n'est exécutée :
// elles ne servent qu'à satisfaire le vérificateur de types.
import Foundation

/// Sur Apple, `Security` réexporte CoreFoundation. Sous Linux, corelibs expose
/// bien `CFString`/`CFDictionary`, mais sans le pont implicite vers
/// `String`/`[String: Any]` — et `CFString` n'y accepte pas de littéral. Le shim
/// les ramène donc à leurs équivalents Swift, ce que le code de Duello attend
/// (il construit des dictionnaires `[String: Any]`).
public typealias CFString = String
public typealias CFDictionary = [String: Any]

public typealias OSStatus = Int32

public let kSecClass: String = "class"
public let kSecClassGenericPassword: String = "genp"
public let kSecAttrService: String = "svce"
public let kSecAttrAccount: String = "acct"
public let kSecValueData: String = "v_Data"
public let kSecReturnData: String = "r_Data"
public let kSecMatchLimit: String = "m_Limit"
public let kSecMatchLimitOne: String = "m_LimitOne"

public let kSecAttrAccessible: CFString = "accessible"
public let kSecAttrAccessibleWhenUnlockedThisDeviceOnly: CFString = "accessible-when-unlocked-this-device-only"
public let kSecAttrAccessibleAfterFirstUnlock: CFString = "accessible-after-first-unlock"

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
