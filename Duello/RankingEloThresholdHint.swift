import Foundation
import SwiftUI

// MARK: - Astuce de seuil Elo (EloLeagueThresholdHint)
//
//  Découpé de `RankingSubjectLeaderboard.swift` (règle des 500 lignes) :
//  encart de démonstration de l'astuce de seuil Elo (`EloLeagueThresholdHint`
//  de `RankingsScreen.tsx:71-247`). Aucun type ni membre renommé.

/// Segment d'animation : plage `[start, start + duration)` et courbe.
private struct EloHintSegment {
    let start: Double
    let duration: Double
    let from: Double
    let to: Double
    let ease: (Double) -> Double
}

/// `Easing.out(Easing.quad)`.
private func eloHintQuadOut(_ t: Double) -> Double {
    let x = LeagueAnimation.clamp01(t)
    return 1 - (1 - x) * (1 - x)
}

/// Durée d'un tour de boucle, en secondes (`Animated.loop` de la source).
private let eloHintLoopDuration: Double = 4.76

/// `demoHandPosition` : approche de la main vers le blason, puis retrait.
private let eloHintHandPositionSegments: [EloHintSegment] = [
    EloHintSegment(start: 0.45, duration: 0.52, from: 0, to: 1, ease: LeagueAnimation.cubicOut),
    EloHintSegment(start: 1.77, duration: 0.36, from: 1, to: 0, ease: LeagueAnimation.cubicInOut),
    EloHintSegment(start: 2.78, duration: 0.52, from: 0, to: 1, ease: LeagueAnimation.cubicOut),
    EloHintSegment(start: 3.95, duration: 0.36, from: 1, to: 0, ease: LeagueAnimation.cubicInOut),
]

/// `demoHandPress` : appui de la main (échelle).
private let eloHintHandPressSegments: [EloHintSegment] = [
    EloHintSegment(start: 0.97, duration: 0.13, from: 0, to: 1, ease: LeagueAnimation.quadOut),
    EloHintSegment(start: 1.10, duration: 0.22, from: 1, to: 0, ease: LeagueAnimation.quadOut),
    EloHintSegment(start: 3.30, duration: 0.13, from: 0, to: 1, ease: LeagueAnimation.quadOut),
    EloHintSegment(start: 3.43, duration: 0.22, from: 1, to: 0, ease: LeagueAnimation.quadOut),
]

/// `demoThresholdOpacity` : apparition puis disparition du seuil affiché.
private let eloHintThresholdSegments: [EloHintSegment] = [
    EloHintSegment(start: 1.10, duration: 0.18, from: 0, to: 1, ease: eloHintQuadOut),
    EloHintSegment(start: 3.43, duration: 0.18, from: 1, to: 0, ease: eloHintQuadOut),
]

/// Échantillonne une suite de segments à l'instant `time`, en boucle.
private func eloHintSample(_ time: Double, _ segments: [EloHintSegment]) -> Double {
    guard let first = segments.first else { return 0 }
    let looped = max(0, time).truncatingRemainder(dividingBy: eloHintLoopDuration)
    var value = first.from
    for segment in segments {
        if looped < segment.start { return value }
        if looped < segment.start + segment.duration {
            let local = (looped - segment.start) / segment.duration
            return segment.from + (segment.to - segment.from) * segment.ease(local)
        }
        value = segment.to
    }
    return value
}

/// Astuce de seuil Elo (`EloLeagueThresholdHint`) : une main approche du
/// blason, l'appuie, et le seuil Elo apparaît puis disparaît, en boucle.
///
/// La boucle `Animated.loop` de la source est transposée par
/// `TimelineView(.animation)` : la position de la main, l'appui et l'opacité du
/// seuil sont échantillonnés à chaque image depuis une table de segments
/// (durées identiques à la séquence de `RankingsScreen.tsx:82-158`).
struct EloLeagueThresholdHint: View {
    /// Ligue dont on montre le seuil (`highestEloLeague`).
    let league: EloLeague
    /// Fermeture persistée de l'astuce.
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                VStack(spacing: 0) {
                    demo(time: time)
                    thresholdValue(time: time)
                }
            }
            closeButton
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Appuie sur un blason pour afficher ou masquer l’Elo minimum de sa ligue. Exemple : \(league.label), \(groupedNumber(league.minimumElo)) Elo.")
    }

    /// Blason et main animée (`eloThresholdHintInteraction`).
    private func demo(time: Double) -> some View {
        let position = eloHintSample(time, eloHintHandPositionSegments)
        let press = eloHintSample(time, eloHintHandPressSegments)
        return ZStack {
            LeagueBadgeImage(leagueId: league.id, size: 68)
            IonIcon(name: "hand-left-outline", size: 23, color: Theme.inkSoft)
                .opacity(LeagueAnimation.interpolate(position, [0, 0.18, 1], [0.35, 1, 1], clamped: true))
                .scaleEffect(1 - 0.14 * press)
                .offset(x: -67 + 39 * position, y: 2)
        }
        .frame(width: 68, height: 68)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 90)
    }

    /// Seuil Elo révélé (`eloThresholdHintValue`).
    private func thresholdValue(time: Double) -> some View {
        let opacity = eloHintSample(time, eloHintThresholdSegments)
        return Text("\(groupedNumber(league.minimumElo)) Elo")
            .font(.system(size: 11, weight: .heavy).monospacedDigit())
            .foregroundStyle(Theme.ink)
            .opacity(opacity)
            .offset(y: LeagueAnimation.interpolate(opacity, [0, 1], [-3, 0], clamped: true))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 18)
    }

    /// Fermeture définitive (`eloThresholdHintClose`).
    private var closeButton: some View {
        Button(action: onDismiss) {
            IonIcon(name: "close", size: 20, color: Theme.inkSoft)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .padding(.top, 5)
        .padding(.trailing, 6)
        .accessibilityLabel("Masquer définitivement l’explication des seuils Elo")
    }
}
