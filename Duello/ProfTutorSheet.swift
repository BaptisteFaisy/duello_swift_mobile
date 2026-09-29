//
//  ProfTutorSheet.swift
//  Duello
//
//  Port de `src/components/prof-tutor/ProfTutorSheet.tsx` (RN) — Prof IA en
//  bottom-sheet mobile : hauteur réglable au doigt sur la poignée, clavier
//  évité (`KeyboardAvoidingView`).
//
//  L'écran parent pose la demande (`quote` + contexte, ou photo) et la retire à
//  la fermeture ; la session (streaming puis questions) vit dans
//  `ProfTutorSession`. La ligne de séparation règle la hauteur au doigt, entre
//  deux butées, avec aimantation au relâcher ; glissée trop bas, elle referme le
//  panneau. Le chevron de l'en-tête ouvre la fiche du prof (`onOpenProfile`).
//
//  Approché (24/09/2026) :
//    - la poignée `PanResponder` devient un `DragGesture` qui pilote un unique
//      `PresentationDetent` `.fraction(sheetRatio)` (butées et aimantation
//      inchangées, cf. `ProfSheetHeight`) ;
//    - `KeyboardAvoidingView` (`behavior: "padding"`) devient un observateur des
//      notifications clavier qui retranche la hauteur du clavier en bas du
//      panneau (noms de notification en clair : `UIKeyboard…` n'existe pas au
//      vérificateur Linux, même approche que `DictAppStateGate`) ;
//    - le `Modal animationType="slide"` devient la présentation `.sheet`
//      (glissement système), la hauteur `%` un `PresentationDetent` fractionnaire.
//
//  Discussion libre (2026-09-29) : `syncRequest` branche `openBlank` quand le
//  passage est vide sans photo, et le panneau reçoit `chatMode` (cf.
//  `useProfTutor.ts:59-68,152-157`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI
import UIKit

/// `ProfTutorSheet` : bottom-sheet du prof IA, hauteur réglable à la poignée.
struct ProfTutorSheet: View {
    /// Demande de l'écran parent ; `nil` ferme la session.
    let request: ProfTutorRequest?
    /// Jeton de session Duello, posé depuis `SessionStore`.
    let token: String?
    /// Fourni : le chevron de l'en-tête ouvre la fiche du prof IA.
    var onOpenProfile: ((String) -> Void)? = nil
    let onClose: () -> Void

    @StateObject private var tutor = ProfTutorSession()
    @State private var sheetRatio: CGFloat = PROF_SHEET_DEFAULT_RATIO
    @State private var dragOrigin: CGFloat = PROF_SHEET_DEFAULT_RATIO
    /// Hauteur pleine de la fenêtre, figée au début du geste.
    @State private var dragFullHeight: CGFloat = 0
    /// Hauteur mesurée du panneau présenté, déduite en hauteur pleine.
    @State private var containerHeight: CGFloat = 0
    @State private var isDragging = false
    @State private var openedRequest: UUID?
    /// `KeyboardAvoidingView behavior="padding"` : hauteur du clavier à retrancher.
    @State private var keyboardInset: CGFloat = 0
    @State private var keyboardObservers: [NSObjectProtocol] = []

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                grip
                panel
            }
            .background(Theme.surface)
            .padding(.bottom, keyboardInset)
            .onAppear { containerHeight = proxy.size.height }
            .onChange(of: proxy.size.height) { containerHeight = $0 }
        }
        // Le clavier ne déplace pas le panneau par le système : notre `padding`
        // est le seul mécanisme, comme `behavior: "padding"` de la source.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .presentationDetents([.fraction(sheetRatio)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            tutor.token = token
            observeKeyboard()
            syncRequest()
        }
        .onDisappear { stopObservingKeyboard() }
        .onChange(of: token) { newValue in tutor.token = newValue }
        .onChange(of: request) { _ in syncRequest() }
    }

    /// Le panneau du prof IA, alimenté par la session.
    ///
    /// `chatMode` : discussion libre (ni photo ni passage) — la source ouvre
    /// alors la saisie sans explication préalable
    /// (`ProfTutorSheet.tsx:88-92`, `ProfTutorPanel.tsx:29`).
    private var panel: some View {
        ProfTutorPanel(
            imageUri: tutor.request?.imageUri,
            context: tutor.request?.context ?? .fallback,
            messages: tutor.messages,
            streamingText: tutor.streamingText,
            streaming: tutor.status == .streaming,
            suggestions: tutor.status == .ready ? tutor.suggestions : [],
            error: tutor.status == .error ? tutor.error : "",
            onSend: tutor.send,
            chatMode: tutor.request?.image == nil && (tutor.request?.quote.isEmpty ?? false),
            onOpenProfile: panelOpenProfile,
            onClose: onClose
        )
    }

    /// `onOpenProfile(PROF_IA_PROFILE_ID)` : la fiche ouverte est celle du prof.
    private var panelOpenProfile: (() -> Void)? {
        guard let onOpenProfile else { return nil }
        return { onOpenProfile(PROF_IA_PROFILE_ID) }
    }

    // MARK: Poignée

    /// Ligne fine pleine largeur (hauteur 2) dans une zone de prise de 24,
    /// comme la ligne de séparation du champ de réponse de l'énoncé.
    private var grip: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityElement()
            .accessibilityLabel("Redimensionner le panneau du prof")
            .accessibilityAdjustableAction { direction in
                nudgeSheet(direction == .decrement ? -1 : 1)
            }
    }

    /// `gripResponder` : glisser vertical → butées ; relâcher → aimantation ou
    /// fermeture. La hauteur pleine est figée au début du geste, pour que le
    /// redimensionnement du panneau n'influe pas sur la conversion.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragOrigin = sheetRatio
                    dragFullHeight = sheetRatio > 0 ? containerHeight / sheetRatio : 0
                }
                guard dragFullHeight > 0 else { return }
                sheetRatio = clampProfSheetRatio(
                    dragOrigin - value.translation.height / dragFullHeight
                )
            }
            .onEnded { value in
                isDragging = false
                let released = dragFullHeight > 0
                    ? dragOrigin - value.translation.height / dragFullHeight
                    : sheetRatio
                if shouldCloseProfSheetOnRelease(released) {
                    onClose()
                    return
                }
                sheetRatio = snapProfSheetRatio(released)
            }
    }

    /// `nudgeSheet` : pas d'un dixième, aimanté (action d'accessibilité).
    private func nudgeSheet(_ step: Int) {
        sheetRatio = snapProfSheetRatio(sheetRatio + CGFloat(step) * 0.1)
    }

    // MARK: Clavier

    /// `KeyboardAvoidingView` : retranche la hauteur du clavier en bas du
    /// panneau, avec la durée d'animation annoncée par le système.
    private func observeKeyboard() {
        guard keyboardObservers.isEmpty else { return }
        let centre = NotificationCenter.default
        let show = centre.addObserver(
            forName: Notification.Name("UIKeyboardWillShowNotification"),
            object: nil,
            queue: .main
        ) { note in
            let frame = (note.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect) ?? .zero
            let duration = (note.userInfo?["UIKeyboardAnimationDurationUserInfoKey"] as? Double) ?? 0.25
            Task { @MainActor in
                withAnimation(.easeOut(duration: duration)) { keyboardInset = frame.height }
            }
        }
        let hide = centre.addObserver(
            forName: Notification.Name("UIKeyboardWillHideNotification"),
            object: nil,
            queue: .main
        ) { note in
            let duration = (note.userInfo?["UIKeyboardAnimationDurationUserInfoKey"] as? Double) ?? 0.25
            Task { @MainActor in
                withAnimation(.easeOut(duration: duration)) { keyboardInset = 0 }
            }
        }
        keyboardObservers = [show, hide]
    }

    private func stopObservingKeyboard() {
        let centre = NotificationCenter.default
        for observer in keyboardObservers { centre.removeObserver(observer) }
        keyboardObservers = []
    }

    // MARK: Demande

    /// `useEffect` de la source : ouvre à la demande posée (texte ou photo),
    /// ferme à son retrait.
    private func syncRequest() {
        guard let request else {
            if openedRequest != nil {
                openedRequest = nil
                tutor.close()
            }
            return
        }
        guard openedRequest != request.id else { return }
        openedRequest = request.id
        sheetRatio = PROF_SHEET_DEFAULT_RATIO
        if let image = request.image, let mimeType = request.mimeType {
            tutor.openImage(image: image, mimeType: mimeType, context: request.context)
        } else if !request.quote.isEmpty {
            tutor.open(quote: request.quote, context: request.context)
        } else {
            // Discussion libre (`request.quote` vide, sans photo) : la source
            // appelle `openBlank` (`ProfTutorSheet.tsx:88-92`).
            tutor.openBlank(context: request.context)
        }
    }
}
