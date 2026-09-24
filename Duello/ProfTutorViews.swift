//
//  ProfTutorViews.swift
//  Duello
//
//  Port de `src/components/prof-tutor/ProfTutorPanel.tsx` et
//  `src/components/prof-tutor/ProfTutorSheet.tsx` (RN) — contenu du prof IA et
//  bottom-sheet mobile réglable au doigt.
//
//  Le panneau ne connaît ni le relais ni la navigation : il affiche les messages
//  et le streaming, et remonte la saisie. Le passage expliqué reste dans le
//  contexte envoyé au relais, sans répéter à l'écran ce que l'élève vient de
//  lire. La saisie reste verrouillée pendant le streaming, puis s'ouvre avec des
//  relances.
//
//  Réduit / approché (24/09/2026) :
//    - la poignée `PanResponder` de la source devient un `DragGesture` qui pilote
//      un unique `PresentationDetent` `.fraction(sheetRatio)` ; les butées,
//      l'aimantation (`snapProfSheetRatio`) et la fermeture au relâcher
//      (`shouldCloseProfSheetOnRelease`) restent ceux de `ProfSheetHeight`.
//    - `useWindowDimensions().height` est déduit de la hauteur mesurée du panneau
//      (`GeometryReader`) : la hauteur pleine se reconstitue par `hauteur / ratio`.
//    - les puces de relance, qui s'enroulaient (`flexWrap`), défilent
//      horizontalement : même contenu, disposition réduite.
//    - la bulle élève n'a plus le coin inférieur droit pincé (rayon unique).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI
import UIKit

/// `contextLabel` : exercice · question · chapitre · programme, vides omis.
func profContextLabel(_ context: ProfTutorContext) -> String {
    [context.exercise, context.question, context.chapter, context.program]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
}

// MARK: - Panneau

/// `ProfTutorPanel` : en-tête, fil de messages, barre de saisie.
struct ProfTutorPanel: View {
    let context: ProfTutorContext
    let messages: [ProfTutorMessage]
    let streamingText: String
    let streaming: Bool
    let suggestions: [String]
    let error: String
    let onSend: (String) -> Void
    let onClose: () -> Void

    @State private var draft = ""

    /// Ancre de défilement du bas de fil.
    private static let bottomAnchor = "prof-tutor-bottom"

    /// `locked` : saisie verrouillée pendant le streaming ou sans explication.
    private var locked: Bool { streaming || messages.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ProfTutorPanelHeader(context: context, onClose: onClose)
            messageList
            ProfTutorPanelChatBar(draft: $draft, locked: locked, onSend: submit)
        }
        .background(Theme.surface)
    }

    /// `submit` : envoie la saisie si elle est non vide et la saisie ouverte.
    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !locked else { return }
        draft = ""
        onSend(text)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    messageContent
                    if !error.isEmpty { ProfTutorErrorBox(text: error) }
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            .onChange(of: messages.count) { _ in scrollToBottom(proxy) }
            .onChange(of: streamingText) { _ in scrollToBottom(proxy) }
        }
    }

    /// Messages, texte en cours de rédaction, puis relances (hors erreur).
    @ViewBuilder
    private var messageContent: some View {
        ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
            ProfTutorMessageRow(message: message)
        }
        if !streamingText.isEmpty {
            ProfTutorStreamingText(text: streamingText)
        }
        if error.isEmpty && !streaming && !suggestions.isEmpty {
            ProfTutorSuggestionChips(suggestions: suggestions, onTap: onSend)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }
}

/// En-tête du panneau : avatar, nom, repère de contexte, fermeture.
private struct ProfTutorPanelHeader: View {
    let context: ProfTutorContext
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 0) {
                Text("Prof IA")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(profContextLabel(context))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            closeButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
    }

    private var avatar: some View {
        Text("π")
            .font(.system(size: 16))
            .foregroundStyle(Theme.white)
            .frame(width: 34, height: 34)
            .background(Theme.primary)
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.mastery)
                    .frame(width: 10, height: 10)
                    .overlay { Circle().stroke(Theme.surface, lineWidth: 2) }
            }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Text("✕")
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 32, height: 32)
                .background(Theme.surfaceMuted)
                .clipShape(Circle())
        }
        .accessibilityLabel("Fermer le prof IA")
    }
}

/// Un tour de conversation : bulle élève à droite, texte du prof à gauche.
private struct ProfTutorMessageRow: View {
    let message: ProfTutorMessage

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantText
        }
    }

    private var userBubble: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.white)
                .lineSpacing(8)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantText: some View {
        Text(message.text)
            .font(.system(size: 14, design: .serif))
            .foregroundStyle(Theme.ink)
            .lineSpacing(9)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Texte en cours de rédaction, suivi du curseur `▍`.
private struct ProfTutorStreamingText: View {
    let text: String

    var body: some View {
        (
            Text(text).font(.system(size: 14, design: .serif)).foregroundColor(Theme.ink)
                + Text("▍").foregroundColor(Theme.inkFaint)
        )
        .lineSpacing(9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Relances proposées après la première explication.
private struct ProfTutorSuggestionChips: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button { onTap(suggestion) } label: {
                        Text(suggestion)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay { Capsule().stroke(Theme.border, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(suggestion)
                }
            }
            .padding(.vertical, 1)
        }
    }
}

/// Encadré d'erreur du relais, sur le fond « prérequis incomplet ».
private struct ProfTutorErrorBox: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.ink)
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.prerequisitesMissingLight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
    }
}

/// Barre de saisie : champ verrouillable et bouton d'envoi.
private struct ProfTutorPanelChatBar: View {
    @Binding var draft: String
    let locked: Bool
    let onSend: () -> Void

    private var canSend: Bool {
        !locked && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            field
            sendButton
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
        .duelloShadow()
    }

    private var field: some View {
        TextField(locked ? "Le prof rédige…" : "Pose ta question de maths…", text: $draft)
            .disabled(locked)
            .font(.system(size: 14))
            .foregroundStyle(Theme.ink)
            .submitLabel(.send)
            .onSubmit(onSend)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(Theme.surfaceMuted)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(Theme.border, lineWidth: 1) }
            .opacity(locked ? 0.45 : 1)
            .accessibilityLabel("Poser une question de maths au prof IA")
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Text("↑")
                .font(.system(size: 17))
                .foregroundStyle(Theme.white)
                .frame(width: 44, height: 44)
                .background(Theme.primary)
                .clipShape(Circle())
        }
        .disabled(!canSend)
        .opacity(canSend ? 1 : 0.38)
        .accessibilityLabel("Envoyer la question")
    }
}

// MARK: - Feuille

/// `ProfTutorSheet` : bottom-sheet du prof IA, hauteur réglable à la poignée.
///
/// L'écran parent pose la demande (`quote` + contexte) et la retire à la
/// fermeture ; la session (streaming puis questions) vit dans `ProfTutorSession`.
/// La poignée règle la hauteur au doigt, entre deux butées, avec aimantation au
/// relâcher ; glissée trop bas, elle referme le panneau.
struct ProfTutorSheet: View {
    /// Demande de l'écran parent ; `nil` ferme la session.
    let request: ProfTutorRequest?
    /// Jeton de session Duello, posé depuis `SessionStore`.
    let token: String?
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

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                grip
                panel
            }
            .background(Theme.surface)
            .onAppear { containerHeight = proxy.size.height }
            .onChange(of: proxy.size.height) { containerHeight = $0 }
        }
        .presentationDetents([.fraction(sheetRatio)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            tutor.token = token
            syncRequest()
        }
        .onChange(of: token) { newValue in tutor.token = newValue }
        .onChange(of: request) { _ in syncRequest() }
    }

    /// Le panneau du prof IA, alimenté par la session.
    private var panel: some View {
        ProfTutorPanel(
            context: tutor.request?.context ?? .fallback,
            messages: tutor.messages,
            streamingText: tutor.streamingText,
            streaming: tutor.status == .streaming,
            suggestions: tutor.status == .ready ? tutor.suggestions : [],
            error: tutor.status == .error ? tutor.error : "",
            onSend: tutor.send,
            onClose: onClose
        )
    }

    // MARK: Poignée

    private var grip: some View {
        Capsule()
            .fill(Theme.border)
            .frame(width: 42, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.bottom, 10)
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

    // MARK: Demande

    /// `useEffect` de la source : ouvre à la demande posée, ferme à son retrait.
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
        tutor.open(quote: request.quote, context: request.context)
    }
}
