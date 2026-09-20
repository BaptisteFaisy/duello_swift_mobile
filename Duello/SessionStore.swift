import Foundation
import Security

/// Session serveur, alignée sur `ServerSession` de `src/utils/serverSession.ts`.
struct ServerSession: Codable, Equatable {
    var token: String
    var expiresAt: String
    var publicId: String
    var email: String
}

/// Compte local et profil, persistés dans le trousseau et les préférences.
final class SessionStore: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var profile: UserProfile = UserProfile()
    @Published var isLoadingSession: Bool = true

    private(set) var session: ServerSession?

    private static let service = "com.duello.ios.session"
    private static let account = "session-v1"
    private static let profileKey = "com.duello.ios.profile"

    init() {
        restoreSession()
    }

    var token: String? { session?.token }
    var isTokenValid: Bool {
        guard let session else { return false }
        guard let expires = ISO8601DateFormatter.date(fromISO: session.expiresAt) else { return false }
        return session.token.hasPrefix("dus_") && expires > Date()
    }

    // MARK: Connexion / inscription

    @MainActor
    func signIn(email: String, password: String) async throws {
        let payload = try await DuelloAPI.login(email: email, password: password)
        try applySession(payload, email: email)
    }

    @MainActor
    func signUp(email: String, password: String, displayName: String) async throws {
        let deviceId = Self.deviceId()
        let payload = try await DuelloAPI.register(
            email: email,
            password: password,
            displayName: displayName,
            deviceId: deviceId
        )
        try applySession(payload, email: email)
    }

    /// Ouvre la session renvoyée par `POST /auth/google` et préremplit le
    /// profil comme `profileWithGoogleIdentity` (`utils/googleAccount.ts`) :
    /// prénom en affichage, e-mail Google, profil public, sans photo du
    /// fournisseur entre les comptes.
    @MainActor
    func signInWithGoogle(identity: GoogleIdentity, payload: DuelloAPI.SessionPayload) throws {
        try applySession(payload, email: identity.email)

        let words = identity.displayName.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let firstName = identity.firstName.isEmpty ? (words.first ?? "") : identity.firstName
        let lastName = identity.lastName.isEmpty ? words.dropFirst().joined(separator: " ") : identity.lastName

        profile.firstName = firstName
        profile.lastName = lastName
        profile.displayName = firstName.isEmpty ? identity.displayName : firstName
        profile.email = identity.email
        profile.photoUri = nil
        profile.isPublic = true
        persistProfile()
    }

    @MainActor
    func signOut() async {
        if let token {
            await DuelloAPI.logout(token: token)
        }
        session = nil
        isSignedIn = false
        Keychain.delete(service: Self.service, account: Self.account)
    }

    // MARK: Persistance

    private func applySession(_ payload: DuelloAPI.SessionPayload, email: String) throws {
        let session = ServerSession(
            token: payload.token,
            expiresAt: payload.expiresAt,
            publicId: payload.publicId,
            email: payload.email.isEmpty ? email : payload.email
        )
        guard session.token.hasPrefix("dus_") else {
            throw DirectoryError(message: "Session refusée par le serveur Duello.")
        }
        self.session = session
        isSignedIn = true
        profile.email = session.email
        if profile.displayName.isEmpty {
            profile.displayName = email.split(separator: "@").first.map(String.init) ?? "Élève"
        }
        if profile.firstName.isEmpty {
            profile.firstName = profile.displayName
        }
        persistSession(session)
        persistProfile()
    }

    private func restoreSession() {
        if let data = Keychain.read(service: Self.service, account: Self.account),
           let session = try? JSONDecoder().decode(ServerSession.self, from: data) {
            self.session = session
            isSignedIn = session.token.hasPrefix("dus_")
        }
        if let data = UserDefaults.standard.data(forKey: Self.profileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = profile
        }
        isLoadingSession = false
    }

    private func persistSession(_ session: ServerSession) {
        if let data = try? JSONEncoder().encode(session) {
            Keychain.save(data, service: Self.service, account: Self.account)
        }
    }

    func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.profileKey)
        }
    }

    /// Identifiant d'appareil stable, requis à l'inscription et à la
    /// connexion Google (équivalent de `registrationDeviceId`). Le serveur
    /// n'accepte que les identifiants préfixés par la plateforme (`ios:`,
    /// `android:`, `web:`, `fallback:`) : un UUID nu est refusé (réponse
    /// `device-id-required`).
    static func deviceId() -> String {
        let key = "com.duello.ios.device-id"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            // Un identifiant créé par une version antérieure (UUID nu) est
            // migré vers le format attendu plutôt que régénéré.
            if existing.contains(":") {
                return existing
            }
            let migrated = "ios:" + existing
            UserDefaults.standard.set(migrated, forKey: key)
            return migrated
        }
        let created = "ios:" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}

// MARK: - Trousseau

enum Keychain {
    static func save(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }

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

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Dates ISO tolérantes

extension ISO8601DateFormatter {
    /// Le serveur peut envoyer des dates avec ou sans fractions de seconde.
    static let flexible: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func date(fromISO string: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        return flexible.date(from: string)
    }
}
