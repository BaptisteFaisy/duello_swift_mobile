import SwiftUI

// Formulaire de réinitialisation de mot de passe — porté depuis
// `src/components/PasswordResetForm.tsx`, `src/screens/PasswordResetScreen.tsx`,
// `src/hooks/usePasswordResetForm.ts`, `src/utils/passwordResetApi.ts`,
// `passwordResetHttp.ts`, `passwordResetLink.ts` et `passwordResetIdentity.ts`.
//
// Les trois étapes de la source (demande de lien → saisie du code → nouveau mot
// de passe) sont réunies dans une seule vue. Les appels réseau passent par
// `DuelloAPI` et un helper local : `DuelloAPI.swift` n'est pas modifié. La
// session renvoyée est remise à l'appelant (`onAuthenticated`) pour qu'il la
// confie à `SessionStore`.

/// Destination du lien de réinitialisation (voir `PasswordResetDestination`
/// de `passwordResetApi.ts`).
enum AcctSecResetDestination: String, Codable, Equatable {
    case app
    case web
}

/// Étape courante du parcours de réinitialisation.
enum AcctSecPasswordResetStep: Equatable {
    case request
    case code
    case password
}

/// Formulaire en trois étapes : demande, code, nouveau mot de passe.
struct AcctSecPasswordResetForm: View {
    /// Adresse préremplie ; si non vide, le parcours démarre à l'étape « code ».
    var email: String = ""
    /// Destination du lien de réinitialisation.
    var destination: AcctSecResetDestination = .app
    /// Remise de la session serveur pour la confier à `SessionStore`.
    var onAuthenticated: ((ServerSession) -> Void)? = nil

    @State private var step: AcctSecPasswordResetStep = .request
    @State private var address = ""
    @State private var code = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var notice = ""
    @State private var saving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                stepContent
                if !notice.isEmpty { noticeCard }
                if !errorMessage.isEmpty { errorCard }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .task { prime() }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .black))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
            Text(headline)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var eyebrow: String {
        switch step {
        case .request: return "Mot de passe oublié"
        case .code: return "Code de secours"
        case .password: return "Nouveau mot de passe"
        }
    }

    private var headline: String {
        switch step {
        case .request: return "Retrouve l’accès à ton compte"
        case .code: return "Saisis le code de récupération"
        case .password: return "Choisis ton nouveau mot de passe"
        }
    }

    // MARK: Étapes

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .request: requestStep
        case .code: codeStep
        case .password: passwordStep
        }
    }

    private var requestStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Indique l’adresse e-mail de ton compte. Tu recevras un lien sécurisé pour choisir un nouveau mot de passe.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            DuelloTextField(
                title: "Adresse e-mail",
                text: $address,
                textContentType: .emailAddress,
                keyboard: .emailAddress
            )
            Button {
                Task { await submitRequest() }
            } label: {
                Text(saving ? "Envoi…" : "Envoyer le lien")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(saving)
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            emailCard
            Text("Saisis le code reçu par e-mail, ou ton code de secours administrateur.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            DuelloTextField(title: "Code de secours", text: $code)
            Button {
                submitCode()
            } label: {
                Text("Continuer")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(DuelloPrimaryButton())
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            emailCard
            DuelloTextField(
                title: "Nouveau mot de passe",
                text: $password,
                isSecure: !showPassword,
                textContentType: .newPassword
            )
            visibilityButton
            DuelloTextField(
                title: "Confirme le mot de passe",
                text: $confirmation,
                isSecure: !showPassword,
                textContentType: .newPassword
            )
            Button {
                Task { await submitPassword() }
            } label: {
                Text(saving ? "Enregistrement…" : "Enregistrer")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(saving)
        }
    }

    // MARK: Cartes

    private var emailCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adresse e-mail")
                .font(.system(size: 12, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            Text(address)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var visibilityButton: some View {
        Button {
            showPassword.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 12, weight: .bold))
                Text(showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe")
                    .font(.system(size: 12, weight: .heavy))
            }
            .foregroundStyle(Theme.inkSoft)
        }
        .buttonStyle(.plain)
    }

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.like)
            Text(errorMessage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var noticeCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.progress)
            Text(notice)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    // MARK: Actions

    private func prime() {
        guard address.isEmpty, !email.isEmpty else { return }
        address = email
        step = .code
    }

    private func submitRequest() async {
        let normalized = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isPlausibleEmail(normalized) else {
            errorMessage = "Saisis une adresse e-mail valide."
            return
        }
        errorMessage = ""
        notice = ""
        saving = true
        defer { saving = false }
        do {
            try await sendResetRequest(normalized)
            address = normalized
            notice = "Si un compte correspond à cette adresse, tu recevras un e-mail dans quelques instants. Le lien restera valable 30 minutes."
            step = .code
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitCode() {
        let normalized = AcctSecRecoveryCodePolicy.normalize(code)
        guard !normalized.isEmpty else {
            errorMessage = "Saisis le code reçu par e-mail ou ton code de secours."
            return
        }
        errorMessage = ""
        notice = ""
        code = normalized
        step = .password
    }

    private func submitPassword() async {
        guard password.count >= 8, password.count <= 128 else {
            errorMessage = AcctSecRecoveryCodePolicy.passwordPolicyMessage
            return
        }
        guard password == confirmation else {
            errorMessage = "Les deux mots de passe ne correspondent pas."
            return
        }
        errorMessage = ""
        saving = true
        defer { saving = false }
        do {
            let session = try await sendReset(address, token: code, password: password)
            onAuthenticated?(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isPlausibleEmail(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 320 else { return false }
        guard !value.contains(where: { $0.isWhitespace }) else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.firstIndex(of: ".") else { return false }
        let afterDot = domain.index(after: dot)
        return dot != domain.startIndex && afterDot < domain.endIndex
    }

    // MARK: Réseau (helpers locaux, `DuelloAPI.swift` inchangé)

    private func sendResetRequest(_ email: String) async throws {
        let body = try DuelloAPI.encodeBody([
            "email": email,
            "destination": destination.rawValue,
        ])
        let data = try await DuelloAPI.request(
            "auth/password/reset-request",
            method: "POST",
            body: body
        )
        let payload = try? DuelloAPI.decoder.decode(AcctSecResetRequestResponse.self, from: data)
        guard payload?.accepted == true else {
            throw DirectoryError(message: "La réponse du service de mot de passe est invalide.")
        }
    }

    private func sendReset(_ email: String, token: String, password: String) async throws -> ServerSession {
        let body = try DuelloAPI.encodeBody([
            "email": email,
            "token": token,
            "password": password,
        ])
        let data = try await DuelloAPI.request(
            "auth/password/reset",
            method: "POST",
            body: body
        )
        let payload = try? DuelloAPI.decoder.decode(AcctSecResetResponse.self, from: data)
        guard let session = payload?.session else {
            throw DirectoryError(
                message: "Le mot de passe a changé, mais la nouvelle session Duello est inutilisable."
            )
        }
        return session
    }
}

/// Réponse de `POST /auth/password/reset-request` (voir `PasswordResetResponse`).
private struct AcctSecResetRequestResponse: Decodable {
    var accepted: Bool?
}

/// Réponse de `POST /auth/password/reset` : la session ouverte après le
/// changement de mot de passe, ou `null` si l'identité ne correspond pas.
private struct AcctSecResetResponse: Decodable {
    var accepted: Bool?
    var session: ServerSession?
}
