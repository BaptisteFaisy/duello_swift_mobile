//
//  EvEventWaitingView.swift
//  Duello
//
//  Phases « upcoming » et « waiting » : décompte dans la barre du haut (à
//  droite du chevron), puis salle d'attente réduite au bouton « Rejoindre ».
//
//  Fichier source Expo porté : branche correspondante de
//  `src/components/event/EventWorkspace.tsx` (décompte dans la barre du haut,
//  salle d'attente sans phrase : ni compteur, ni note d'inscription — les
//  présents se voient sur le rail d'icônes le long du bord droit).
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventWaitingView: View {
    let event: EvEvent
    @ObservedObject var model: EvEventSession
    let onBack: () -> Void
    /// Ouvre le profil d'un participant (classement, chat) ; `nil` inactif.
    var onOpenProfile: ((String) -> Void)? = nil

    /// Identifiant public du compte courant, transmis à la barre d'actions.
    private var ownId: String { DuelloAPI.publicProfileId(email: model.email) }

    /// Le décompte vit dans la barre du haut, à droite du chevron ; sans
    /// horaire lisible, aucune barre de titre (jamais de texte inventé).
    private var topBarTitle: AnyView? {
        guard let start = model.startDate else { return nil }
        return AnyView(EvEventCountdown(targetAt: start, now: model.now))
    }

    var body: some View {
        VStack(spacing: 0) {
            EvEventTopBar(titleView: topBarTitle, onBack: onBack)
            VStack(spacing: 18) {
                if model.phase == .upcoming { EvEventReminderOptIn(event: event) }
                middleRoom
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(24)
            EvEventActionsBar(
                event: event,
                token: model.token,
                ownId: ownId,
                onOpenProfile: onOpenProfile,
                chatOpen: EvEventSchedule.isChatOpen(event, now: model.now)
            )
        }
        .background(Theme.surface)
    }

    /// Salle d'attente sans phrase : ni compteur, ni note d'inscription. Le
    /// bouton n'apparaît que tant que l'inscription n'est pas posée
    /// (`joined !== true`) ; avant la salle d'attente il reste affiché mais
    /// désactivé (`disabled={!waitingOpen}`).
    private var middleRoom: some View {
        let waitingOpen = model.phase == .waiting
        return VStack(spacing: 12) {
            if model.joined != true {
                Button(action: { model.joinEventParticipation() }) {
                    Text("Rejoindre")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 42)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                                .stroke(Theme.ink, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!waitingOpen)
                .opacity(waitingOpen ? 1 : 0.4)
                .accessibilityLabel("Rejoindre l’événement")
            }
            if !model.joinError.isEmpty {
                Text(model.joinError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.like)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
