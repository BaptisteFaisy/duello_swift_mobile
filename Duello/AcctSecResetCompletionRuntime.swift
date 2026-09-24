import Foundation

// Port de src/utils/passwordResetCompletionRuntime.ts (RN) — orchestration
// d'exécution : rattachement du compte mis à jour, dépendances concrètes, et
// passage par le sérialiseur partagé.
//
// La source compose `completePasswordReset` avec les vrais services
// (`resetServerPassword`, `savePasswordResetSession`, `abandon...`, le registre
// local des comptes). Ici :
//   - le transport réseau vient de `AcctSecResetTransport` ;
//   - la session/abandon vient de `AcctSecResetSession` via un
//     `AcctSecResetSessionBackend` fourni par l'appelant (couture) ;
//   - le registre local des comptes n'étant pas porté en Swift
//     (`utils/auth.ts`, cf. `LoginScrLogic.swift`), le compte de base vient de
//     `LoginScrAccountBook` quand une fiche locale existe, sinon de
//     `recoverAccount` (fourni par l'appelant), exactement comme la source.
//
// Cible : iOS 16. Aucune dépendance externe.

/// Environnement d'exécution (`PasswordResetRuntimeOptions` de la source).
struct AcctSecResetRuntimeOptions {
    var email: String
    var token: String
    var password: String
    /// Registre local des comptes (`accounts`), instantané minimal.
    var accounts: [LoginScrAccount]
    /// `recoverAccount` : compte utilisateur reconstruit depuis la réponse serveur.
    var recoverAccount: (RecoveredServerAccount) -> LoginScrAccount
    /// `isCurrent` : la demande est-elle encore la courante ?
    var isCurrent: () -> Bool
    /// `authenticate(account, isCurrent)` : ouvre la session applicative.
    var authenticate: (LoginScrAccount, @escaping () -> Bool) async -> Void
    /// `revokeApplicationAuthentication` : rejette l'utilisateur vers la connexion.
    var revokeApplicationAuthentication: () -> Void
    /// Couture de stockage de session (voir `AcctSecResetSession`).
    var sessionBackend: AcctSecResetSessionBackend
}

/// `const runPasswordResetCompletion = createSerializedPasswordResetCompletionRunner()`
/// : sérialiseur partagé par toutes les complétions du processus.
let runPasswordResetCompletion = createSerializedPasswordResetCompletionRunner()

/// `passwordResetCompletionRuntime.ts`.
enum AcctSecResetCompletionRuntime {

    /// `updatedPasswordResetAccount` : part d'une fiche locale utilisateur non
    /// invitée si elle existe, sinon du compte récupéré, puis fixe l'empreinte.
    static func updatedPasswordResetAccount(
        options: AcctSecResetRuntimeOptions,
        recovered: RecoveredServerAccount,
        password: String
    ) -> LoginScrAccount {
        let local = LoginScrAccountBook.find(options.accounts, email: options.email)
        let base: LoginScrAccount
        if let local, LoginScrAccountBook.isUser(local), !local.isGuest {
            base = local
        } else {
            base = options.recoverAccount(recovered)
        }
        var updated = base
        updated.passwordHash = LoginScrCredential.hashPassword(password)
        return updated
    }

    /// `completePasswordResetFlow` : compose les dépendances et exécute la
    /// complétion sous le sérialiseur partagé.
    static func completePasswordResetFlow(
        options: AcctSecResetRuntimeOptions
    ) async throws -> PasswordResetCompletionResult {
        try await runPasswordResetCompletion.run {
            try await completePasswordReset(
                options: PasswordResetCompletionOptions(
                    email: options.email,
                    token: options.token,
                    password: options.password
                ),
                dependencies: dependencies(for: options)
            )
        }
    }

    /// Assemblage des dépendances concrètes (`passwordResetCompletionRuntime.ts`).
    private static func dependencies(
        for options: AcctSecResetRuntimeOptions
    ) -> PasswordResetCompletionDependencies<LoginScrAccount> {
        PasswordResetCompletionDependencies(
            resetPassword: { email, token, password in
                try await AcctSecResetTransport.resetServerPassword(
                    email: email,
                    token: token,
                    password: password
                )
            },
            accountFromReset: { recovered, password in
                updatedPasswordResetAccount(options: options, recovered: recovered, password: password)
            },
            saveAuthentication: { session, account in
                try await AcctSecResetSession.savePasswordResetSession(
                    session: session,
                    account: account,
                    backend: options.sessionBackend
                )
            },
            isCurrent: options.isCurrent,
            authenticate: { account in
                await options.authenticate(account, options.isCurrent)
            },
            abandonAuthentication: {
                await AcctSecResetSession.abandonPasswordResetSession(backend: options.sessionBackend)
            },
            abandonSupersededAuthentication: { session in
                await AcctSecResetSession.abandonSupersededPasswordResetSession(
                    session: session,
                    backend: options.sessionBackend
                )
            },
            revokeApplicationAuthentication: options.revokeApplicationAuthentication
        )
    }
}
