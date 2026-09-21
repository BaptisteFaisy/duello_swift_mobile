//
//  EvEventActionsBar.swift
//  Duello
//
//  Barre d'actions au bas de l'espace événement : vues de la carte, ajout à
//  l'agenda et partages. L'œil affiche le nombre de comptes ayant ouvert
//  l'événement ; le compteur de partage suit des personnes, pas des messages.
//
//  Fichier source Expo porté : `src/components/event/EventActionsBar.tsx`
//  (compteurs d'interactions, rappel d'agenda, ouverture des canaux, note
//  temporaire de 4 s).
//
//  Substitutions SF Symbols : eye-outline → eye ; calendar-outline → calendar ;
//  share-social-outline → square.and.arrow.up.
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit
import MessageUI

struct EvEventActionsBar: View {
    let event: EvEvent
    let token: String?

    @State private var counts: EvInteractionCounts?
    @State private var shareSheetVisible = false
    @State private var messageComposerVisible = false
    @State private var shareError: String?
    @State private var actionNote: String?
    @State private var busyChannel: EvShareChannel?
    @State private var noteToken = 0

    /// Durée d'affichage d'une note d'action (`setTimeout(…, 4_000)`).
    private let noteLifetime: UInt64 = 4_000_000_000

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                viewersCell
                calendarCell
                shareCell
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            if let actionNote {
                note(actionNote, color: Theme.inkFaint)
            }
            if let shareError {
                note(shareError, color: Theme.like)
            }
        }
        .task { await loadCounts() }
        .sheet(isPresented: $shareSheetVisible) {
            EvEventShareSheet(
                event: event,
                openingChannel: busyChannel,
                error: shareError,
                onOpen: { channel in choose(channel) }
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

    /// Compteur de vues de la carte, non actionnable.
    private var viewersCell: some View {
        VStack(spacing: 5) {
            Image(systemName: "eye")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(height: 24)
            Text(counts.map { "\($0.viewers)" } ?? "—")
                .font(.system(size: 13, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Ajout à l'agenda de l'appareil, rappel copié au passage.
    private var calendarCell: some View {
        Button { Task { await addToCalendar() } } label: {
            VStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .frame(height: 24)
                Text("Ajouter à mon agenda")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ajouter l'événement à mon agenda")
        .accessibilityHint("Copie un rappel puis ouvre l'application Calendrier ou Agenda")
    }

    /// Compteur de partages, qui ouvre la feuille Message / WhatsApp / Instagram.
    private var shareCell: some View {
        Button { actionNote = nil; shareError = nil; shareSheetVisible = true } label: {
            VStack(spacing: 5) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .frame(height: 24)
                Text(counts.map { "\($0.shares)" } ?? "—")
                    .font(.system(size: 13, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Partager l'événement")
        .accessibilityHint("Ouvre le menu Message, WhatsApp ou Instagram")
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
        showNote("Partage compté. Merci !")
    }

    /// Affiche une note pendant quatre secondes.
    private func showNote(_ text: String) {
        actionNote = text
        noteToken += 1
        let token = noteToken
        Task {
            try? await Task.sleep(nanoseconds: noteLifetime)
            await MainActor.run {
                if noteToken == token { actionNote = nil }
            }
        }
    }

    /// Copie le rappel puis ouvre l'agenda ; le message suit la voie retenue.
    private func addToCalendar() async {
        actionNote = nil
        let copied = EvEventCalendar.copyReminder(event)
        switch await EvEventCalendar.open(event) {
        case .native:
            showNote(copied
                ? "Rappel copié : colle-le dans un nouvel événement."
                : "Agenda ouvert.")
        case .google:
            showNote(copied
                ? "Rappel copié. Google Agenda est prérempli."
                : "Google Agenda ouvert.")
        case .none:
            showNote(copied
                ? "Rappel copié : colle-le dans ton agenda."
                : "Impossible d’ouvrir l’agenda sur cet appareil.")
        }
    }
}
