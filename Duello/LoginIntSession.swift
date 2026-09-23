//
//  LoginIntSession.swift
//  Duello
//
//  LOT 20 — pont d'ouverture de session pour la connexion Apple de l'écran de
//  connexion sombre (`LoginScrScreen`, porté de `src/screens/LoginScreen.tsx`).
//
//  `SessionStore.swift` est **hors périmètre** de ce lot et n'expose aucune
//  entrée Apple : la seule entrée qui ouvre une session à partir d'une identité
//  fournisseur est `signInWithGoogle(identity:payload:)`. On lui présente donc
//  une `GoogleIdentity` **construite depuis l'identité Apple déjà validée par le
//  serveur** (`AppleAuthIdentity`) : l'effet est le même que la source
//  (`profileWithAppleIdentity` / `profileWithGoogleIdentity` produisent le même
//  profil : prénom, nom, e-mail normalisé, profil public, sans photo distante).
//  Le jeton local n'est jamais lu : seule la session serveur est ouverte.
//
//  Limite assumée : l'arbitrage du registre local
//  (`AppleAuthAccountResolver.resolve`, registre non porté) n'est pas appliqué ;
//  seul le refus du compte administrateur (`isAdminEmail`) l'est, comme la
//  source. À lever le jour où le registre local (`utils/auth.ts`) sera porté.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Ouverture d'une session Duello à partir d'une identité Apple validée.
enum LoginIntSession {
    /// Ouvre la session Apple ; refuse l'adresse administrateur comme la source.
    ///
    /// `@MainActor` : `SessionStore.signInWithGoogle` l'est, et l'appelant
    /// (`LoginIntAssembly`) exécute ce pont depuis un `Task { @MainActor in … }`.
    @MainActor
    static func openAppleSession(
        session: SessionStore,
        identity: AppleAuthIdentity,
        payload: DuelloAPI.SessionPayload
    ) throws {
        guard !AppleAuthAccountResolver.isAdminEmail(identity.email) else {
            throw DirectoryError(message: AppleAuthAccountResolver.adminRejection)
        }

        let bridge = GoogleIdentity(
            subject: identity.subject,
            email: identity.email,
            displayName: identity.displayName,
            firstName: identity.firstName,
            lastName: identity.lastName,
            photoUrl: nil
        )
        try session.signInWithGoogle(identity: bridge, payload: payload)
    }

    /// Ouvre la session Google ; refuse l'adresse administrateur comme la
    /// source (`onGoogleAuthenticated` arbitré par le parent).
    @MainActor
    static func openGoogleSession(
        session: SessionStore,
        identity: GoogleIdentity,
        payload: DuelloAPI.SessionPayload
    ) throws {
        guard !AppleAuthAccountResolver.isAdminEmail(identity.email) else {
            throw DirectoryError(message: AppleAuthAccountResolver.adminRejection)
        }
        try session.signInWithGoogle(identity: identity, payload: payload)
    }
}
