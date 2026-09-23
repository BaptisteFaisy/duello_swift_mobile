import Foundation
import Security
import UIKit

// Port de `src/utils/deviceRegistration.ts` (identifiant d'installation stable)
// et de l'appel de pré-contrôle `POST /auth/registration/preflight` de
// `src/utils/accountRegistration.ts` (`ensureAccountRegistrationAvailable`).
//
// L'identifiant transmis lors d'une création de compte est l'IDFV figé dans le
// trousseau sur iOS, avec repli local persisté dans `UserDefaults`. Clés et
// formats sont repris mot pour mot de la source.
//
// Limite : la source Expo couvre aussi Android et le web ; la cible étant iOS,
// seuls les chemins `ios:` et `fallback:` sont portés.

/// Identifiant d'installation stable de l'appareil.
enum DevReg {
    /// Clé du repli persistant (`AsyncStorage` côté Expo).
    static let fallbackKey = "@prepapp/registration-device-v1"
    /// Entrée du trousseau iOS (`SecureStore` côté Expo).
    static let iosKey = "duello.registration-device.v1"
    /// Service du trousseau associé à l'IDFV.
    static let keychainService = "com.duello.ios.registration"

    /// Identifiant transmis lors d'une création de compte
    /// (`registrationDeviceId`) : préfixé par la plateforme (`ios:`,
    /// `fallback:`), comme l'exige le serveur.
    static func registrationDeviceId() -> String {
        if let vendorId = iosRegistrationDeviceId() {
            return "ios:\(vendorId)"
        }
        return "fallback:\(fallbackDeviceId())"
    }

    /// IDFV figé dans le trousseau (`iosRegistrationDeviceId`). Conserver
    /// l'IDFV empêche une réinstallation ordinaire de recréer un essai : le
    /// trousseau survit à la désinstallation avec le même identifiant de bundle.
    static func iosRegistrationDeviceId() -> String? {
        if let data = DevRegKeychain.read(service: keychainService, account: iosKey),
           let stored = String(data: data, encoding: .utf8)?
               .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           isValidVendorId(stored) {
            return stored
        }
        guard let vendorId = UIDevice.current.identifierForVendor?.uuidString
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            isValidVendorId(vendorId) else { return nil }
        DevRegKeychain.save(
            Data(vendorId.utf8),
            service: keychainService,
            account: iosKey,
            accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        )
        return vendorId
    }

    /// Repli quand l'IDFV est indisponible (`fallbackDeviceId`). Un stockage
    /// privé peut être indisponible : l'inscription reste possible, mais cet
    /// identifiant éphémère ne résistera pas au rechargement.
    static func fallbackDeviceId() -> String {
        let created = randomInstallationId()
        if let stored = UserDefaults.standard.string(forKey: fallbackKey),
           isValidFallbackId(stored) {
            return stored
        }
        UserDefaults.standard.set(created, forKey: fallbackKey)
        return created
    }

    /// Identifiant local réinitialisable (`randomInstallationId`).
    static func randomInstallationId() -> String {
        let stamp = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        return "\(stamp)-\(randomToken())-\(randomToken())"
    }

    /// Segment aléatoire base 36 (12 caractères), équivalent de
    /// `Math.random().toString(36).slice(2)`.
    static func randomToken() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))
    }

    /// `/^[a-f0-9-]{20,80}$/` (valeur déjà trimée et en minuscules).
    static func isValidVendorId(_ value: String) -> Bool {
        guard (20...80).contains(value.count) else { return false }
        return value.allSatisfy { $0.isHexDigit || $0 == "-" }
    }

    /// `/^[a-z0-9-]{20,100}$/i`.
    static func isValidFallbackId(_ value: String) -> Bool {
        guard (20...100).contains(value.count) else { return false }
        return value.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" }
    }
}

// MARK: - Pré-contrôle d'inscription

extension DevReg {
    /// Verdict du pré-contrôle (`RegistrationPreflightOutcome`).
    enum PreflightOutcome: String {
        case verified
        case unverified
    }

    /// Vérifie qu'une inscription est encore possible sans créer de compte
    /// (`ensureAccountRegistrationAvailable`, `POST /auth/registration/preflight`).
    /// Un relais lent ne rend pas de verdict : délai dépassé, coupure réseau ou
    /// panne passagère (5xx, 429) renvoient `unverified`. Seuls 409 (compte déjà
    /// inscrit) et 400 (appareil ou e-mail invalide) sont définitifs et lèvent
    /// une erreur.
    static func registrationPreflight(
        deviceId: String,
        email: String?
    ) async throws -> PreflightOutcome {
        let normalizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // La source **omet** le champ quand l'adresse est vide
        // (`...(normalizedEmail ? { email: normalizedEmail } : {})`,
        // `accountRegistration.ts:52-55`) : envoyer `""` fait répondre au serveur
        // 400 « Saisis une adresse e-mail valide. », ce qui bloque le parcours dès
        // le montage — quand aucune adresse n'a encore été collectée.
        let payloadEmail = normalizedEmail.flatMap { $0.isEmpty ? nil : $0 }
        var request = URLRequest(
            url: DuelloAPI.baseURL.appendingPathComponent("auth/registration/preflight")
        )
        request.httpMethod = "POST"
        // La source borne ce seul appel à 6 s (`REGISTRATION_PREFLIGHT_TIMEOUT_MS`).
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? DuelloAPI.encodeBody(
            DevRegPreflightBody(deviceId: deviceId, email: payloadEmail)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .unverified
        }
        guard let http = response as? HTTPURLResponse else { return .unverified }
        if (200..<300).contains(http.statusCode), preflightAvailable(data) {
            return .verified
        }
        if http.statusCode == 409 || http.statusCode == 400 {
            let message = (try? DuelloAPI.decoder.decode(DirectoryError.self, from: data))?.message
            throw DevRegPreflightError(
                message: message ?? "La création de compte est momentanément indisponible.",
                status: http.statusCode
            )
        }
        return .unverified
    }

    /// `payload.available === true`.
    private static func preflightAvailable(_ data: Data) -> Bool {
        let payload = try? DuelloAPI.decoder.decode(DevRegPreflightResponse.self, from: data)
        return payload?.available == true
    }
}

/// Corps de `POST /auth/registration/preflight`.
struct DevRegPreflightBody: Encodable {
    var deviceId: String
    var email: String?
}

/// Réponse `{ available?: boolean }` du pré-contrôle.
private struct DevRegPreflightResponse: Decodable {
    var available: Bool?
}

/// Refus définitif du pré-contrôle d'inscription.
struct DevRegPreflightError: LocalizedError {
    let message: String
    let status: Int

    var errorDescription: String? { message }
}
