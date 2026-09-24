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
    /// Mode capture : la feuille de connexion peut s'ouvrir d'elle-même
    /// (`DUELLO_SHOT=login`) ; l'inscription, elle, passe par `onCreateAccount`.
    @State private var showLogin = ScreenshotTour.welcomeDestination == .login

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                // `ElasticScrollView` de la source : le contenu reste centré
                // quand il tient, et peut défiler sur petit écran / grande
                // taille de police.
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        Image("DuelloLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .accessibilityLabel("Marque Duello")
                            .accessibilityAddTraits(.isImage)

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
                    // `content.paddingTop: 20` de la source : le centre du
                    // logo descend de 10 pt (centre = safeTop + (hauteur −
                    // actions) / 2).
                    .padding(.top, 20)
                    .frame(minHeight: proxy.size.height)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Écran de bienvenue")
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
    /// `onGoogleAuthenticated` : quand elle est fournie, l'identité et la
    /// session sont rendues à l'appelant (arbitrage de réouverture de compte /
    /// refus administrateur) au lieu d'ouvrir la session ici — même contrat
    /// que le bouton Expo (`GoogleAuthButton.native.tsx`).
    var onAuthenticated: ((GoogleIdentity, DuelloAPI.SessionPayload) -> Void)? = nil

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

            // `status` de la source : le texte d'état s'ajoute **sous** le
            // bouton, en plus du libellé échangé dans le bouton.
            if isLoading {
                Text("Connexion à Google…")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(appearance == .dark ? Color(hex: 0xA3A3A3) : Theme.inkSoft)
            }

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
                if let onAuthenticated {
                    onAuthenticated(auth.identity, auth.session)
                } else {
                    try session.signInWithGoogle(identity: auth.identity, payload: auth.session)
                    // RootView bascule vers les onglets dès que isSignedIn change.
                }
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

/// Bouton blanc plein radius 18, libellé 15/900.
///
/// Aucun retour d'appui : la source passe ses `Pressable` par `AppPressable`,
/// qui fige `pressed` à `false` (`RESTING_PRESS_STATE`, `AppPressable.tsx:14`).
/// Le `styles.pressed` déclaré par `WelcomeScreen.tsx`/`LoginScreen.tsx`
/// (opacité 0.84 + scale 0.99) est donc **mort** et ne doit pas être porté.
struct DuelloWelcomeButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(.black)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
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
///
/// `radius` : rayon du coin, **paramétré** car il varie d'un écran à l'autre
/// (14/16/17/18). Défaut = `Theme.radiusMedium` (14, `radii.medium`), valeur
/// du CTA de compte (`AccountEmailScreen.tsx:142`, `AccountPasswordScreen`,
/// `FeedbackScreen`) — usage RN dominant.
/// `weight` : graisse du libellé, paramétrée (800/900). Défaut = `.black`
/// (900, `fontWeight: '900'` des CTA RN). Quelques écrans sont en 800.
///
/// Aucun retour d'appui : `AppPressable` fige `pressed` à `false`
/// (`AppPressable.tsx:14`) — l'opacité 0.84 + scale 0.99 qu'ajoutait ce style
/// était une divergence.
struct DuelloPrimaryButton: ButtonStyle {
    var onDark: Bool = false
    var radius: CGFloat = Theme.radiusMedium
    var weight: Font.Weight = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: weight))
            .foregroundStyle(onDark ? Color.black : Theme.surface)
            .background(onDark ? Color.white : Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

/// Champ de formulaire avec légende, comme les écrans de compte Expo.
///
/// Cotes du champ générique RN (`PasswordResetForm.tsx:136-150`, `fieldGroup`/
/// `fieldLabel`/`fieldShell`/`input`, aussi `Field` de `OnboardingScreen.tsx`) :
/// légende 13 / `.heavy` (800) / `ink` (pas de majuscules), coquille hauteur
/// min 55, rayon 14, bordure 1.5 `border`, fond `surface`, saisie 15 / regular.
struct DuelloTextField: View {
    let title: String
    @Binding var text: String
    var isSecure: Bool = false
    var textContentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    /// Texte d'invite. La source RN affiche le libellé en placeholder
    /// (`placeholder={label}`) : le passer ici pour s'en approcher.
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textContentType(textContentType)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .frame(minHeight: 55)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1.5)
            )
        }
    }
}
