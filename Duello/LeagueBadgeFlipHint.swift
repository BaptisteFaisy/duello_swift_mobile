//
//  LeagueBadgeFlipHint.swift
//  Duello
//
//  Démonstration du retournement de blason (`BadgeFlipHint.tsx`).
//
//  Fichiers source Expo portés (libellés et minutages repris mot pour mot) :
//    - src/components/BadgeFlipHint.tsx
//
//  La boucle `Animated.loop` de la source (position de la main, appui, rotation
//  `rotateY`) est transposée par `TimelineView(.animation)` : la position de la
//  main, l'appui et l'angle de retournement sont échantillonnés à chaque image
//  depuis une table de segments (durées identiques à `createHintLoop`).
//  La face arrière (`backFace: ReactNode`) est portée en `AnyView`, comme la
//  source accepte n'importe quel nœud.
//  La source ne consulte pas la réduction des mouvements pour cette
//  démonstration : la boucle tourne donc toujours, comme dans `BadgeFlipHint`.
//  `perspective: 700` (React Native) est approché par `perspective: 0.5`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Côté de l'aperçu de blason (`BADGE_PREVIEW_SIZE`).
private let leagueFlipPreviewSize: CGFloat = 54

/// Durée d'un tour de boucle, en secondes (`createHintLoop`).
private let leagueFlipLoopDuration: Double = 5.09

/// Segment d'animation : plage `[start, start + duration)` et courbe.
private struct LeagueFlipSegment {
    let start: Double
    let duration: Double
    let from: Double
    let to: Double
    let ease: (Double) -> Double
}

/// `tapPhase` + `retreatHand` : position de la main au fil de la boucle.
private let leagueFlipHandPositionSegments: [LeagueFlipSegment] = [
    LeagueFlipSegment(start: 0.45, duration: 0.52, from: 0, to: 1, ease: LeagueAnimation.cubicOut),
    LeagueFlipSegment(start: 1.90, duration: 0.36, from: 1, to: 0, ease: LeagueAnimation.cubicInOut),
    LeagueFlipSegment(start: 2.91, duration: 0.52, from: 0, to: 1, ease: LeagueAnimation.cubicOut),
    LeagueFlipSegment(start: 4.28, duration: 0.36, from: 1, to: 0, ease: LeagueAnimation.cubicInOut),
]

/// `tapPhase` : appui de la main au fil de la boucle.
private let leagueFlipHandPressSegments: [LeagueFlipSegment] = [
    LeagueFlipSegment(start: 0.97, duration: 0.13, from: 0, to: 1, ease: LeagueAnimation.quadIn),
    LeagueFlipSegment(start: 1.10, duration: 0.22, from: 1, to: 0, ease: LeagueAnimation.quadIn),
    LeagueFlipSegment(start: 3.43, duration: 0.13, from: 0, to: 1, ease: LeagueAnimation.quadIn),
    LeagueFlipSegment(start: 3.56, duration: 0.22, from: 1, to: 0, ease: LeagueAnimation.quadIn),
]

/// `flip` : angle de retournement (0 = face avant, 1 = face arrière).
private let leagueFlipRotationSegments: [LeagueFlipSegment] = [
    LeagueFlipSegment(start: 1.10, duration: 0.42, from: 0, to: 1, ease: LeagueAnimation.cubicInOut),
    LeagueFlipSegment(start: 3.56, duration: 0.42, from: 1, to: 0, ease: LeagueAnimation.cubicInOut),
]

/// Échantillonne une suite de segments à l'instant `time`, en boucle.
private func leagueFlipSample(_ time: Double, _ segments: [LeagueFlipSegment]) -> Double {
    guard let first = segments.first else { return 0 }
    let looped = max(0, time).truncatingRemainder(dividingBy: leagueFlipLoopDuration)
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

/// Démonstration du retournement de blason : une main approche, appuie, le
/// blason se retourne, puis la boucle repart.
struct LeagueBadgeFlipHint: View {
    /// Libellé lu par VoiceOver pour l'ensemble de la démonstration.
    let accessibilityLabel: String
    /// Adresse du blason ; `nil` ⇒ repli bouclier.
    let badgeURL: URL?
    /// Libellé du bouton de fermeture.
    let dismissAccessibilityLabel: String
    /// Ferme la démonstration ; sans valeur, aucun bouton n'est affiché.
    let onDismiss: (() -> Void)?
    /// Contenu de la face arrière (`backFace`), déjà effacé en `AnyView`.
    let backFace: AnyView

    @State private var startedAt = Date()

    init<BackFace: View>(accessibilityLabel: String,
                         badgeURL: URL?,
                         dismissAccessibilityLabel: String = "Masquer la démonstration du blason",
                         onDismiss: (() -> Void)? = nil,
                         @ViewBuilder backFace: () -> BackFace) {
        self.accessibilityLabel = accessibilityLabel
        self.badgeURL = badgeURL
        self.dismissAccessibilityLabel = dismissAccessibilityLabel
        self.onDismiss = onDismiss
        self.backFace = AnyView(backFace())
    }

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSince(startedAt)
            card(
                position: leagueFlipSample(time, leagueFlipHandPositionSegments),
                press: leagueFlipSample(time, leagueFlipHandPressSegments),
                flip: leagueFlipSample(time, leagueFlipRotationSegments)
            )
        }
        .onAppear { startedAt = Date() }
    }

    /// La carte : bord fin, rayon moyen, la démonstration centrée et, si
    /// demandé, un bouton de fermeture en haut à droite.
    private func card(position: Double, press: Double, flip: Double) -> some View {
        ZStack(alignment: .topLeading) {
            LeagueFlipBadge(badgeURL: badgeURL, flip: flip, backFace: backFace)
            LeagueFlipHand(position: position, press: press)
                .offset(x: -45, y: 16)
        }
        .frame(width: leagueFlipPreviewSize, height: leagueFlipPreviewSize, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if let onDismiss {
                LeagueFlipDismissButton(label: dismissAccessibilityLabel, action: onDismiss)
                    .padding(.top, 4)
                    .padding(.trailing, 6)
            }
        }
        .padding(.bottom, 12)
    }
}

/// Main qui approche et appuie (`HintHand`).
private struct LeagueFlipHand: View {
    let position: Double
    let press: Double

    private var opacity: Double {
        LeagueAnimation.interpolate(position, [0, 0.18, 1], [0.35, 1, 1])
    }
    private var translateX: CGFloat {
        CGFloat(LeagueAnimation.interpolate(position, [0, 1], [0, 27]))
    }
    private var scale: Double {
        LeagueAnimation.interpolate(press, [0, 1], [1, 0.86])
    }

    var body: some View {
        Image(systemName: "hand.point.left")
            .font(.system(size: 23))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: 24, height: 24)
            .scaleEffect(scale)
            .offset(x: translateX)
            .opacity(opacity)
            .accessibilityHidden(true)
    }
}

/// Le blason à deux faces (`HintBadge`) : l'avers tourne de 0 à 180°, le revers
/// de 180 à 360°. `backfaceVisibility: hidden` est reproduit en n'affichant que
/// la face tournée vers l'écran.
private struct LeagueFlipBadge: View {
    let badgeURL: URL?
    let flip: Double
    let backFace: AnyView

    private var frontAngle: Double { flip * 180 }
    private var backAngle: Double { 180 + flip * 180 }
    private var showsFront: Bool { flip < 0.5 }

    var body: some View {
        ZStack {
            front
                .frame(width: leagueFlipPreviewSize, height: leagueFlipPreviewSize)
                .rotation3DEffect(.degrees(frontAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .opacity(showsFront ? 1 : 0)
            backFace
                .frame(width: leagueFlipPreviewSize, height: leagueFlipPreviewSize)
                .rotation3DEffect(.degrees(backAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .opacity(showsFront ? 0 : 1)
        }
        .frame(width: leagueFlipPreviewSize, height: leagueFlipPreviewSize)
    }

    private var front: some View {
        Group {
            if let badgeURL {
                AsyncImage(url: badgeURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
            } else {
                Image(systemName: "shield")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

/// Bouton de fermeture de la démonstration (`DismissButton`).
private struct LeagueFlipDismissButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 20))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
