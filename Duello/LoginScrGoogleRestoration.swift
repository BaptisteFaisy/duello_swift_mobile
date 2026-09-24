//
//  LoginScrGoogleRestoration.swift
//  Duello
//
//  Port de src/utils/googleSessionRestorationPolicy.ts +
//  src/utils/googleSessionRestoration.native.ts (RN) — restauration silencieuse
//  de la session serveur Google au lancement, et garde de correspondance.
//
//  Migre un compte Google local créé avant les sessions Duello révocables :
//  `restorePreviousSignIn` ne rouvre qu'un compte Google déjà autorisé, sans
//  sélecteur ni boîte système ; la preuve reçue reste vérifiée par le serveur.
//
//  Couture honnête (24/09/2026) — dépendances natives et réductions assumées :
//    - Le `ServerSession` Swift ne porte PAS `localAccountId`, et le registre de
//      comptes locaux (`utils/auth.ts`) n'est pas porté (`LoginScrLogic.swift`).
//      `bindServerSessionAccount(accountId)` n'a donc pas d'équivalent exact : le
//      protocole `LoginScrGoogleSessionBinding` rend la couture explicite, et
//      l'adaptateur `LoginScrSessionStoreBinding` documente la réduction.
//    - La source vérifie la preuve via `verifyGoogleIdToken`, qui **persiste**
//      déjà la session (`saveServerSession`) avant la garde. Côté Swift,
//      `DuelloAPI.googleAuth` ne persiste rien : `restoreGoogleServerSession`
//      reproduit l'ordre (persister, puis garder) via la couture.
//    - `googleSessionRestoration.ts` (variante web) renvoie toujours `false` :
//      sans objet sur iOS, non portée.
//
//  Cible : iOS 16. Dépendance : SDK GoogleSignIn (déjà utilisée par
//  `GoogleAuth.swift`), aucune dépendance nouvelle.
//

import Foundation
import GoogleSignIn

/// `googleSessionMatchesAccount` (`utils/googleSessionRestorationPolicy.ts`) :
/// une restauration silencieuse ne doit jamais rouvrir le mauvais compte local.
/// L'e-mail peut changer chez Google ; seul le `sub` déjà lié est une preuve
/// stable que la session restaurée appartient bien au compte attendu. Un
/// `googleSubject` absent ou vide ne correspond à rien.
func googleSessionMatchesAccount(account: LoginScrAccount, identity: GoogleIdentity) -> Bool {
    guard let subject = account.googleSubject, !subject.isEmpty else { return false }
    return subject == identity.subject
}

/// Couture honnête vers la session serveur (`utils/serverSession.ts`).
///
/// Côté Swift, la session unique vit dans le trousseau (`SessionStore`) et ne
/// porte pas de `localAccountId`. Le protocole isole les trois opérations que
/// la source enchaîne ; un test ou un aperçu peut fournir une implémentation en
/// mémoire, l'application réelle utilise `LoginScrSessionStoreBinding`.
@MainActor
protocol LoginScrGoogleSessionBinding {
    /// `saveServerSession` : persiste la session renvoyée par `POST /auth/google`.
    func saveServerSession(_ payload: DuelloAPI.SessionPayload, fallbackEmail: String) throws
    /// `bindServerSessionAccount` : rattache la session au compte local.
    func bindServerSessionAccount(_ accountId: String)
    /// `clearServerSession` : oublie (et révoque) la session serveur.
    func clearServerSession() async
}

/// Adaptateur réel de la couture, sur `SessionStore`.
@MainActor
struct LoginScrSessionStoreBinding: LoginScrGoogleSessionBinding {
    let store: SessionStore

    func saveServerSession(_ payload: DuelloAPI.SessionPayload, fallbackEmail: String) throws {
        try store.installSession(ServerSession(payload: payload, fallbackEmail: fallbackEmail))
    }

    /// Réduction assumée : la session unique vit dans le trousseau sans
    /// `localAccountId`, et l'installation par `saveServerSession` a déjà marqué
    /// le compte connecté — il n'y a rien de plus à rattacher.
    func bindServerSessionAccount(_ accountId: String) {}

    /// `clearServerSession` : `SessionStore` n'expose pas de session détachée du
    /// compte local ; la fermeture révoque le jeton et efface la session.
    func clearServerSession() async {
        await store.signOut()
    }
}

/// Restauration silencieuse de la session serveur Google
/// (`utils/googleSessionRestoration.native.ts`).
enum LoginScrGoogleRestoration {
    /// `restoreGoogleServerSession` : rouvre en silence la session serveur d'un
    /// compte Google local déjà autorisé, puis vérifie que l'identité rendue par
    /// le serveur correspond bien au `sub` du compte (`googleSessionMatchesAccount`).
    /// Renvoie `true` seulement si la session a été liée au compte attendu.
    @MainActor
    static func restoreGoogleServerSession(
        account: LoginScrAccount,
        binding: LoginScrGoogleSessionBinding
    ) async -> Bool {
        guard GoogleClientIds.isConfigured,
              account.googleSubject?.isEmpty == false
        else { return false }

        do {
            guard let idToken = await silentIdToken() else { return false }
            let result = try await DuelloAPI.googleAuth(
                idToken: idToken,
                deviceId: SessionStore.deviceId(),
                username: nil
            )
            // `verifyGoogleIdToken` a déjà persisté la session (`saveServerSession`).
            try binding.saveServerSession(result.session, fallbackEmail: result.identity.email)
            if !googleSessionMatchesAccount(account: account, identity: result.identity) {
                // La session vient d'être créée pour une autre identité : elle ne
                // doit ni rester en cache, ni publier pour ce compte local.
                await binding.clearServerSession()
                return false
            }
            binding.bindServerSessionAccount(account.id)
            return true
        } catch {
            return false
        }
    }

    /// Restauration silencieuse : uniquement une session Google déjà autorisée
    /// (`restorePreviousSignIn`), jamais de sélecteur ni de boîte système — le
    /// bouton de connexion reste le recours interactif explicite
    /// (`GoogleAuthService`).
    @MainActor
    private static func silentIdToken() async -> String? {
        GoogleAuthService.shared.configure()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, _ in
                let token = user?.idToken?.tokenString ?? ""
                continuation.resume(returning: token.isEmpty ? nil : token)
            }
        }
    }
}
