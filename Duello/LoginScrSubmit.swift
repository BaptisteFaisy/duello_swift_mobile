//
//  LoginScrSubmit.swift
//  Duello
//
//  Soumission de l'écran de connexion, portée de `src/screens/LoginScreen.tsx`
//  (`submit`, `submitReset`, `loginWithBiometrics`) et de ses dépendances :
//    - `src/utils/credentials.ts` + `shared/new-password-policy.mjs`
//      (politique de mot de passe, réinitialisation par code de secours)
//    - `src/utils/biometricPolicy.ts` + `expo-local-authentication`
//      (disponibilité, demande, issues)
//
//  Les politiques déjà portées sont réutilisées telles quelles :
//  `AcctSecRecoveryCodePolicy` (vérification et repose du mot de passe,
//  remise d'un code neuf), `AcctSecBiometricPolicy` (règles et appel natif) et
//  `AdmPasswordPolicy` (message et bornes de longueur). Rien n'est recopié.
//
//  Limite assumée : `AdmPasswordPolicy.message` (« Choisis un mot de passe de
//  8 à 128 caractères. ») est le port de `NEW_PASSWORD_POLICY_MESSAGE` ;
//  `AcctSecRecoveryCodePolicy.passwordPolicyMessage` en donne une variante
//  (« Le mot de passe doit contenir… »). La source n'embarque que la première
//  formulation — c'est elle qui est utilisée ici.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

extension LoginScrScreen {
    // MARK: Soumission

    /// `submit` : aiguille vers la réinitialisation, le compte inconnu, le
    /// compte connu, l'activation administrateur ou la biométrie.
    func submit() {
        if isResetting {
            submitReset()
            return
        }
        guard LoginScrCredential.isValidEmail(email.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = LoginScrCopy.invalidEmail
            return
        }
        guard let account = selectedAccount else {
            submitUnknownAccount()
            return
        }
        if isAdminActivation {
            submitAdminActivation(account)
            return
        }
        if LoginScrAccountBook.isUser(account) && !account.isGuest {
            submitKnownAccount(account)
            return
        }
        if account.passwordHash == nil,
           AcctSecBiometricPolicy.canUseBiometricLogin(LoginScrAccountBook.security(account)) {
            errorMessage = LoginScrCopy.useBiometrics
            return
        }
        if account.passwordHash == nil && account.googleSubject != nil {
            errorMessage = LoginScrCopy.useGoogle
            return
        }
        if account.passwordHash == nil && account.appleSubject != nil {
            errorMessage = LoginScrCopy.useApple
            return
        }
        guard LoginScrCredential.verifyCredentials(account, email: email, password: password) else {
            errorMessage = LoginScrCopy.badCredentials
            return
        }
        submitKnownAccount(account)
    }

    /// Compte encore inconnu du registre : le serveur arbitre (`onPasswordLogin`).
    func submitUnknownAccount() {
        guard !password.isEmpty else {
            errorMessage = LoginScrCopy.enterPassword
            return
        }
        errorMessage = nil
        isAuthenticating = true
        Task { @MainActor in
            defer { isAuthenticating = false }
            do {
                try await props.onPasswordLogin(email.trimmingCharacters(in: .whitespaces), password)
            } catch {
                errorMessage = authMessage(error)
            }
        }
    }

    /// Compte utilisateur connu : mot de passe obligatoire, puis `onLogin`.
    func submitKnownAccount(_ account: LoginScrAccount) {
        guard !password.isEmpty else {
            if account.googleSubject != nil {
                errorMessage = LoginScrCopy.enterPasswordOrGoogle
            } else if account.appleSubject != nil {
                errorMessage = LoginScrCopy.enterPasswordOrApple
            } else {
                errorMessage = LoginScrCopy.enterPassword
            }
            return
        }
        errorMessage = nil
        isAuthenticating = true
        Task { @MainActor in
            defer { isAuthenticating = false }
            do {
                try await props.onLogin(account, password)
            } catch {
                errorMessage = authMessage(error)
            }
        }
    }

    /// Activation administrateur : le mot de passe choisi remplace l'attente et
    /// délivre aussitôt un code de secours.
    func submitAdminActivation(_ account: LoginScrAccount) {
        guard AdmPasswordPolicy.isValid(password) else {
            errorMessage = AdmPasswordPolicy.message
            return
        }
        guard password == passwordConfirmation else {
            errorMessage = LoginScrCopy.passwordMismatch
            return
        }
        issueRecoveryCode(for: account)
    }

    /// `submitReset` : récupération administrateur par code de secours.
    func submitReset() {
        guard LoginScrCredential.isValidEmail(email.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = LoginScrCopy.invalidResetEmail
            return
        }
        guard let admin = selectedAdminAccount else {
            errorMessage = LoginScrCopy.recoveryAdminOnly
            return
        }
        guard let storedHash = admin.recoveryCodeHash, !storedHash.isEmpty else {
            errorMessage = LoginScrCopy.noRecoveryCode
            return
        }
        guard AcctSecRecoveryCodePolicy.verify(recoveryCode, matches: storedHash) else {
            errorMessage = LoginScrCopy.recoveryMismatch
            return
        }
        guard AdmPasswordPolicy.isValid(password) else {
            errorMessage = AdmPasswordPolicy.message
            return
        }
        guard password == passwordConfirmation else {
            errorMessage = LoginScrCopy.passwordMismatch
            return
        }
        issueRecoveryCode(for: admin)
    }

    /// Repose le mot de passe et délivre un code neuf, puis **retient** le
    /// compte jusqu'à l'accusé de réception du code (comme la source).
    func issueRecoveryCode(for account: LoginScrAccount) {
        do {
            let reset = try AcctSecRecoveryCodePolicy.resetPassword(
                for: LoginScrAccountBook.security(account),
                password: password
            )
            var updated = account
            updated.recoveryCodeHash = reset.account.recoveryCodeHash
            errorMessage = nil

            let opened = updated
            let code = reset.code
            Task { @MainActor in
                await props.persistAccount(opened)
                issued = LoginScrIssuedCode(account: opened, code: code)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? AdmPasswordPolicy.message
        }
    }

    /// Message d'erreur d'un échec de connexion, aligné sur la source.
    func authMessage(_ error: Error) -> String {
        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? LoginScrCopy.unavailable : text
    }

    // MARK: Biométrie

    /// `loginWithBiometrics` : mêmes gardes que la source, puis appel natif.
    ///
    /// Seule la branche native est portée : la variante WebAuthn de la source
    /// (`Platform.OS === 'web'`) n'a pas d'équivalent sur iOS.
    func biometricLogin() {
        guard LoginScrCredential.isValidEmail(email.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = LoginScrCopy.biometricEmailFirst
            return
        }
        guard let account = selectedAccount else {
            errorMessage = LoginScrCopy.biometricUnknownAccount
            return
        }
        guard LoginScrAccountBook.isUser(account) else {
            errorMessage = LoginScrCopy.biometricUsersOnly
            return
        }
        guard AcctSecBiometricPolicy.canUseBiometricLogin(LoginScrAccountBook.security(account)) else {
            errorMessage = LoginScrCopy.biometricNotEnabled
            return
        }
        switch AcctSecBiometricPolicy.availability() {
        case .noHardware, .notEnrolled:
            errorMessage = account.passwordHash != nil
                ? LoginScrCopy.biometricSetupWithPassword
                : LoginScrCopy.biometricSetup
            return
        case .available:
            break
        }

        errorMessage = nil
        isAuthenticating = true
        Task { @MainActor in
            let outcome = await AcctSecBiometricPolicy.authenticate(
                prompt: AcctSecBiometricPolicy.loginPrompt
            )
            isAuthenticating = false
            switch outcome {
            case .success:
                errorMessage = nil
                do {
                    try await props.onLogin(account, nil)
                } catch {
                    errorMessage = authMessage(error)
                }
            case .cancelled:
                break
            case .lockout:
                errorMessage = LoginScrCopy.biometricLockout
            case .failed:
                errorMessage = LoginScrCopy.biometricFailed
            }
        }
    }
}
