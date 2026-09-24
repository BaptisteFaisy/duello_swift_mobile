import Foundation
import Combine
import Security

/// Session serveur, alignée sur `ServerSession` de `src/utils/serverSession.ts`.
struct ServerSession: Codable, Equatable {
    var token: String
    var expiresAt: String
    var publicId: String
    var email: String
}

extension ServerSession {
    /// Session issue d'une réponse d'authentification ; `payload.email` peut
    /// être vide, l'adresse de la demande fait alors foi.
    init(payload: DuelloAPI.SessionPayload, fallbackEmail: String) {
        self.init(
            token: payload.token,
            expiresAt: payload.expiresAt,
            publicId: payload.publicId,
            email: payload.email.isEmpty ? fallbackEmail : payload.email
        )
    }
}

/// État de connexion et profil, isolés du reste de la session.
///
/// Lot PF7 (#57) : ces deux valeurs changent à chaque connexion ou édition de
/// profil. Les regrouper dans ce sous-store dédié — exposé tel quel par
/// `SessionStore` (`session.accountStore`) — permet aux vues feuilles de n'observer
/// que ce dont elles ont besoin, au lieu d'être ré-évaluées par toute écriture
/// de la session (jeton, chargement initial).
final class SessionAccountStore: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var profile: UserProfile = UserProfile()
}

/// Compte local et profil, persistés dans le trousseau et les préférences.
final class SessionStore: ObservableObject {
    /// État de connexion et profil, isolés dans leur propre objet observable.
    /// Les vues feuilles peuvent observer ce sous-store (`session.accountStore`)
    /// pour ne réagir qu'aux changements de compte.
    let accountStore = SessionAccountStore()

    @Published var isLoadingSession: Bool = true

    /// Relais de `accountStore.isSignedIn` : l'API publique ne change pas.
    var isSignedIn: Bool {
        get { accountStore.isSignedIn }
        set { accountStore.isSignedIn = newValue }
    }

    /// Relais de `accountStore.profile` (lecture et écriture, `$session.profile`
    /// compris).
    var profile: UserProfile {
        get { accountStore.profile }
        set { accountStore.profile = newValue }
    }

    /// Écriture réservée au module : `installSession`/`signOut` ici, et le mode
    /// capture (`ScreenshotTour`, outil de dev) qui sème une session factice.
    var session: ServerSession?

    private static let service = "com.duello.ios.session"
    private static let account = "session-v1"
    private static let profileKey = "com.duello.ios.profile"

    /// Relais des changements du sous-store : voir `init()`.
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Les vues qui observent `SessionStore` (injecté à la racine) restent
        // notifiées des changements de profil et de connexion : le sous-store
        // les relaie, comportement inchangé.
        accountStore.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        restoreSession()
        // Mode capture (outil de développement) : une session factice remplace
        // celle restaurée pour que les écrans authentifiés s'affichent dans un
        // simulateur CI sans compte. Hors de ce mode, `ScreenshotTour.screen`
        // vaut `nil` et rien de ceci ne s'exécute. La logique vit dans
        // `ScreenshotTour.swift` — outil de dev, jamais livré à l'usage.
        ScreenshotTour.seedSessionIfNeeded(self)
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
        try installSession(ServerSession(payload: payload, fallbackEmail: email))
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
        try installSession(ServerSession(payload: payload, fallbackEmail: email))
    }

    /// Ouvre la session renvoyée par `POST /auth/google` et préremplit le
    /// profil comme `profileWithGoogleIdentity` (`utils/googleAccount.ts`) :
    /// prénom en affichage, e-mail Google, profil public, sans photo du
    /// fournisseur entre les comptes.
    @MainActor
    func signInWithGoogle(identity: GoogleIdentity, payload: DuelloAPI.SessionPayload) throws {
        try installSession(ServerSession(payload: payload, fallbackEmail: identity.email))

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
        // La session de compte distante ne survit pas à la déconnexion
        // (`clearServerSession` de `serverSession.ts`) : sans elle,
        // `RewRemoteAccountData` ne peut plus rattacher aucune donnée à ce compte.
        UserDefaults.standard.removeObject(forKey: DevRegSessions.serverSessionStorageKey)
        // Effacement défensif des clés de session/authentification héritées
        // (`clearPersistedAuthSession` de `authSession.ts`), après la purge du
        // trousseau. Sur une installation Swift neuve, aucune de ces clés
        // n'existe : l'appel est un no-op silencieux, sans effet de bord.
        try? AcctAuthSession.clearPersistedAuthSession()
    }

    // MARK: Persistance

    /// Installe une session serveur validée : marque l'utilisateur connecté,
    /// aligne le profil local et persiste le tout. Point d'entrée unique des
    /// ouvertures de session — mot de passe, inscription, Google, et session
    /// rendue par `POST /auth/password/reset`.
    func installSession(_ session: ServerSession) throws {
        guard session.token.hasPrefix("dus_") else {
            throw DirectoryError(message: "Session refusée par le serveur Duello.")
        }
        self.session = session
        isSignedIn = true
        profile.email = session.email
        if profile.displayName.isEmpty {
            profile.displayName = session.email.split(separator: "@").first.map(String.init) ?? "Élève"
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
        persistRemoteAccountSession(session)
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
