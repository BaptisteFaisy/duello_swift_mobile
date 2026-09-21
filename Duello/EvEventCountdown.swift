//
//  EvEventCountdown.swift
//  Duello
//
//  Décompte d'un événement en quatre unités : jours, heures, minutes, secondes.
//  La cible est un instant absolu : le composant ne garde aucun cumul local,
//  donc une mise en veille du téléphone ne fausse jamais le compte. L'instant
//  courant est fourni par la session, seul porteur de l'horloge.
//
//  Fichier source Expo porté : `src/components/event/EventCountdown.tsx`.
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventCountdown: View {
    let targetAt: Date
    let now: Date

    var body: some View {
        HStack(alignment: .bottom, spacing: 26) {
            ForEach(EvEventSchedule.countdownSegments(targetAt: targetAt, now: now)) { segment in
                EvEventCountdownCell(segment: segment)
            }
        }
    }
}

/// Une unité du décompte : nombre tabulaire à deux chiffres, unité en dessous.
private struct EvEventCountdownCell: View {
    let segment: EvCountdownSegment

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", segment.value))
                .font(.system(size: 34, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(segment.unit)
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(Theme.inkSoft)
        }
    }
}
