//
//  LoginScrLayout.swift
//  Duello
//
//  Écran de connexion complet, porté de `src/screens/LoginScreen.tsx`
//  (plage 52-818 : `LoginScreenProps`, `LoginScreen`, `FieldProps`, `Field`).
//
//  Flux fidèle à la source : étape « identité » (adresse e-mail, fournisseurs,
//  biométrie) puis étape « identifiants » (mot de passe, mot de passe oublié,
//  réinitialisation administrateur par code de secours, activation du compte
//  administrateur), avec en-tête contextuel et remise du nouveau code de
//  secours.
//
//  Divergences assumées, propres à iOS (voir aussi la réponse de lot) :
//    - `DesktopQrLoginButton` et `downloadedAuthFormStyle` : la source les
//      neutralise déjà sur mobile (`isDownloadedDesktopApp()` renvoie
//      `false`) — rien à porter.
//    - `Platform.OS === 'web'` (carte de l'adresse retenue, biométrie WebAuthn,
//      `showWebFallback`) : sans objet sur iOS.
//    - `GoogleAuthButton` (WelcomeView.swift) porte une API différente de la
//      source : il ouvre la session lui-même, sans `onAuthenticated` /
//      `purpose` / `variant`. Il est réutilisé tel quel.
//
//  Réutilise : `AppleAuthView`, `AcctSecBiometricPolicy`,
//  `AcctSecRecoveryCodePolicy`, `AcctSecRecoveryCodeView`, `AdmPasswordPolicy`,
//  `DuelloWelcomeButton`. La soumission vit dans `LoginScrSubmit.swift`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `LoginScreenProps` de `src/screens/LoginScreen.tsx`.
///
/// `onLogin`, `onPasswordLogin` et `persistAccount` sont injectés par
/// l'appelant : la persistance du registre local (`saveAccount` de
/// `utils/auth.ts`) n'est pas portée, l'écran ne la connaît donc pas.
struct LoginScrProps {
    /// Compte rouvert (pré-remplit l'adresse).
    var account: LoginScrAccount? = nil
    var accounts: [LoginScrAccount] = []
    /// `onLogin(account, password)` — mot de passe facultatif (biométrie).
    var onLogin: (LoginScrAccount, String?) async throws -> Void
    /// `onPasswordLogin(email, password)` — compte encore inconnu du registre.
    var onPasswordLogin: (String, String) async throws -> Void
    /// `onAppleAuthenticated` — session Duello déjà validée par le serveur.
    var onAppleAuthenticated: (AppleAuthIdentity, DuelloAPI.SessionPayload) -> Void
    /// `onGoogleAuthenticated` — identité et session Google validées par le
    /// serveur ; l'appelant arbitre la réouverture du compte (le bouton
    /// Google n'ouvre plus la session lui-même).
    var onGoogleAuthenticated: (GoogleIdentity, DuelloAPI.SessionPayload) -> Void
    /// `onOpenPasswordReset(email)` — parcours serveur de réinitialisation.
    var onOpenPasswordReset: (String) -> Void
    /// `saveAccount(account)` — enregistre le compte rouvert ou activé.
    var persistAccount: (LoginScrAccount) async -> Void
    /// `onBack` — quitte l'écran.
    var onBack: () -> Void
}

/// `LoginScreen` de `src/screens/LoginScreen.tsx`.
///
/// L'état vit dans la vue (`useState` de la source) ; les méthodes de
/// soumission et de biométrie sont dans l'extension `LoginScrSubmit.swift`.
struct LoginScrScreen: View {
    let props: LoginScrProps

    @State var step: LoginScrStep = .identity
    @State var email: String
    @State var password = ""
    @State var passwordConfirmation = ""
    @State var recoveryCode = ""
    @State var showPassword = false
    @State var errorMessage: String?
    @State var isAuthenticating = false
    @State var isResetting = false
    @State var issued: LoginScrIssuedCode?
    /// `Alert.alert('Biométrie indisponible', …)` : alerte native du matériel
    /// biométrique absent (distincte du bandeau d'erreur inline).
    @State var biometricAlert: String?

    init(props: LoginScrProps) {
        self.props = props
        _email = State(initialValue: props.account?.email ?? "")
    }

    var body: some View {
        ZStack {
            LoginScrPalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                // `scrollContent` de la source : `flexGrow: 1` +
                // `justifyContent: 'center'` — le contenu se centre quand il
                // tient, et défile sinon.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            content
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    }
                }
                footer
            }
        }
        .overlay { recoveryOverlay }
        .alert("Biométrie indisponible", isPresented: biometricAlertPresented) {
            Button("OK", role: .cancel) { biometricAlert = nil }
        } message: {
            Text(biometricAlert ?? "")
        }
    }

    // MARK: Dérivés

    /// Compte reconnu à la saisie (`findAccountByEmail`).
    var selectedAccount: LoginScrAccount? {
        LoginScrAccountBook.find(props.accounts, email: email)
    }

    /// `selectedAdminAccount` : la récupération par code est réservée à l'admin.
    var selectedAdminAccount: LoginScrAccount? {
        guard let selectedAccount, selectedAccount.role == .admin else { return nil }
        return selectedAccount
    }

    /// `isAdminActivation`.
    var isAdminActivation: Bool {
        LoginScrAccountBook.isAdminActivation(selectedAdminAccount)
    }

    /// `canResetPassword`.
    var canResetPassword: Bool {
        LoginScrAccountBook.canResetPassword(selectedAdminAccount)
    }

    /// `canOfferBiometrics` : les quatre conditions de `biometricPolicy.ts`.
    var canOfferBiometrics: Bool {
        let security = selectedAccount.map(LoginScrAccountBook.security)
        return AcctSecBiometricPolicy.canOfferBiometricLogin(
            security,
            isResetting: isResetting,
            isAdminActivation: isAdminActivation,
            isSelectedAdmin: selectedAdminAccount != nil
        )
    }

    /// `canContinueWithBiometrics` : proposé sur la page des identifiants.
    var canContinueWithBiometrics: Bool {
        step == .credentials && canOfferBiometrics
    }

    /// `hasStartedEmail` : le bouton « Continuer » n'apparaît qu'après une frappe.
    var hasStartedEmail: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Libellé du bouton de pied de page, selon l'état (source : `primaryButtonText`).
    var submitTitle: String {
        if isResetting { return LoginScrCopy.submitReset }
        if isAdminActivation { return LoginScrCopy.submitActivation }
        return isAuthenticating ? LoginScrCopy.submitting : LoginScrCopy.submit
    }

    // MARK: Navigation

    /// `continueWithEmail` : valide l'adresse puis passe aux identifiants.
    func continueWithEmail() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard LoginScrCredential.isValidEmail(trimmed) else {
            errorMessage = LoginScrCopy.invalidEmail
            return
        }
        email = trimmed.lowercased()
        errorMessage = nil
        step = .credentials
    }

    /// `goBack` : referme d'abord la réinitialisation, puis revient d'une étape.
    func goBack() {
        if isResetting {
            closeReset()
            return
        }
        if step == .credentials {
            password = ""
            errorMessage = nil
            step = .identity
            return
        }
        props.onBack()
    }

    /// `openReset` : entre dans le parcours de réinitialisation administrateur.
    func openReset() {
        isResetting = true
        password = ""
        passwordConfirmation = ""
        recoveryCode = ""
        errorMessage = nil
    }

    /// `closeReset` : abandonne la réinitialisation et vide les saisies.
    func closeReset() {
        isResetting = false
        password = ""
        passwordConfirmation = ""
        recoveryCode = ""
        errorMessage = nil
    }

    /// `forgotPassword` : réinitialisation locale pour l'admin, serveur sinon.
    func forgotPassword() {
        if selectedAdminAccount != nil {
            openReset()
            return
        }
        errorMessage = nil
        props.onOpenPasswordReset(email.trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - Mise en page

private extension LoginScrScreen {
    var topBar: some View {
        HStack {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(LoginScrPalette.onDark)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(LoginScrPressStyle(pressedOpacity: 0.6, pressedScale: 1))
            .offset(x: -12)
            .accessibilityLabel("Revenir en arrière")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// Contenu défilant. La source centre verticalement
    /// (`justifyContent: 'center'`) ; `ScrollView` ne le permet pas, l'écart
    /// de mise en page est assumé.
    @ViewBuilder var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if step == .identity {
                identityForm
            } else {
                credentialsForm
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
    }

    /// En-tête contextuel de la réinitialisation / activation.
    @ViewBuilder var header: some View {
        if step == .credentials && (isResetting || isAdminActivation) {
            LoginScrEyebrowHeader(
                eyebrow: isResetting ? LoginScrCopy.resetEyebrow : LoginScrCopy.adminEyebrow,
                title: isResetting ? LoginScrCopy.resetTitle : LoginScrCopy.adminTitle,
                subtitle: isResetting ? LoginScrCopy.resetSubtitle : LoginScrCopy.adminSubtitle
            )
        }
    }

    /// Étape « identité » : adresse, fournisseurs, biométrie.
    @ViewBuilder var identityForm: some View {
        VStack(spacing: 19) {
            emailField

            if let errorMessage {
                LoginScrErrorCard(message: errorMessage)
            }

            GoogleAuthButton(
                appearance: .dark,
                onAuthenticated: { identity, payload in
                    props.onGoogleAuthenticated(identity, payload)
                }
            )

            AppleAuthView(appearance: .dark) { identity, payload in
                props.onAppleAuthenticated(identity, payload)
            }

            if canOfferBiometrics {
                LoginScrDivider()
                LoginScrBiometricButton(isLoading: isAuthenticating) { biometricLogin() }
            }
        }
        .padding(.top, 26)
    }

    /// Étape « identifiants » : mot de passe, code, confirmation, biométrie.
    @ViewBuilder var credentialsForm: some View {
        VStack(spacing: 19) {
            if isResetting {
                recoveryCodeField
            }

            passwordField

            if !isResetting && !isAdminActivation {
                LoginScrLinkButton(title: LoginScrCopy.forgotPassword) { forgotPassword() }
            }

            if isAdminActivation || isResetting {
                confirmField
            }

            if let errorMessage {
                LoginScrErrorCard(message: errorMessage)
            }

            if isResetting && canResetPassword {
                LoginScrLinkButton(title: LoginScrCopy.backToLogin) { closeReset() }
            }

            if canContinueWithBiometrics {
                LoginScrDivider()
                LoginScrBiometricButton(isLoading: isAuthenticating) { biometricLogin() }
            }
        }
        .padding(.top, 26)
    }

    var emailField: some View {
        LoginScrField(
            props: LoginScrFieldProps(
                label: LoginScrCopy.emailLabel,
                placeholder: LoginScrCopy.emailPlaceholder,
                icon: "envelope",
                keyboard: .emailAddress,
                whiteBorder: true
            ),
            text: $email,
            onEdit: { errorMessage = nil }
        )
    }

    var recoveryCodeField: some View {
        LoginScrField(
            props: LoginScrFieldProps(
                label: LoginScrCopy.recoveryCodeLabel,
                placeholder: AcctSecRecoveryCodePolicy.placeholder,
                icon: "key",
                autocapitalization: .characters
            ),
            text: $recoveryCode,
            onEdit: { errorMessage = nil }
        )
    }

    var passwordField: some View {
        LoginScrField(
            props: LoginScrFieldProps(
                label: passwordLabel,
                placeholder: passwordPlaceholder,
                icon: "key",
                isSecure: !showPassword,
                whiteBorder: true,
                trailing: AnyView(LoginScrRevealToggle(isRevealed: $showPassword))
            ),
            text: $password,
            onEdit: { errorMessage = nil }
        )
    }

    var confirmField: some View {
        LoginScrField(
            props: LoginScrFieldProps(
                label: LoginScrCopy.confirmLabel,
                placeholder: LoginScrCopy.confirmPlaceholder,
                icon: "checkmark.shield",
                isSecure: !showPassword
            ),
            text: $passwordConfirmation,
            onEdit: { errorMessage = nil }
        )
    }

    var passwordLabel: String {
        if isResetting { return LoginScrCopy.newPasswordLabel }
        if isAdminActivation { return LoginScrCopy.adminNewPasswordLabel }
        return LoginScrCopy.passwordLabel
    }

    var passwordPlaceholder: String {
        isResetting || isAdminActivation
            ? LoginScrCopy.newPasswordPlaceholder
            : LoginScrCopy.passwordPlaceholder
    }

    /// Pied de page : « Se connecter » aux identifiants, « Continuer » sur
    /// l'adresse dès la première frappe.
    @ViewBuilder var footer: some View {
        if step == .credentials {
            footerButton(title: submitTitle, enabled: !isAuthenticating) { submit() }
        } else if hasStartedEmail {
            footerButton(title: LoginScrCopy.continueTitle, enabled: true) { continueWithEmail() }
        }
    }

    func footerButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        LoginScrFooterPrimary(title: title, enabled: enabled, action: action)
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 10)
    }

    /// `biometricAlert != nil` ⇔ alerte « Biométrie indisponible » présentée.
    var biometricAlertPresented: Binding<Bool> {
        Binding(
            get: { biometricAlert != nil },
            set: { presented in if !presented { biometricAlert = nil } }
        )
    }

    /// Remise du nouveau code de secours (`RecoveryCodeModal` de la source,
    /// déjà porté par `AcctSecRecoveryCodeView`). L'accusé de réception ouvre
    /// ensuite le compte retenu, comme la source.
    @ViewBuilder var recoveryOverlay: some View {
        if let issued {
            ZStack {
                Color(hex: 0x0A0D0C).opacity(0.45).ignoresSafeArea()
                AcctSecRecoveryCodeView(code: issued.code) {
                    self.issued = nil
                    Task { @MainActor in
                        try? await props.onLogin(issued.account, nil)
                    }
                }
            }
        }
    }
}
