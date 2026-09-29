//
//  OnbUiFields.swift
//  Duello
//
//  Champs et récapitulatifs de formulaire de l'inscription.
//  Porté de `src/screens/OnboardingScreen.tsx` :
//    - plage 95-163 : `OnboardingCredentials`, `OnboardingScreenProps`
//    - plage 1494-1703 : `FieldProps`, `ProviderAccountSummary`, `Field`
//
//  Préfixe réservé du lot : `OnbUi`. Aucune dépendance externe. iOS 16.
//  Réutilise `DuelloTextField` / `DuelloPrimaryButton` (kit partagé), `Theme`,
//  `UserProfile`, `GoogleIdentity`, `AppleAuthIdentity`, `PlanScheduleSlot`.
//  Ne redéfinit aucun type existant.
//
//  V2 (29/09/2026, parité RN dev) : `OnbUiFieldProps.autoFocus` porte
//  `onboardingAutofocusFields` (`OnboardingScreen.tsx:353-354`) ; les appels
//  école/pseudo/e-mail/mot de passe (`OnbFlowStepContent.swift`) posent
//  `autoFocus: true`. `OnbUiField` accepte en outre un focus **externe**
//  (`externalFocus` / `focusTarget`) pour le recentrage du champ pseudo/e-mail
//  après fermeture d'une alerte (`focusPseudoInput` / `focusEmailInput`,
//  `OnboardingScreen.tsx:691-696`) ; le `@FocusState` vit dans `OnbFlowView`.
//

import SwiftUI
import UIKit

/// `OnboardingCredentials` — identifiants collectés à l'étape « credentials ».
struct OnbUiCredentials {
    var password: String = ""
    var biometricEnabled: Bool = false
    var pushNotificationsEnabled: Bool = false
    var googleIdentity: GoogleIdentity? = nil
    /// Source : `AppleIdentity` ; équivalent Swift : `AppleAuthIdentity`.
    var appleIdentity: AppleAuthIdentity? = nil
    /// Session serveur déjà validée par le fournisseur, remise à la complétion.
    ///
    /// Absente de la source, qui laisse l'application ouvrir le compte pendant
    /// le parcours (`onGoogleAuthenticated` → `authenticateWithGoogle`,
    /// `App.tsx`). Ici le bouton rend la session avec l'identité ; elle est
    /// mémorisée puis posée d'un seul geste à la fin, pour que l'inscription
    /// n'ouvre la session qu'une fois le parcours terminé.
    var providerSession: DuelloAPI.SessionPayload? = nil
}

/// `OnboardingScreenProps` — entrées et rappels de l'écran d'inscription.
///
/// Le `Promise<() => void>` de `onComplete` est rendu par une closure `async`
/// qui renvoie la fonction d'annulation à exécuter après succès.
/// Le `ClassSlot` de la source correspond à `PlanScheduleSlot` côté Swift
/// (déjà porté par le lot planning).
struct OnbUiScreenProps {
    var initialProfile: UserProfile
    var mode: OnbDataSteps.Mode = .account
    var initialGoogleIdentity: GoogleIdentity? = nil
    var initialAppleIdentity: AppleAuthIdentity? = nil

    var onComplete: (UserProfile, [PlanScheduleSlot], OnbUiCredentials) async -> (() -> Void)
    var onProgramSelected: (UserProfile) async -> Void
    var onTrainingSurfaceReady: () -> Void
    var onGoogleAuthenticated: (GoogleIdentity) async -> Void
    var onAppleAuthenticated: (AppleAuthIdentity) async -> Void
    var onCancel: (() -> Void)? = nil
}

/// Clavier demandé par un champ (`FieldProps.keyboardType`).
enum OnbUiFieldKeyboard {
    case `default`
    case emailAddress
    case numbersAndPunctuation
    case decimalPad
    case numberPad

    /// Équivalent `UIKeyboardType`.
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .default: return .default
        case .emailAddress: return .emailAddress
        case .numbersAndPunctuation: return .numbersAndPunctuation
        case .decimalPad: return .decimalPad
        case .numberPad: return .numberPad
        }
    }
}

/// Mise en majuscules automatique (`FieldProps.autoCapitalize`).
enum OnbUiFieldCapitalization {
    case none
    case sentences
    case words
    case characters

    /// Équivalent `TextInputAutocapitalization` (iOS 15+).
    var textInputAutocapitalization: TextInputAutocapitalization {
        switch self {
        case .none: return .never
        case .sentences: return .sentences
        case .words: return .words
        case .characters: return .characters
        }
    }
}

/// `FieldProps` — configuration d'un champ de l'inscription.
///
/// `trailing` (un `React.ReactNode` dans la source) ne peut pas vivre dans une
/// structure de valeur : il est exposé comme paramètre de vue de `OnbUiField`.
struct OnbUiFieldProps {
    /// Omis quand le bandeau de l'étape dit déjà ce qui est demandé.
    var label: String? = nil
    var value: String
    var onChangeText: (String) -> Void
    var placeholder: String
    /// Nom de SF Symbol (la source reçoit une icône Ionicons).
    var icon: String? = nil
    var multiline: Bool = false
    var keyboardType: OnbUiFieldKeyboard = .default
    var isSecure: Bool = false
    var autoCapitalize: OnbUiFieldCapitalization = .none
    var onFocus: (() -> Void)? = nil
    var onBlur: (() -> Void)? = nil
    var dark: Bool = false
    var whiteBorder: Bool = false
    /// `autoFocus` de `Field` : le champ prend le focus à l'apparition
    /// (`onboardingAutofocusFields`, vrai sur mobile et ordinateur téléchargé).
    var autoFocus: Bool = false
}

/// `Field` — champ de formulaire avec légende optionnelle, icône, bordure
/// blanche et variante multiligne.
struct OnbUiField<Trailing: View>: View {
    var props: OnbUiFieldProps
    /// Focus externe partagé (`OnbFlowView`) : quand il est fourni, le champ s'y
    /// rattache pour se recentrer après fermeture d'une alerte
    /// (`focusPseudoInput` / `focusEmailInput`, `OnboardingScreen.tsx:691-696`).
    /// `nil` sur les champs sans recentrage (école, mot de passe) : ils gardent
    /// leur focus interne (`autoFocus`).
    var externalFocus: FocusState<OnbFlowAlertAction.FocusTarget?>.Binding? = nil
    /// Cible portée par `externalFocus` (`pseudo` / `email`).
    var focusTarget: OnbFlowAlertAction.FocusTarget? = nil
    private let trailing: () -> Trailing

    @FocusState private var focused: Bool

    init(
        props: OnbUiFieldProps,
        externalFocus: FocusState<OnbFlowAlertAction.FocusTarget?>.Binding? = nil,
        focusTarget: OnbFlowAlertAction.FocusTarget? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.props = props
        self.externalFocus = externalFocus
        self.focusTarget = focusTarget
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = props.label {
                Text(label)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(props.dark ? Color.white : Theme.ink)
            }

            HStack(alignment: props.multiline ? .top : .center, spacing: 10) {
                if let icon = props.icon {
                    // `Ionicons name={icon} size={20}` (source, `Field`) : le
                    // glyphe est rendu tel quel, pas un substitut SF Symbol.
                    IonIcon(
                        name: icon,
                        size: 20,
                        color: props.dark ? Color(white: 0.72) : Theme.inkSoft
                    )
                }
                inputField
                trailing()
            }
            .padding(.horizontal, 15)
            .padding(.top, props.multiline ? 16 : 0)
            .frame(
                minHeight: props.multiline ? 98 : 55,
                alignment: props.multiline ? .topLeading : .center
            )
            .background(props.dark ? Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255) : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(borderColor, lineWidth: 1.5)
            )
        }
        .onAppear { if props.autoFocus { requestFocus() } }
    }

    /// Donne le focus à l'apparition : au champ externe s'il est partagé
    /// (recentrage), sinon au focus interne (`autoFocus`).
    private func requestFocus() {
        if let externalFocus, let focusTarget {
            externalFocus.wrappedValue = focusTarget
        } else {
            focused = true
        }
    }

    /// Couleur de bordure : bord blanc forcé, sinon bord invité, sinon bord
    /// clair. La source applique `whiteFieldBorder` **après** `guestFieldShell`
    /// (`OnboardingScreen.tsx:1730-1734`) : le blanc l'emporte sur le sombre.
    private var borderColor: Color {
        if props.whiteBorder { return .white }
        if props.dark { return Color(red: 0x3A / 255, green: 0x3A / 255, blue: 0x3A / 255) }
        return Theme.border
    }

    /// Saisie, sûre ou libre ; multiligne via `axis: .vertical` (iOS 16).
    ///
    /// Limite documentée : la couleur du texte d'invite
    /// (`placeholderTextColor` de la source) n'est pas personnalisable avec
    /// `TextField` en SwiftUI — l'invite prend la teinte par défaut du système.
    @ViewBuilder
    private var inputField: some View {
        let text = Binding(get: { props.value }, set: props.onChangeText)
        if props.isSecure {
            applyFocus(
                SecureField(props.placeholder, text: text)
                    .textContentType(.password)
                    .modifier(OnbUiFieldTextStyle(dark: props.dark))
            )
        } else {
            applyFocus(
                TextField(props.placeholder, text: text, axis: props.multiline ? .vertical : .horizontal)
                    .keyboardType(props.keyboardType.uiKeyboardType)
                    .textInputAutocapitalization(props.autoCapitalize.textInputAutocapitalization)
                    .autocorrectionDisabled()
                    .modifier(OnbUiFieldTextStyle(dark: props.dark))
            )
        }
    }

    /// Rattache la saisie au focus externe (recentrage) quand il est fourni,
    /// sinon au focus interne (`autoFocus`).
    @ViewBuilder
    private func applyFocus<Content: View>(_ content: Content) -> some View {
        if let externalFocus, let focusTarget {
            content.focused(externalFocus, equals: focusTarget)
        } else {
            content.focused($focused)
        }
    }
}

/// Typographie commune aux saisies du champ (`input` / `guestInput`).
private struct OnbUiFieldTextStyle: ViewModifier {
    let dark: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(dark ? Color.white : Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `ProviderAccountSummary` — carte « Compte {Google|Apple} vérifié ».
struct OnbUiProviderAccountSummary: View {
    /// Fournisseur dont le compte est confirmé.
    enum Provider: String {
        case google = "Google"
        case apple = "Apple"
    }

    let email: String
    let provider: Provider
    var dark: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(dark ? Color.white : Theme.progress)
                // `checkmark`, 21 (source, `ProviderAccountSummary`).
                IonIcon(name: "checkmark", size: 21, color: dark ? Color.black : Color.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Compte \(provider.rawValue) vérifié")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(dark ? Color.white : Theme.ink)
                Text(email)
                    .font(.system(size: 12))
                    .foregroundStyle(dark ? Color(white: 0.72) : Theme.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .frame(minHeight: 64)
        .background(dark ? Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255) : Theme.progressLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(
                    dark ? Color(red: 0x3A / 255, green: 0x3A / 255, blue: 0x3A / 255) : Theme.progress,
                    lineWidth: 1.5
                )
        )
        .accessibilityElement(children: .combine)
    }
}
