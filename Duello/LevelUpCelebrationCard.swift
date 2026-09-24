//
//  LevelUpCelebrationCard.swift
//  Duello
//
//  Carte et étincelles de la célébration de montée de niveau — unité U5.
//
//  Fichier source Expo porté (libellés, mesures et couleurs repris mot pour mot) :
//    - src/components/LevelUpCelebration.tsx
//        `CelebrationSparkles`, `CelebrationCard` (et le `StyleSheet` associé).
//
//  Adaptations assumées (2026-09-24) :
//    - `expo-linear-gradient` → `LinearGradient` SwiftUI, mêmes arrêts
//      (`#1A211E` à 0, `#0A0D0C` à 0.58, `#050706` à 1).
//    - Les `Ionicons` (`sparkles`, `star`, `star-outline`) → symboles SF
//      (`sparkles`, `star.fill`, `star`) aux mêmes tailles et couleurs.
//    - `colors.progress` = `#16A34A` (`Theme.progress`), `colors.ink`
//      (`Theme.ink`), `colors.white` (`Theme.white`).
//    - `cardShadow` iOS du thème Expo : `Theme.duelloShadow()`.
//    - `accessibilityLiveRegion="assertive"` / `accessibilityRole="alert"` de la
//      source n'a pas d'équivalent iOS 16 : le message complet est porté par le
//      libellé d'accessibilité de la zone de fermeture (`LevelUpCelebration`).
//
//  Cible : iOS 16, SwiftUI ; aucune API iOS 17.
//
import SwiftUI

/// Une étincelle de la couronne (`sparkle*` du `StyleSheet`) : symbole, centre
/// dans la boîte 330 × 420 et couleur.
private struct LevelUpSparkle: Identifiable {
    let id: Int
    let symbol: String
    let size: CGFloat
    let center: CGPoint
    let colorHex: Int
}

/// `styles.sparkles` : boîte 330 × 420, six étincelles aux positions d'origine.
private let levelUpSparkles: [LevelUpSparkle] = [
    LevelUpSparkle(id: 0, symbol: "sparkles", size: 30,
                   center: CGPoint(x: 163, y: 19), colorHex: 0xFFFFFF),
    LevelUpSparkle(id: 1, symbol: "star.fill", size: 18,
                   center: CGPoint(x: 313, y: 87), colorHex: 0x16A34A),
    LevelUpSparkle(id: 2, symbol: "sparkles", size: 22,
                   center: CGPoint(x: 317, y: 315), colorHex: 0xFFFFFF),
    LevelUpSparkle(id: 3, symbol: "star", size: 25,
                   center: CGPoint(x: 169.5, y: 407.5), colorHex: 0x16A34A),
    LevelUpSparkle(id: 4, symbol: "star.fill", size: 16,
                   center: CGPoint(x: 16, y: 330), colorHex: 0xFFFFFF),
    LevelUpSparkle(id: 5, symbol: "sparkles", size: 24,
                   center: CGPoint(x: 14, y: 84), colorHex: 0x16A34A),
]

/// `CelebrationSparkles` : la couronne d'étincelles, projetée par `burst`.
struct LevelUpSparkles: View {
    let animation: LevelUpCelebrationAnimation

    var body: some View {
        ZStack {
            ForEach(levelUpSparkles) { sparkle in
                Image(systemName: sparkle.symbol)
                    .font(.system(size: sparkle.size))
                    .foregroundStyle(Color(hex: sparkle.colorHex))
                    .position(x: sparkle.center.x, y: sparkle.center.y)
            }
        }
        .frame(width: 330, height: 420)
        .opacity(animation.burstOpacity)
        .scaleEffect(animation.burstScale)
        .rotationEffect(.degrees(animation.burstRotation))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// `CelebrationCard` : sur-titre, pastille du niveau, « Bravo ! », message et
/// invitation à toucher.
struct LevelUpCelebrationCard: View {
    let level: Int
    let animation: LevelUpCelebrationAnimation

    var body: some View {
        content
            .frame(maxWidth: 350)
            .background(cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .duelloShadow()
            .opacity(animation.cardOpacity)
            .scaleEffect(animation.cardScale)
            .offset(y: animation.cardOffsetY)
            .accessibilityHidden(true)
    }

    /// Contenu de la carte (`cardGradient`), dans l'ordre de la source.
    private var content: some View {
        VStack(spacing: 0) {
            Text("NIVEAU SUPÉRIEUR")
                .font(.system(size: 11, weight: .black))
                .tracking(2.4)
                .foregroundStyle(Color.white.opacity(0.64))
            badge
                .padding(.top, 22)
            Text("Bravo !")
                .font(.system(size: 28, weight: .black))
                .tracking(-0.7)
                .foregroundStyle(Theme.white)
                .padding(.top, 22)
            Text("Tu passes au niveau \(level).")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.top, 7)
            Text("TOUCHER POUR CONTINUER")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.25)
                .foregroundStyle(Color.white.opacity(0.38))
                .padding(.top, 28)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 24)
    }

    /// Pastille du niveau (`badge` → `badgeRing` → `badgeCore`), animée par
    /// `badgeStyle.transform.scale`.
    private var badge: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x16A34A).opacity(0.12))
                .frame(width: 148, height: 148)
                .overlay(
                    Circle().strokeBorder(Color(hex: 0x16A34A).opacity(0.44), lineWidth: 1)
                )
            Circle()
                .strokeBorder(Theme.progress, lineWidth: 2)
                .frame(width: 122, height: 122)
            Circle()
                .fill(Theme.white)
                .frame(width: 104, height: 104)
                .overlay(
                    Text("\(level)")
                        .font(.system(size: 58, weight: .black))
                        .tracking(-2.5)
                        .foregroundStyle(Theme.ink)
                )
        }
        .scaleEffect(animation.badgeScale)
    }

    /// `cardGradient` : dégradé `['#1A211E', '#0A0D0C', '#050706']` aux
    /// emplacements `[0, 0.58, 1]`, de haut en bas.
    private var cardGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0x1A211E), location: 0),
                .init(color: Color(hex: 0x0A0D0C), location: 0.58),
                .init(color: Color(hex: 0x050706), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
