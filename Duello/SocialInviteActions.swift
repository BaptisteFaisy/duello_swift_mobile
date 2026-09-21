//
//  SocialInviteActions.swift
//  Duello
//
//  Lot « Social » — actions du volet d'invitation : partage vers un ami qui
//  n'a pas encore de compte, et envoi du défi aux amis choisis.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ChallengeInviteModal.tsx   (channelsMenu,
//                                                 channelsMenuRow,
//                                                 inviteMethods,
//                                                 sendInvitationButton)
//
//  Découpé de `SocialInviteModal.swift` (règle des 500 lignes) : contenu repris
//  à l'identique, aucun type ni libellé renommé.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Canaux de partage

/// Menu des canaux de partage (`channelsMenu`) : Message, WhatsApp, Instagram.
///
/// Le partage vit ici pour les personnes qui n'ont pas encore de compte ; le
/// défi direct, lui, part du bouton d'envoi.
struct SocInviteChannelsMenu: View {
    let openingChannel: SocShareChannel?
    let errorMessage: String?
    let onOpen: (SocShareChannel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(SocShareChannel.allCases) { channel in
                row(channel)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1))
        .padding(.top, 6)
    }

    /// Ligne d'un canal (`channelsMenuRow`) : icône, libellé, indicateur.
    /// Toutes les lignes patientent pendant l'ouverture d'un canal.
    private func row(_ channel: SocShareChannel) -> some View {
        Button { onOpen(channel) } label: {
            HStack(spacing: 10) {
                if openingChannel == channel {
                    ProgressView().tint(Theme.ink)
                } else {
                    Image(systemName: channel.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text(channel.label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(openingChannel != nil)
        .accessibilityLabel("Inviter un ami par \(channel.label)")
    }
}

// MARK: - Envoi

/// Bouton « Envoyer le défi » (`sendInvitationButton`), avec son indicateur.
struct SocInviteSendButton: View {
    let enabled: Bool
    let sending: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if sending {
                    ProgressView().tint(Theme.surface)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Envoyer le défi")
                        .font(.system(size: 12, weight: .black))
                }
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || sending)
        .accessibilityLabel(label)
        .padding(.top, 10)
    }
}
