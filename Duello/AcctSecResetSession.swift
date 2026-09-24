import Foundation

// Port de src/utils/passwordResetSession.ts et src/utils/passwordResetGeneration.ts
// (RN) — sauvegarde et abandon de la session de réinitialisation, et règlement
// d'une demande par jeton de génération.
//
// Dans la vue actuelle, la session de reset est remise brute à l'appelant
// (`onAuthenticated`), sans équivalent dédié : la « moitié abandon » de la
// source manquait. Ce fichier la porte.
//
// **Couture honnête** : la persistance (`saveServerSession` / `saveAccount` /
// `clearServerSession` / `clearPersistedAuthSession` / session courante /
// invalidation locale / révocation de jeton) est réunie derrière
// `AcctSecResetSessionBackend`, un jeu de fermetures que l'application doit
// brancher (voir `wave2-20260924/wiring/U6.md`). L'implémentation par défaut,
// `unavailable`, **refuse clairement** toute écriture plutôt que de simuler un
// succès silencieux.
//
// Cible : iOS 16. Aucune dépendance externe.

// MARK: - Couture de stockage

/// Erreur de la couture de stockage : levée par le backend non branché.
struct AcctSecResetSessionUnavailableError: LocalizedError, Equatable {
    let operation: String

    var errorDescription: String? {
        "Le stockage de session de réinitialisation n'est pas branché (\(operation))."
    }
}

/// Opérations de session et de compte requises par la réinitialisation
/// (équivalents Swift des primitives de `serverSession.ts` / `auth.ts`).
struct AcctSecResetSessionBackend {
    /// `saveServerSession(session, localAccountId)`.
    var saveServerSession: (ServerSession, String) async throws -> Void
    /// `saveAccount(account)` (registre local des comptes).
    var saveAccount: (LoginScrAccount) async -> Void
    /// `clearServerSession()`.
    var clearServerSession: () async -> Void
    /// `clearPersistedAuthSession(AsyncStorage)`.
    var clearPersistedAuthSession: () async -> Void
    /// `currentServerSession()`.
    var currentServerSession: () async -> ServerSession?
    /// `invalidateCheckedServerSession(checked)`.
    var invalidateCheckedServerSession: (ServerSession) async -> Bool
    /// `revokeServerSessionToken(token)`.
    var revokeServerSessionToken: (String) async -> Void

    /// Backend par défaut : **refuse** l'écriture de session (aucun stub muet).
    /// Les lectures renvoient « aucune session » ; la révocation ne fait rien
    /// faute de transport branché. À remplacer par le backend vivant côté app.
    static let unavailable = AcctSecResetSessionBackend(
        saveServerSession: { _, _ in
            throw AcctSecResetSessionUnavailableError(operation: "saveServerSession")
        },
        saveAccount: { _ in },
        clearServerSession: {},
        clearPersistedAuthSession: {},
        currentServerSession: { nil },
        invalidateCheckedServerSession: { _ in false },
        revokeServerSessionToken: { _ in }
    )
}

// MARK: - Session de réinitialisation

/// `passwordResetSession.ts`.
enum AcctSecResetSession {
    /// `savePasswordResetSession` : contrôle d'identité, puis session et compte.
    static func savePasswordResetSession(
        session: ServerSession,
        account: LoginScrAccount,
        backend: AcctSecResetSessionBackend
    ) async throws {
        guard passwordResetIdentityMatches(
            expected: account.email,
            sessionEmail: session.email,
            accountEmail: account.email
        ) else {
            throw DirectoryError(message: "La session Duello ne correspond pas au compte demandé.")
        }
        try await backend.saveServerSession(session, account.id)
        await backend.saveAccount(account)
    }

    /// `abandonPasswordResetSession` : les deux nettoyages en parallèle
    /// (`Promise.allSettled`), aucun ne lève.
    static func abandonPasswordResetSession(backend: AcctSecResetSessionBackend) async {
        async let server: Void = backend.clearServerSession()
        async let persisted: Void = backend.clearPersistedAuthSession()
        _ = await (server, persisted)
    }

    /// `abandonSupersededPasswordResetSession` : une demande remplacée ne doit
    /// jamais effacer la session d'une demande plus récente. On retire son
    /// propre jeton — localement s'il est encore courant, à distance toujours.
    static func abandonSupersededPasswordResetSession(
        session: ServerSession,
        backend: AcctSecResetSessionBackend
    ) async {
        let current = await backend.currentServerSession()
        async let revocation: Void = backend.revokeServerSessionToken(session.token)
        if let current, current.token == session.token {
            _ = await backend.invalidateCheckedServerSession(current)
        }
        _ = await revocation
    }

    /// `passwordResetIdentityMatches` (voir `passwordResetIdentity.ts`).
    private static func passwordResetIdentityMatches(
        expected: String,
        sessionEmail: String,
        accountEmail: String
    ) -> Bool {
        let target = LoginScrCredential.normalize(expected)
        return !target.isEmpty
            && LoginScrCredential.normalize(sessionEmail) == target
            && LoginScrCredential.normalize(accountEmail) == target
    }
}

// MARK: - Règlement par génération

/// `settlePasswordResetRequest` (`passwordResetGeneration.ts`) : le résultat
/// n'est rendu que si le jeton est **encore** courant ; une demande remplacée
/// est réglée par `nil`, sans jamais effacer la demande suivante.
func settlePasswordResetRequest(
    token: String,
    completion: () async -> PasswordResetCompletionResult,
    clearIfCurrent: (String) -> Bool
) async -> PasswordResetCompletionResult? {
    let result = await completion()
    return clearIfCurrent(token) ? result : nil
}
