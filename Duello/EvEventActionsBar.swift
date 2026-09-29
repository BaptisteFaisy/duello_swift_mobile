//
//  EvEventActionsBar.swift
//  Duello
//
//  Barre d'actions au bas de l'espace événement : vues de la carte,
//  partages et chat des participants. L'œil affiche le nombre de comptes ayant
//  ouvert l'événement ; le compteur de partage suit des personnes, pas des
//  messages ; la bulle ouvre le chat, grisée pendant l'épreuve.
//
//  Fichier source Expo porté : `src/components/event/EventActionsBar.tsx`
//  (compteurs d'interactions, compteur du chat, ouverture des canaux, note
//  temporaire de 4 s).
//
//  Icônes Ionicons : eye-outline (22), share-social-outline (22),
//  chatbubbles-outline (22), comme la source — plus de substitution SF Symbol.
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit
import MessageUI

struct EvEventActionsBar: View {
    let event: EvEvent
    let token: String?
    /// Identifiant public du compte courant.
    var ownId: String? = nil
    /// Ouvre le profil du compte choisi ; `nil` laisse les lignes inactives.
    var onOpenProfile: ((String) -> Void)? = nil
    /// Faux pendant l'épreuve : le chat est alors fermé et la bulle grisée.
    var chatOpen: Bool = true

    /// Présence live, injectée par `.evEventPresence(...)` de l'espace événement.
    @EnvironmentObject private var presence: EvEventPresenceStore

    @State private var counts: EvInteractionCounts?
    @State private var chatTotal: Int?
    @State private var viewersVisible = false
    @State private var shareSheetVisible = false
    @State private var chatVisible = false
    @State private var messageComposerVisible = false
    @State private var shareError: String?
    @State private var busyChannel: EvShareChannel?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                viewersCell
                shareCell
                chatCell
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            if let shareError {
                note(shareError, color: Theme.like)
            }
        }
        .task { await loadCounts() }
        // Compteur du chat : relu à l'ouverture de la page, puis à chaque
        // fermeture du chat — des messages ont pu partir entre-temps.
        .task(id: chatVisible) { await loadChatTotal() }
        .sheet(isPresented: $viewersVisible) {
            EvEventViewersSheet(
                eventId: event.id,
                token: token,
                ownId: ownId,
                onOpenProfile: onOpenProfile
            )
        }
        .sheet(isPresented: $shareSheetVisible) {
            EvEventShareSheet(
                event: event,
                openingChannel: busyChannel,
                error: shareError,
                onOpen: { channel in choose(channel) }
            )
        }
        .sheet(isPresented: $chatVisible) {
            EvEventChatSheet(
                eventId: event.id,
                eventTitle: event.title,
                token: token,
                ownId: ownId,
                chatOpen: chatOpen,
                onOpenProfile: onOpenProfile
            )
        }
        .fullScreenCover(isPresented: $messageComposerVisible) {
            EvEventMessageComposer(message: EvEventShare.message(for: event)) { result in
                messageComposerVisible = false
                busyChannel = nil
                switch result {
                case .sent, .cancelled:
                    onShareSent()
                case .failed:
                    shareError = "Impossible d’ouvrir Message sur cet appareil."
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: Cellules

    /// Compteur de vues de la carte ; l'œil ouvre la liste des personnes qui ont
    /// vu la page (`eye-outline`, 22, encre).
    private var viewersCell: some View {
        actionCell(
            icon: "eye-outline",
            count: (presence.views ?? counts?.viewers).map { "\($0)" },
            disabled: false,
            action: { viewersVisible = true }
        )
        .accessibilityLabel("Voir les vues de l’événement")
        .accessibilityHint("Ouvre la liste des personnes qui ont vu la page")
    }

    /// Compteur de partages, qui ouvre la feuille Message / WhatsApp / Instagram
    /// (`share-social-outline`, 22, encre).
    private var shareCell: some View {
        actionCell(
            icon: "share-social-outline",
            count: (presence.shares ?? counts?.shares).map { "\($0)" },
            disabled: false,
            action: { shareError = nil; shareSheetVisible = true }
        )
        .accessibilityLabel("Partager l'événement")
        .accessibilityHint("Ouvre le menu Message, WhatsApp ou Instagram")
    }

    /// Compteur de messages du chat, qui ouvre la discussion
    /// (`chatbubbles-outline`, 22 ; grisé pendant l'épreuve).
    private var chatCell: some View {
        actionCell(
            icon: "chatbubbles-outline",
            count: chatTotal.map { "\($0)" },
            disabled: !chatOpen,
            action: { chatVisible = true }
        )
        .accessibilityLabel("Ouvrir le chat de l’événement")
        .accessibilityHint(chatOpen
            ? "Lis et écris des messages avec les participants"
            : "Chat fermé pendant l’épreuve")
    }

    /// Cellule d'action : icône Ionicons (22) dans un cadre de 24, compteur
    /// tabulaire (13, 900). Sans bordure, comme `actionCell` de la source.
    private func actionCell(
        icon: String,
        count: String?,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                IonIcon(name: icon, size: 22, color: disabled ? Theme.inkFaint : Theme.ink)
                    .frame(height: 24)
                Text(count ?? "—")
                    .font(.system(size: 13, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(disabled ? Theme.inkFaint : Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(EvActionCellButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    /// Note de bas de barre, centrée et discrète.
    private func note(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 6)
    }

    // MARK: Actions

    /// Compteurs affichés : la vue locale est rejointe par celles des autres
    /// comptes à chaque ouverture de la page.
    private func loadCounts() async {
        if let next = try? await EvEventAPI.interactions(eventId: event.id, token: token) {
            counts = next
        }
    }

    /// Compteur du chat : relu quand le chat n'est pas ouvert. Un échec (dont le
    /// 403 du chat fermé) laisse le tiret affiché.
    private func loadChatTotal() async {
        guard chatOpen, !chatVisible else { return }
        if let state = try? await EvEventAPI.chat(eventId: event.id, token: token) {
            chatTotal = state.total
        }
    }

    /// Ouvre le canal choisi, puis compte le partage s'il est parti.
    private func choose(_ channel: EvShareChannel) {
        guard busyChannel == nil else { return }
        shareSheetVisible = false
        shareError = nil
        let message = EvEventShare.message(for: event)
        switch channel {
        case .sms:
            guard MFMessageComposeViewController.canSendText() else {
                shareError = "Impossible d’ouvrir Message sur cet appareil."
                return
            }
            busyChannel = channel
            messageComposerVisible = true
        case .whatsapp:
            guard let url = EvEventShare.whatsappUrl(message: message) else {
                shareError = "Impossible d’ouvrir WhatsApp sur cet appareil."
                return
            }
            busyChannel = channel
            openUrl(url) { accepted in
                busyChannel = nil
                if accepted {
                    onShareSent()
                } else {
                    shareError = "Impossible d’ouvrir WhatsApp sur cet appareil."
                }
            }
        case .instagram:
            UIPasteboard.general.string = message
            guard let url = EvEventShare.instagramInboxUrl() else {
                shareError = "Le message a été copié. Ouvre Instagram pour le partager."
                return
            }
            busyChannel = channel
            openUrl(url) { accepted in
                busyChannel = nil
                if accepted {
                    onShareSent()
                } else {
                    shareError = "Le message a été copié. Ouvre Instagram pour le partager."
                }
            }
        }
    }

    /// Ouvre une URL système et rend vrai si le système l'a acceptée.
    private func openUrl(_ url: URL, completion: @escaping (Bool) -> Void) {
        UIApplication.shared.open(url, options: [:], completionHandler: completion)
    }

    /// Une feuille qui se ferme sans partage envoyé ne compte personne : le
    /// compteur ne bouge qu'ici, sur un envoi effectif.
    private func onShareSent() {
        if let current = counts {
            counts = EvInteractionCounts(viewers: current.viewers, shares: current.shares + 1)
        }
        Task { await EvEventAPI.recordShare(eventId: event.id, token: token) }
    }
}

/// État d'appui d'une cellule d'action (`actionPressed`,
/// `EventActionsBar.tsx:418-421`) : fond `surfaceMuted` et opacité 0.72 tant
/// que le doigt est posé. Hors appui, fond `surface` et rayon `medium`.
private struct EvActionCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.surfaceMuted : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
