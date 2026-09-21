//
//  RewGuestIdentity.swift
//  Duello
//
//  Identités invitées et comptes purement locaux (suite de `RewStorageScope`).
//
//  Fichier source Expo porté (commentaires repris mot pour mot) :
//    - src/utils/storageScope.ts
//        `GuestIdentity`, `LOCAL_DEMO_ACCOUNT_ID_BASE`, `LOCAL_DEMO_EMAIL_BASE`,
//        `isLocalOnlyDemoAccountId`, `isLocalOnlyAccountStorageId`,
//        `isLocalOnlyDemoEmail`, `createGuestIdentity`, `isGuestEmail`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Identité technique opaque d'un invité (`GuestIdentity`), sans exposer son
/// identifiant.
struct RewGuestIdentity: Equatable {
    /// `accountId` : identifiant de portée (`user-guest-…`).
    var accountId: String
    /// `email` : adresse synthétique (`guest-…@guest.duello.local`).
    var email: String
}

extension RewStorageScope {
    /// `LOCAL_DEMO_ACCOUNT_ID_BASE` : identifiant du téléphone virtuel.
    private static var localDemoAccountIdBase: String { "user-guest-demo-lucie" }
    /// `LOCAL_DEMO_EMAIL_BASE` : partie locale de l'adresse du téléphone virtuel.
    private static var localDemoEmailBase: String { "guest-demo-lucie" }

    /// `isLocalOnlyDemoAccountId` : identité réservée au téléphone virtuel de
    /// duello.fr/home.
    static func isLocalOnlyDemoAccountId(_ accountId: String) -> Bool {
        let normalized = accountId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = localDemoAccountIdBase
        return normalized == base || normalized.hasPrefix("\(base)-")
    }

    /// `isLocalOnlyAccountStorageId` : une portée purement locale n'a ni session
    /// ni dossier serveur ; ses écritures ne doivent jamais partir vers l'API.
    static func isLocalOnlyAccountStorageId(_ accountId: String) -> Bool {
        accountId == onboardingAccountStorageId || isLocalOnlyDemoAccountId(accountId)
    }

    /// `isLocalOnlyDemoEmail` : adresse synthétique qui ne doit jamais créer de
    /// session côté serveur.
    static func isLocalOnlyDemoEmail(_ email: String) -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let suffix = "@\(guestEmailDomain)"
        guard normalized.hasSuffix(suffix) else { return false }
        let localPart = String(normalized.dropLast(suffix.count))
        let base = localDemoEmailBase
        return localPart == base || localPart.hasPrefix("\(base)-")
    }

    /// `createGuestIdentity` : identité technique opaque d'un invité.
    /// `random` force une entropie déterministe (facultatif, comme le second
    /// paramètre de la source). L'entropie vient de `UUID` (équivalent de
    /// `crypto.randomUUID()` de la source ; le repli « quatre entiers en base
    /// 36 » n'a pas lieu d'être côté iOS).
    static func createGuestIdentity(
        now: Double = Date().timeIntervalSince1970 * 1000,
        random: Double? = nil
    ) -> RewGuestIdentity {
        let entropy: String
        if let random {
            let clamped = min(max(0, random), 0.999999999999)
            entropy = padded(String(UInt64(clamped * 0x1_0000_0000), radix: 36))
        } else {
            entropy = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
        let stamp = String(max(0, Int(now.rounded(.down))), radix: 36)
        let token = "\(stamp)-\(entropy)"
        return RewGuestIdentity(
            accountId: "user-guest-\(token)",
            email: "guest-\(token)@\(guestEmailDomain)"
        )
    }

    /// `isGuestEmail` : l'adresse appartient au domaine invité.
    static func isGuestEmail(_ email: String) -> Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .hasSuffix("@\(guestEmailDomain)")
    }

    /// `padStart(7, '0')` : complète à gauche sur sept caractères.
    private static func padded(_ value: String) -> String {
        let missing = max(0, 7 - value.count)
        return String(repeating: "0", count: missing) + value
    }
}
