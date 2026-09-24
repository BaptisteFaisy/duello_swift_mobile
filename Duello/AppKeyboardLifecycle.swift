//
//  AppKeyboardLifecycle.swift
//  Duello
//
//  Port de src/utils/appKeyboardLifecycle.ts +
//  src/hooks/useDismissKeyboardOnAppBackground.ts (RN) — retrait du focus
//  clavier quand l'application quitte le premier plan.
//
//  Les écrans et leur saisie restent montés. Le second passage au retour couvre
//  aussi les plateformes qui restaurent le focus de la vue native à la reprise.
//
//  Réductions assumées (iOS), notées le 24/09/2026 :
//    - `AppStateStatus` de React Native est réduit à `AppKeyboardLifecycleState`
//      (`active` / `inactive` / `background` / `unknown`), alimenté par le
//      `ScenePhase` SwiftUI. `unknown` couvre l'état de lancement non résolu.
//    - `Keyboard.dismiss()` est rendu par le retrait du premier répondant
//      (`resignFirstResponder`), qui referme le clavier quel que soit le champ
//      actif. Le hook React est remplacé par un `ViewModifier` : l'application
//      l'appose sur la vue racine (cf. wiring/U13.md).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI
import UIKit

/// `AppStateStatus` de React Native, réduit aux états observables sur iOS.
enum AppKeyboardLifecycleState: Equatable {
    case active
    case inactive
    case background
    case unknown
}

/// `shouldDismissKeyboardForAppStateTransition` (`utils/appKeyboardLifecycle.ts`).
enum AppKeyboardLifecycle {
    /// Une frontière entre premier plan et arrière-plan invalide le focus natif.
    /// Le premier passage de l'état de lancement `unknown` à `active` est exclu
    /// (`hasEnteredForeground == false`) : il ne doit pas annuler l'auto-focus
    /// légitime d'un écran qui vient de monter.
    static func shouldDismissKeyboardForAppStateTransition(
        previousState: AppKeyboardLifecycleState,
        nextState: AppKeyboardLifecycleState,
        hasEnteredForeground: Bool
    ) -> Bool {
        if !hasEnteredForeground || previousState == nextState { return false }
        return previousState == .active || nextState == .active
    }

    /// `Keyboard.dismiss()` : retire le focus du premier répondant, ce qui
    /// referme le clavier sans démonter les écrans.
    @MainActor
    static func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #else
        // Hors iOS (contrôle de types Linux) : pas de premier répondant UIKit à
        // retirer ; le repli reste inerte.
        #endif
    }
}

extension AppKeyboardLifecycleState {
    /// Traduction d'un `ScenePhase` SwiftUI vers l'état équivalent.
    init(_ phase: ScenePhase) {
        switch phase {
        case .active: self = .active
        case .inactive: self = .inactive
        case .background: self = .background
        @unknown default: self = .unknown
        }
    }
}

/// `useDismissKeyboardOnAppBackground` : retire le focus natif des champs quand
/// l'application quitte le premier plan, et au retour pour un focus restauré par
/// le système. Les écrans restent montés.
struct DismissKeyboardOnAppBackground: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentState: AppKeyboardLifecycleState = .unknown
    @State private var hasEnteredForeground = false

    func body(content: Content) -> some View {
        content
            // `AppState.currentState` initial de la source : synchronisé une fois
            // à l'apparition, sans retirer de focus.
            .onAppear { syncInitial() }
            .onChange(of: scenePhase) { phase in handle(phase) }
    }

    /// Initialise l'état courant comme la source (`AppState.currentState`) :
    /// `hasEnteredForeground` vaut vrai si l'app démarre au premier plan.
    private func syncInitial() {
        let state = AppKeyboardLifecycleState(scenePhase)
        currentState = state
        hasEnteredForeground = (state == .active)
    }

    /// Équivalent du listener `AppState.addEventListener('change', …)`.
    private func handle(_ phase: ScenePhase) {
        let next = AppKeyboardLifecycleState(phase)
        let shouldDismiss = AppKeyboardLifecycle.shouldDismissKeyboardForAppStateTransition(
            previousState: currentState,
            nextState: next,
            hasEnteredForeground: hasEnteredForeground
        )
        currentState = next
        if next == .active { hasEnteredForeground = true }
        if shouldDismiss { Task { @MainActor in AppKeyboardLifecycle.dismissKeyboard() } }
    }
}

extension View {
    /// Appose le retrait du focus clavier en arrière-plan
    /// (`useDismissKeyboardOnAppBackground`).
    func dismissKeyboardOnAppBackground() -> some View {
        modifier(DismissKeyboardOnAppBackground())
    }
}
