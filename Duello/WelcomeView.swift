import SwiftUI
import UIKit

/// Écran d'accueil : fond noir, logo centré, deux boutons blancs.
/// Reprend `src/screens/WelcomeScreen.tsx`.
struct WelcomeView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Image("DuelloLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(96, proxy.size.width * 0.4), height: 96)
                        .accessibilityLabel("Marque Duello")

                    Spacer(minLength: 0)

                    VStack(spacing: 11) {
                        Button {
                            showRegister = true
                        } label: {
                            Text("Créer un compte")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(DuelloWelcomeButton())

                        Button {
                            showLogin = true
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Me connecter")
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(DuelloWelcomeButton())

                        GoogleAuthButton(appearance: .dark)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView(mode: .login)
        }
        .sheet(isPresented: $showRegister) {
            LoginView(mode: .register)
        }
    }
}

/// Connexion Google : variante « onboarding-field » de l'app Expo
/// (`GoogleAuthButton.native.tsx`) — bouton sombre bordé de blanc, logo G,
/// libellé échangé contre « Connexion à Google… » pendant l'échange serveur.
struct GoogleAuthButton: View {
    enum Appearance {
        case dark
        case light
    }

    var appearance: Appearance = .dark
    /// Pseudo éventuellement collecté avant l'inscription, transmis au
    /// serveur (`username`) comme dans l'Expo.
    var username: String? = nil

    @EnvironmentObject private var session: SessionStore
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 7) {
            Button {
                authenticate()
            } label: {
                HStack(spacing: 10) {
                    GoogleGLogo()
                        .frame(width: 20, height: 20)
                    Text(isLoading ? "Connexion à Google…" : "Se connecter avec Google")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 55)
            }
            .buttonStyle(GoogleFieldButtonStyle(appearance: appearance))
            .disabled(isLoading)
            .accessibilityLabel("Se connecter avec Google")

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(appearance == .dark ? Color(hex: 0xFF8A80) : Theme.like)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func authenticate() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let auth = try await GoogleAuthService.shared.authenticate(username: username)
                try session.signInWithGoogle(identity: auth.identity, payload: auth.session)
                // RootView bascule vers les onglets dès que isSignedIn change.
            } catch {
                // Une annulation volontaire n'est pas une erreur à afficher.
                errorMessage = googleAuthErrorMessage(error)
            }
            isLoading = false
        }
    }
}

/// Style du champ d'onboarding Expo : fond sombre, bordure blanche 1.5,
/// rayon 14, pressé : #1D1D1D.
struct GoogleFieldButtonStyle: ButtonStyle {
    var appearance: GoogleAuthButton.Appearance

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(appearance == .dark ? Color.white : Theme.ink)
            .background(appearance == .dark
                ? (configuration.isPressed ? Color(hex: 0x1D1D1D) : Color(hex: 0x111111))
                : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(appearance == .dark ? Color.white : Theme.border, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed && appearance == .light ? 0.84 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

/// Logo « G » de Google, tracé à l'identique des quatre arcs du SVG Expo
/// (anneau rayon 16 sur une grille 48, barre horizontale à droite).
struct GoogleGLogo: View {
    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / 48
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = 16 * scale
            let stroke = 8 * scale

            ZStack {
                arc(center: center, radius: radius, start: -47, end: 70)
                    .stroke(Color(hex: 0x4285F4), lineWidth: stroke)
                arc(center: center, radius: radius, start: 70, end: 133)
                    .stroke(Color(hex: 0x34A853), lineWidth: stroke)
                arc(center: center, radius: radius, start: 133, end: 208)
                    .stroke(Color(hex: 0xFBBC05), lineWidth: stroke)
                arc(center: center, radius: radius, start: 208, end: 313)
                    .stroke(Color(hex: 0xEA4335), lineWidth: stroke)
                Path { path in
                    path.addRect(CGRect(x: center.x, y: 20 * scale, width: 20 * scale, height: 8 * scale))
                }
                .fill(Color(hex: 0x4285F4))
            }
        }
        .accessibilityLabel("Google")
    }

    private func arc(center: CGPoint, radius: CGFloat, start: Double, end: Double) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: true
        )
        return path
    }
}

/// Bouton blanc plein radius 18, pressé : opacité 0.84 et scale 0.99.
struct DuelloWelcomeButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(.black)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .opacity(configuration.isPressed ? 0.84 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

/// Connexion ou création de compte par e-mail et mot de passe.
struct LoginView: View {
    enum Mode {
        case login
        case register

        var title: String {
            switch self {
            case .login: return "Me connecter"
            case .register: return "Créer un compte"
            }
        }
    }

    let mode: Mode

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSubmitting = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(mode.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 18)

                    if mode == .register {
                        DuelloTextField(
                            title: "Prénom ou pseudo",
                            text: $displayName,
                            textContentType: .name
                        )
                    }

                    DuelloTextField(
                        title: "Adresse e-mail",
                        text: $email,
                        textContentType: .emailAddress,
                        keyboard: .emailAddress
                    )
                    DuelloTextField(
                        title: "Mot de passe",
                        text: $password,
                        isSecure: true
                    )

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.like)
                    }

                    Button {
                        submit()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            }
                            Text(mode.title)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(DuelloPrimaryButton())
                    .disabled(isSubmitting || !canSubmit)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 22)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && (mode == .login || !displayName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func submit() {
        isSubmitting = true
        errorMessage = ""
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        let password = password
        let displayName = displayName.trimmingCharacters(in: .whitespaces)

        Task {
            defer { isSubmitting = false }
            do {
                switch mode {
                case .login:
                    try await session.signIn(email: email, password: password)
                case .register:
                    try await session.signUp(email: email, password: password, displayName: displayName)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Bouton encre plein, style principal de l'app.
struct DuelloPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(Theme.surface)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .opacity(configuration.isPressed ? 0.84 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

/// Champ de formulaire avec légende, comme les écrans de compte Expo.
struct DuelloTextField: View {
    let title: String
    @Binding var text: String
    var isSecure: Bool = false
    var textContentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .textContentType(textContentType)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(12)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}
