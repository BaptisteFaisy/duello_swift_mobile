//
//  EvEventShareSheet.swift
//  Duello
//
//  Feuille Message / WhatsApp / Instagram, dans le ton du volet d'invitation
//  des défis, et composeur de message système.
//
//  Fichier source Expo porté : `EventShareSheet` de
//  `src/components/event/EventActionsBar.tsx`. Le canal « Message » ouvre le
//  composeur système (`SMS.sendSMSAsync` côté Expo) ; WhatsApp et Instagram
//  s'ouvrent par leur URL.
//
//  Différence assumée : la source garde la feuille ouverte pendant l'ouverture
//  du canal ; sur iOS le composeur système ne peut pas se poser par-dessus, donc
//  la feuille se referme avant l'ouverture et la note d'action s'affiche dans la
//  barre. Le jeton d'attente reste affiché si le canal se rouvre.
//
//  Cible : iOS 16.
//
import SwiftUI
import MessageUI

struct EvEventShareSheet: View {
    let event: EvEvent
    let openingChannel: EvShareChannel?
    let error: String?
    let onOpen: (EvShareChannel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Theme.border)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            Text("Partager l’événement")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2)
                .padding(.top, 2)
                .padding(.bottom, 12)
            ForEach(EvShareChannel.allCases) { channel in
                channelRow(channel)
            }
            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.like)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(Theme.surface)
        .presentationDetents([.fraction(0.42)])
    }

    /// Une ligne de canal : symbole, libellé, et jeton d'attente.
    private func channelRow(_ channel: EvShareChannel) -> some View {
        Button { onOpen(channel) } label: {
            HStack(spacing: 12) {
                Image(systemName: channel.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 24)
                Text(channel.label)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if openingChannel == channel {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(openingChannel != nil)
        .accessibilityLabel(channel.accessibilityLabel)
    }
}

// MARK: - Composeur de message

/// Composeur de message du système (`SMS.sendSMSAsync` côté Expo).
struct EvEventMessageComposer: UIViewControllerRepresentable {
    let message: String
    let onFinish: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.body = message
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let onFinish: (MessageComposeResult) -> Void

        init(onFinish: @escaping (MessageComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            onFinish(result)
        }
    }
}
