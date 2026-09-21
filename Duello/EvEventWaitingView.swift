//
//  EvEventWaitingView.swift
//  Duello
//
//  Phases « upcoming » et « waiting » : décompte plein écran, puis salle
//  d'attente avec son compteur de présents et le bouton « Participer ».
//
//  Fichier source Expo porté : branche correspondante de
//  `src/components/event/EventWorkspace.tsx` (décompte centré, salle
//  d'attente, bouton « Participer », note « Tu es inscrit… »).
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventWaitingView: View {
    let event: EvEvent
    @ObservedObject var model: EvEventSession
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EvEventTopBar(onBack: onBack)
            VStack(spacing: 18) {
                if let start = model.startDate {
                    EvEventCountdown(targetAt: start, now: model.now)
                } else {
                    Text("Horaire à venir")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                }
                if model.phase == .waiting { waitingRoom }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            EvEventActionsBar(event: event, token: model.token)
        }
        .background(Theme.surface)
    }

    /// Salle d'attente : compteur de présents, puis bouton ou note d'inscription.
    private var waitingRoom: some View {
        VStack(spacing: 12) {
            Text(waitingCountText)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            if model.joined == false || model.waitingCount == nil {
                Button(action: { model.joinEventParticipation() }) {
                    Text("Participer")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 42)
                        .background(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Participer à l'événement")
            } else {
                Text("Tu es inscrit. L’épreuve s’ouvrira automatiquement au début.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            if !model.joinError.isEmpty {
                Text(model.joinError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.like)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Compteur de présents, au pluriel quand il y a plus d'un participant.
    private var waitingCountText: String {
        guard let count = model.waitingCount else { return "Salle d’attente…" }
        return "\(count) participant\(count > 1 ? "s" : "") sur la page d’attente"
    }
}
