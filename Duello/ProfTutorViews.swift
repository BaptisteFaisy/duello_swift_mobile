//
//  ProfTutorViews.swift
//  Duello
//
//  Port de `src/components/prof-tutor/ProfTutorPanel.tsx` et
//  `src/components/ChatSendButton.tsx` (RN) — contenu du prof IA : en-tête
//  (avatar, nom, chevron de fiche), fil de messages, vignette de photo
//  expliquée, relances enroulées et barre de saisie.
//
//  Le panneau ne connaît ni le relais ni la navigation : il affiche les messages
//  et le streaming, et remonte la saisie. Le passage expliqué reste dans le
//  contexte envoyé au relais, sans répéter à l'écran ce que l'élève vient de
//  lire ; seule la photo expliquée garde une vignette. La saisie reste
//  verrouillée pendant le streaming, puis s'ouvre avec des relances. Quand
//  `onOpenProfile` est fourni, l'avatar et le nom ouvrent la fiche du prof.
//
//  Réduit / approché (24/09/2026) :
//    - la poignée `PanResponder` de la source devient un `DragGesture` qui pilote
//      un unique `PresentationDetent` `.fraction(sheetRatio)` (voir
//      `ProfTutorSheet`) ; les butées, l'aimantation (`snapProfSheetRatio`) et la
//      fermeture au relâcher (`shouldCloseProfSheetOnRelease`) restent ceux de
//      `ProfSheetHeight`.
//    - `useWindowDimensions().height` est déduit de la hauteur mesurée du panneau
//      (`GeometryReader`) : la hauteur pleine se reconstitue par `hauteur / ratio`.
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

/// `data:<mime>;base64,<…>` → image affichable (vignette « Photo expliquée »).
/// Le format a déjà été validé par `parseProfImageDataUrl` ; ici on décode.
func profImageFromDataUrl(_ dataUrl: String) -> UIImage? {
    guard let comma = dataUrl.firstIndex(of: ","),
          dataUrl[..<comma].contains(";base64")
    else { return nil }
    let payload = String(dataUrl[dataUrl.index(after: comma)...])
    guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else {
        return nil
    }
    return UIImage(data: data)
}

// MARK: - Panneau

/// `ProfTutorPanel` : en-tête, fil de messages, barre de saisie.
struct ProfTutorPanel: View {
    /// Photo expliquée en data-URL, absente pour une explication de texte.
    var imageUri: String? = nil
    let context: ProfTutorContext
    let messages: [ProfTutorMessage]
    let streamingText: String
    let streaming: Bool
    let suggestions: [String]
    let error: String
    let onSend: (String) -> Void
    /// Fourni : l'avatar et le nom ouvrent la fiche du prof (chevron « › »).
    var onOpenProfile: (() -> Void)? = nil
    let onClose: () -> Void

    @State private var draft = ""

    /// Ancre de défilement du bas de fil.
    private static let bottomAnchor = "prof-tutor-bottom"

    /// `locked` : saisie verrouillée pendant le streaming ou sans explication.
    private var locked: Bool { streaming || messages.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ProfTutorPanelHeader(context: context, onClose: onClose, onOpenProfile: onOpenProfile)
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
                    if let imageUri, let image = profImageFromDataUrl(imageUri) {
                        ProfTutorPhotoQuote(image: image)
                    }
                    messageContent
                    if !error.isEmpty { ProfTutorErrorBox(text: error) }
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], 14)
                .padding(.bottom, 20)
            }
            // `keyboardShouldPersistTaps="handled"` / `keyboardDismissMode` de la
            // source : le clavier reste ouvert quand on tape une relance.
            .scrollDismissesKeyboard(.never)
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

/// En-tête du panneau : avatar, nom, repère de contexte, chevron de fiche,
/// fermeture.
private struct ProfTutorPanelHeader: View {
    let context: ProfTutorContext
    let onClose: () -> Void
    let onOpenProfile: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let onOpenProfile {
                Button(action: onOpenProfile) { identity(chevron: true) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Voir le profil du prof IA")
            } else {
                identity(chevron: false)
            }
            closeButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
    }

    /// `renderIdentity` + chevron : avatar, « qui », puis « › » quand la fiche
    /// du prof est ouvrable.
    private func identity(chevron: Bool) -> some View {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            if chevron {
                Text("›")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// Vignette « Photo expliquée » : la seule citation gardée à l'écran, quand
/// l'explication vient d'une photo (cours ou page scannée).
private struct ProfTutorPhotoQuote: View {
    let image: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Photo expliquée")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.inkFaint)
                .padding(.bottom, 4)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo de cours expliquée")
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
                .clipShape(MsgBubbleShape(radius: 16, tightRadius: 4, isMine: true))
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

/// Relances proposées après la première explication, enroulées (`flexWrap`).
private struct ProfTutorSuggestionChips: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        ProfChipFlowLayout(spacing: 8) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `flexDirection: 'row' + flexWrap: 'wrap' + gap: 8` de la source : les puces
/// s'enroulent sur plusieurs lignes au lieu de défiler horizontalement.
struct ProfChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidths: [CGFloat] = [0]
        var rowHeights: [CGFloat] = [0]
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let current = rowWidths[rowWidths.count - 1]
            let needed = current == 0 ? size.width : current + spacing + size.width
            if needed > maxWidth && current > 0 {
                rowWidths.append(size.width)
                rowHeights.append(size.height)
            } else {
                rowWidths[rowWidths.count - 1] = needed
                rowHeights[rowHeights.count - 1] = max(rowHeights[rowHeights.count - 1], size.height)
            }
        }
        let height = rowHeights.reduce(0, +) + spacing * CGFloat(max(0, rowHeights.count - 1))
        return CGSize(width: proposal.width ?? (rowWidths.max() ?? 0), height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
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

    /// `ChatSendButton` : l'avion en papier Ionicons, rond noir 42×42.
    private var sendButton: some View {
        Button(action: onSend) {
            IonIcon(name: "send", size: 18, color: Theme.white)
                .frame(width: 42, height: 42)
                .background(Theme.ink)
                .clipShape(Circle())
        }
        .disabled(!canSend)
        .opacity(canSend ? 1 : 0.35)
        .accessibilityLabel("Envoyer la question")
    }
}
