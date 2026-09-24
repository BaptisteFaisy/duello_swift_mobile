import Foundation

// Port de src/utils/passwordResetCompletion.ts (RN) — cœur de la complétion
// d'une réinitialisation de mot de passe.
//
// La vue `AcctSecPasswordResetForm.swift` ne portait que le chemin nominal
// (un `await`, remise de la session à `SessionStore`). Ce fichier apporte la
// **machine à 4 issues** (`authenticated` / `login-required` /
// `outcome-unknown` / `superseded`), le **sérialiseur** de complétions et la
// garde+commit atomique. Il est volontairement pur — aucun accès au réseau ni
// au stockage : les dépendances arrivent en fermetures, comme dans la source,
// et sont branchées par `AcctSecResetCompletionRuntime.swift`.
//
// Cible : iOS 16. Aucune dépendance externe.

// MARK: - Erreurs

/// Erreur levée quand le serveur a peut-être déjà changé le mot de passe mais
/// que la réponse s'est perdue (`PasswordResetOutcomeUnknownError` de
/// `passwordResetAuthentication.ts`). Le message est fourni par le transport.
struct PasswordResetOutcomeUnknownError: LocalizedError, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

/// Erreur levée quand le mot de passe a changé mais que la session renvoyée
/// est inutilisable (`PasswordResetAuthenticationUnavailableError`). Message
/// repris mot pour mot de la source.
struct PasswordResetAuthenticationUnavailableError: LocalizedError, Equatable {
    var errorDescription: String? {
        "Le mot de passe a changé, mais la nouvelle session Duello est inutilisable."
    }
}

// MARK: - Modèles

/// Compte récupéré renvoyé par `POST /auth/password/reset`
/// (`RecoveredServerAccount` de `serverSession.ts`).
struct RecoveredServerAccount: Equatable {
    var email: String
    var displayName: String
    var googleSubject: String?
    var appleSubject: String?
    var createdAt: Double
    /// `Partial<UserProfile>` dans la source : le profil n'est lu que par le
    /// rattachement au compte (`recoverAccount`), jamais par ce module.
    var profile: [String: Any]? = nil

    static func == (lhs: RecoveredServerAccount, rhs: RecoveredServerAccount) -> Bool {
        lhs.email == rhs.email
            && lhs.displayName == rhs.displayName
            && lhs.googleSubject == rhs.googleSubject
            && lhs.appleSubject == rhs.appleSubject
            && lhs.createdAt == rhs.createdAt
    }
}

/// Session + compte récupérés (`PasswordResetAuthentication` de
/// `passwordResetHttp.ts`). La session locale n'a pas de `localAccountId` en
/// Swift : `ServerSession` s'y réduit.
struct PasswordResetAuthentication: Equatable {
    var session: ServerSession
    var account: RecoveredServerAccount
}

/// Options de la complétion (`PasswordResetCompletionOptions`).
struct PasswordResetCompletionOptions: Equatable {
    var email: String
    var token: String
    var password: String
}

/// Issue de la complétion (`PasswordResetCompletionResult`). Les libellés
/// `kind` reproduisent les chaînes de la source.
enum PasswordResetCompletionResult: Equatable {
    case authenticated
    case loginRequired(email: String)
    case outcomeUnknown(email: String)
    case superseded

    /// `result.kind` de la source.
    var kind: String {
        switch self {
        case .authenticated: return "authenticated"
        case .loginRequired: return "login-required"
        case .outcomeUnknown: return "outcome-unknown"
        case .superseded: return "superseded"
        }
    }

    /// `result.email` : renseigné pour `login-required` et `outcome-unknown`.
    var email: String? {
        switch self {
        case .loginRequired(let email), .outcomeUnknown(let email): return email
        case .authenticated, .superseded: return nil
        }
    }
}

/// Dépendances de la complétion (`PasswordResetCompletionDependencies`). Les
/// types génériques et les fermetures reproduisent les signatures de la source.
struct PasswordResetCompletionDependencies<Account> {
    var resetPassword: (String, String, String) async throws -> PasswordResetAuthentication
    var accountFromReset: (RecoveredServerAccount, String) throws -> Account
    var saveAuthentication: (ServerSession, Account) async throws -> Void
    var isCurrent: () -> Bool
    var authenticate: (Account) async throws -> Void
    var abandonAuthentication: () async -> Void
    var abandonSupersededAuthentication: (ServerSession) async -> Void
    var revokeApplicationAuthentication: () -> Void
}

// MARK: - Sérialiseur

/// `createSerializedPasswordResetCompletionRunner` : une seule complétion à la
/// fois peut toucher le stockage et l'état de l'application. L'acteur protège
/// la file ; la queue chaînée garantit que la complétion suivante attend la fin
/// de la précédente **quelle que soit son issue** (comme `tail.then(noop, noop)`).
actor PasswordResetCompletionRunner {
    private var tail: Task<Void, Never> = Task {}

    func run<Result: Sendable>(
        _ completion: @escaping @Sendable () async throws -> Result
    ) async throws -> Result {
        let previous = tail
        let task = Task { () async throws -> Result in
            await previous.value
            return try await completion()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }
}

/// Fabrique du sérialiseur, homologue de
/// `createSerializedPasswordResetCompletionRunner()`.
func createSerializedPasswordResetCompletionRunner() -> PasswordResetCompletionRunner {
    PasswordResetCompletionRunner()
}

/// `commitPasswordResetAuthenticationIfCurrent` : le garde et le commit restent
/// dans la même pile synchrone, sans suspension entre les deux.
@discardableResult
func commitPasswordResetAuthenticationIfCurrent(
    isCurrent: () -> Bool,
    commit: () -> Void
) -> Bool {
    guard isCurrent() else { return false }
    commit()
    return true
}

// MARK: - Complétion

/// `completePasswordReset` : machine à 4 issues. Toute erreur autre que
/// « issue inconnue » ou « session inutilisable » remonte telle quelle.
func completePasswordReset<Account>(
    options: PasswordResetCompletionOptions,
    dependencies: PasswordResetCompletionDependencies<Account>
) async throws -> PasswordResetCompletionResult {
    if !dependencies.isCurrent() { return .superseded }

    let reset: PasswordResetAuthentication
    do {
        reset = try await dependencies.resetPassword(
            options.email,
            options.token,
            options.password
        )
    } catch {
        return try await resetFailureResult(error, options: options, dependencies: dependencies)
    }

    if !dependencies.isCurrent() {
        await abandonSupersededPasswordResetAuthentication(dependencies, session: reset.session)
        return .superseded
    }
    return await commitPasswordResetAuthentication(reset, options: options, dependencies: dependencies)
}

/// Échec de `resetPassword` : seules « issue inconnue » et « session
/// inutilisable » sont absorbées ; tout le reste est relancé.
private func resetFailureResult<Account>(
    _ error: Error,
    options: PasswordResetCompletionOptions,
    dependencies: PasswordResetCompletionDependencies<Account>
) async throws -> PasswordResetCompletionResult {
    let outcomeUnknown = error is PasswordResetOutcomeUnknownError
    if !outcomeUnknown && !(error is PasswordResetAuthenticationUnavailableError) {
        throw error
    }
    if !dependencies.isCurrent() { return .superseded }
    await abandonPasswordResetAuthentication(dependencies)
    return outcomeUnknown
        ? .outcomeUnknown(email: options.email)
        : .loginRequired(email: options.email)
}

/// Chemin nominal : rattachement du compte, sauvegarde, authentification — avec
/// un contrôle de génération après chaque suspension.
private func commitPasswordResetAuthentication<Account>(
    _ reset: PasswordResetAuthentication,
    options: PasswordResetCompletionOptions,
    dependencies: PasswordResetCompletionDependencies<Account>
) async -> PasswordResetCompletionResult {
    do {
        let account = try dependencies.accountFromReset(reset.account, options.password)
        try await dependencies.saveAuthentication(reset.session, account)
        if !dependencies.isCurrent() {
            await abandonSupersededPasswordResetAuthentication(dependencies, session: reset.session)
            return .superseded
        }
        try await dependencies.authenticate(account)
        if !dependencies.isCurrent() {
            await abandonSupersededPasswordResetAuthentication(dependencies, session: reset.session)
            return .superseded
        }
        return .authenticated
    } catch {
        if !dependencies.isCurrent() {
            await abandonSupersededPasswordResetAuthentication(dependencies, session: reset.session)
            return .superseded
        }
        await abandonPasswordResetAuthentication(dependencies)
        return .loginRequired(email: options.email)
    }
}

/// `abandonPasswordResetAuthentication` : l'abandon, puis la révocation — la
/// révocation s'exécute dans tous les cas (le `finally` de la source ; les
/// abandons Swift ne lèvent pas).
private func abandonPasswordResetAuthentication<Account>(
    _ dependencies: PasswordResetCompletionDependencies<Account>
) async {
    await dependencies.abandonAuthentication()
    dependencies.revokeApplicationAuthentication()
}

/// `abandonSupersededPasswordResetAuthentication`.
private func abandonSupersededPasswordResetAuthentication<Account>(
    _ dependencies: PasswordResetCompletionDependencies<Account>,
    session: ServerSession
) async {
    await dependencies.abandonSupersededAuthentication(session)
}
