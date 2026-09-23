//
//  LeaguePromotionCard.swift
//  Duello
//
//  Carte de promotion « NOUVELLE LIGUE » (`EloLeaguePromotionCard.tsx`).
//
//  Fichiers source Expo portés (libellés et mesures repris mot pour mot) :
//    - src/components/EloLeaguePromotionCard.tsx
//    - src/hooks/useEloLeaguePromotionStyles.ts   (via LeaguePromotionAnimation)
//
//  Les PNG des blasons ne sont pas embarqués dans l'app Swift : le blason est
//  chargé à distance (`LeagueBadges.badgeURL`), avec le repli `shield` de la
//  source (`Ionicons name="shield-outline"`). La carte garde son rayon de 28 et
//  son fond de surface d'origine — `.duelloCard()` (rayon 14 + bord) ne
//  reproduirait pas cette géométrie.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Carte de promotion : sur-titre, blason animé, ligue atteinte, chemin
/// `from → to`, cote moyenne et bouton « Continuer ».
struct LeaguePromotionCard: View {
    let promotion: LeaguePromotion
    let animation: LeaguePromotionAnimation
    let onDismiss: () -> Void

    /// Côté du blason (`BADGE_SIZE` : 144 natif, 172 sur le web).
    private let badgeSize: CGFloat = 144

    init(promotion: LeaguePromotion,
         animation: LeaguePromotionAnimation,
         onDismiss: @escaping () -> Void) {
        self.promotion = promotion
        self.animation = animation
        self.onDismiss = onDismiss
    }

    /// Raccourci : carte pleinement révélée (`progress` = 1) ou animée.
    init(promotion: LeaguePromotion,
         progress: Double = 1,
         onDismiss: @escaping () -> Void) {
        self.init(promotion: promotion,
                  animation: LeaguePromotionAnimation(progress: progress),
                  onDismiss: onDismiss)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("NOUVELLE LIGUE")
                .font(.system(size: 11, weight: .black))
                .tracking(2.1)
                .foregroundStyle(Theme.inkSoft)
            badgeStage
            Text(promotion.to.label)
                .font(.system(size: 29, weight: .black))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            leaguePath
                .padding(.top, 12)
            Text("\(promotion.averageElo) Elo moyen")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 8)
            continueButton
                .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(maxWidth: 420)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .opacity(animation.cardOpacity)
        .scaleEffect(animation.cardScale)
        .offset(y: animation.cardOffsetY)
        .accessibilityAddTraits(.isModal)
    }

    /// Scène du blason (`badgeStage`) : étincelles et blason animés.
    private var badgeStage: some View {
        ZStack {
            sparkleLayer
            badge
                .scaleEffect(animation.badgeScale)
                .rotationEffect(.degrees(animation.badgeRotation))
        }
        .frame(width: badgeSize + 92, height: badgeSize + 52)
        .padding(.top, 10)
    }

    /// Le blason de la ligue atteinte, ou le repli bouclier de la source.
    private var badge: some View {
        Group {
            if let url = LeagueBadges.badgeURL(forLeague: promotion.to.id) {
                CachedRemoteImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
                .frame(width: badgeSize, height: badgeSize)
                .accessibilityLabel("Blason \(promotion.to.label)")
            } else {
                Image(systemName: "shield")
                    .font(.system(size: 88))
                    .foregroundStyle(Theme.ink)
                    .frame(width: badgeSize, height: badgeSize)
            }
        }
    }

    /// Les quatre étincelles (`PromotionSparkles`), aux positions d'origine.
    private var sparkleLayer: some View {
        ZStack {
            sparkleIcon(size: 22, color: Theme.ink, rotation: -16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 16, y: 18)
            sparkleIcon(size: 17, color: Theme.inkSoft, rotation: 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: -22, y: 6)
            sparkleIcon(size: 16, color: Theme.inkSoft, rotation: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 26, y: -22)
            sparkleIcon(size: 21, color: Theme.ink, rotation: -12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -10, y: -34)
        }
        .opacity(animation.sparkleOpacity)
        .scaleEffect(animation.sparkleScale)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Chemin de ligue (`LeaguePromotionPath`) : `from` → `to`.
    private var leaguePath: some View {
        HStack(spacing: 8) {
            Text(promotion.from.label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.system(size: 16))
                .foregroundStyle(Theme.inkFaint)
            Text(promotion.to.label)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .accessibilityHidden(true)
    }

    /// Bouton « Continuer » : pleine largeur, fond d'encre, texte blanc.
    private var continueButton: some View {
        Button(action: onDismiss) {
            Text("Continuer")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continuer après la promotion en ligue \(promotion.to.label)")
    }

    /// Une étincelle : `sparkles` à la taille et à l'inclinaison voulues.
    private func sparkleIcon(size: CGFloat, color: Color, rotation: Double) -> some View {
        Image(systemName: "sparkles")
            .font(.system(size: size))
            .foregroundStyle(color)
            .rotationEffect(.degrees(rotation))
    }
}
