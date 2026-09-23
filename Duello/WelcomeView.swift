import SwiftUI
import UIKit

/// Écran d'accueil : fond noir, logo centré, deux boutons blancs.
/// Reprend `src/screens/WelcomeScreen.tsx`.
struct WelcomeView: View {
    @EnvironmentObject private var session: SessionStore
    /// `onCreateAccount` de `WelcomeScreen.tsx` : ouvre le parcours
    /// d'inscription, qui se joue **hors** de la feuille de connexion
    /// (`authStage === 'signup'`).
    var onCreateAccount: () -> Void = {}
    /// Mode capture : la feuille de connexion peut s'ouvrir d'elle-même.
    @State private var showLogin = ScreenshotTour.welcomeDestination == .login

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
                            onCreateAccount()
                        } label: {
                            Text("Créer un compte")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(DuelloWelcomeButton())

                        Button {
                            showLogin = true
                        } label: {
                            Text("Me connecter")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(DuelloWelcomeButton())
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

/// Connexion Google : variante « onboarding-field » de l'app Expo
/// (`GoogleAuthButton.native.tsx`) — bouton sombre bordé de blanc, logo G,
/// libellé échangé contre « Connexion à Google… » pendant l'échange serveur.
///
/// Libellé « Continuer avec Google » : c'est celui de la variante
/// `onboarding-field` (`buttonLabel`, `GoogleAuthButton.native.tsx:105-109`),
/// la seule qu'emploie l'écran de connexion (`LoginScreen.tsx`, étape
/// « identité ») — seul appelant depuis que l'accueil n'a plus que ses deux
/// boutons.
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
                HStack(spacing: Theme.providerFieldSpacing) {
                    GoogleGLogo()
                        .frame(width: Theme.providerLogoSize, height: Theme.providerLogoSize)
                    Text(isLoading ? "Connexion à Google…" : "Continuer avec Google")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: Theme.providerFieldMinHeight)
            }
            .buttonStyle(GoogleFieldButtonStyle(appearance: appearance, isDimmed: isLoading))
            .disabled(isLoading)
            .accessibilityLabel("Continuer avec Google")

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(appearance == .dark ? Theme.providerErrorOnDark : Theme.providerError)
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
///
/// C'est le style **commun** des deux fournisseurs de l'étape `auth-method` :
/// `GoogleAuthButton` et `AppleAuthView` le partagent, donc les deux boutons
/// d'une même paire ne peuvent pas diverger. Les cotes qu'il ne porte pas
/// (hauteur, écart, logo) vivent dans `Theme.providerField*`.
struct GoogleFieldButtonStyle: ButtonStyle {
    var appearance: GoogleAuthButton.Appearance
    /// Bouton hors service : 55 %, le `styles.disabled` des deux boutons Expo.
    var isDimmed: Bool = false

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
            .opacity(restingOpacity(configuration))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }

    /// 55 % hors service, 84 % à l'appui en clair, 100 % sinon.
    private func restingOpacity(_ configuration: Configuration) -> Double {
        if isDimmed { return 0.55 }
        return configuration.isPressed && appearance == .light ? 0.84 : 1
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

/// Feuille de connexion de l'accueil.
///
/// Branche l'écran de connexion **sombre** porté au lot 14-A
/// (`LoginScrScreen`, assemblé par `LoginIntAssembly`), fidèle à
/// `src/screens/LoginScreen.tsx` : fond `#000`, texte blanc, champ à icône,
/// œil d'affichage, bordure blanche, mot de passe oublié, lien de retour,
/// bandeau d'erreur, séparateur « OU », bouton biométrie, en-tête
/// eyebrow/titre/sous-titre, fournisseurs Google/Apple.
///
/// L'inscription ne passe plus par cette feuille : la source la joue **avant**
/// toute session (`onCreateAccount` → `authStage === 'signup'` →
/// `OnboardingScreen`), elle vit donc dans `SignupFlowView`.
struct LoginView: View {
    var body: some View {
        LoginIntAssembly()
    }
}

/// Bouton encre plein, style principal de l'app.
///
/// `onDark` : variante du parcours d'inscription en thème sombre — bouton
/// blanc, texte noir (`guestContinueButton` / `guestContinueButtonText`).
struct DuelloPrimaryButton: ButtonStyle {
    var onDark: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(onDark ? Color.black : Theme.surface)
            .background(onDark ? Color.white : Theme.ink)
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
