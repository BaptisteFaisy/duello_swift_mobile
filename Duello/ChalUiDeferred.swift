//
//  ChalUiDeferred.swift
//  Duello
//
//  Lot 11-A — modales différées : replis de chargement et inventaire des surfaces
//  chargées à la demande.
//
//  Fichiers source Expo portés (libellés et mesures repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx (plage 166-226) : le bloc de
//      `lazy(() => import(…))` — `DesktopChallengeForm`, `ChallengeInviteModal`,
//      `ClassInviteModal`, `NewUserInviteModal`, `MathKeyboard`, `PaywallModal`,
//      `PhotoTranscriptionModal`, `PythonConsole`, `LeaderboardScreen` — puis
//      `DeferredInlineFallback` et `DeferredOverlayFallback` (styles
//      `deferredInlineFallback`, `deferredOverlayFallback`).
//
//  SwiftUI ne découpe pas le binaire : toutes les vues sont compilées ensemble,
//  il n'y a donc rien à charger à la demande. Le registre `ChalUiDeferredSurface`
//  conserve néanmoins la carte des surfaces différées de la source et leur
//  équivalent natif — c'est la seule partie utile ici, et elle documente quel
//  composant de la source possède une surface iOS.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Repli en ligne d'une surface différée (`DeferredInlineFallback`) : un
/// indicateur discret qui réserve la hauteur de la ligne attendue, sans
/// intercepter les touches.
struct ChalUiDeferredInlineFallback: View {
    var body: some View {
        ProgressView()
            .tint(Theme.primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.background)
            .allowsHitTesting(false)
            .accessibilityLabel("Chargement")
    }
}

/// Repli plein écran d'une surface différée (`DeferredOverlayFallback`) : voile
/// transparent, l'écran reste visible, seul l'indicateur tourne.
///
/// Le fond est transparent à dessein : un voile plein produisait un « saut
/// d'écran » visible à chaque suspension. L'appelant le pose en `.overlay`
/// (`zIndex: 100` dans la source).
struct ChalUiDeferredOverlayFallback: View {
    var body: some View {
        ZStack {
            Color.clear
            ProgressView()
                .tint(Theme.primary)
                .scaleEffect(1.4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityLabel("Chargement")
    }
}

/// Surface chargée à la demande par l'écran Défis (`lazy(() => import(…))`) et
/// son équivalent natif SwiftUI, lorsqu'il existe.
enum ChalUiDeferredSurface: String, CaseIterable {
    case desktopChallengeForm
    case challengeInvite
    case classInvite
    case newUserInvite
    case mathKeyboard
    case paywall
    case photoTranscription
    case pythonConsole
    case leaderboard

    /// Composant chargé à la demande dans la source Expo.
    var sourceComponent: String {
        switch self {
        case .desktopChallengeForm: return "DesktopChallengeForm"
        case .challengeInvite: return "ChallengeInviteModal"
        case .classInvite: return "ClassInviteModal"
        case .newUserInvite: return "NewUserInviteModal"
        case .mathKeyboard: return "MathKeyboard"
        case .paywall: return "PaywallModal"
        case .photoTranscription: return "PhotoTranscriptionModal"
        case .pythonConsole: return "PythonConsole"
        case .leaderboard: return "LeaderboardScreen"
        }
    }

    /// Fichier source Expo qui définit le composant.
    var sourceFile: String {
        switch self {
        case .desktopChallengeForm: return "src/components/DesktopChallengeForm.tsx"
        case .challengeInvite, .classInvite, .newUserInvite:
            return "src/components/ChallengeInviteModal.tsx"
        case .mathKeyboard: return "src/components/MathKeyboard.tsx"
        case .paywall: return "src/components/PaywallModal.tsx"
        case .photoTranscription: return "src/components/PhotoTranscriptionModal.tsx"
        case .pythonConsole: return "src/components/PythonConsole.tsx"
        case .leaderboard: return "src/screens/LeaderboardScreen.tsx"
        }
    }

    /// Type natif SwiftUI qui porte la surface, `nil` s'il n'existe pas encore.
    var nativeSurface: String? {
        switch self {
        case .challengeInvite: return "SocialChallengeInviteModal"
        case .mathKeyboard: return "MathKeyboardView"
        case .paywall: return "PremPaywallSheet"
        case .photoTranscription: return "PhotoTranscriptionView"
        case .pythonConsole: return "PythonConsoleView"
        case .leaderboard: return "RankingScreenTabs"
        case .desktopChallengeForm, .classInvite, .newUserInvite: return nil
        }
    }

    /// Vrai si la surface possède un équivalent natif iOS.
    var isPorted: Bool { nativeSurface != nil }

    /// Pourquoi une surface reste sans équivalent natif, quand c'est le cas.
    var missingReason: String? {
        switch self {
        case .desktopChallengeForm:
            return "Mise en page web/desktop : aucune surface iOS équivalente — le téléphone n’affiche pas ce formulaire (hors périmètre assumé du portage)."
        case .classInvite:
            return "Modale « défi de classe » non encore portée : sa définition vit hors des plages 166-410 et 3136-3262 de ce lot."
        case .newUserInvite:
            return "Modale « inviter un ami sans compte » non encore portée : sa définition vit hors des plages 166-410 et 3136-3262 de ce lot."
        default:
            return nil
        }
    }
}
