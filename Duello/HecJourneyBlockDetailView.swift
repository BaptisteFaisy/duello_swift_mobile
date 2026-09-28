import SwiftUI

/// Détail d'un bloc ouvert depuis la frise, superposé au parcours.
///
/// Porté de `openedBlockOverlay` de `src/components/HecJourney.tsx:890-972` :
/// le détail **reste au-dessus** de la frise au lieu de la remplacer, pour que
/// la scène garde son cadrage et se retrouve instantanément à la fermeture.
/// L'en-tête (`openedBlockHeader`) fait 60 de haut, remonté de 7 points, et
/// porte le retour (chevron nu, 20), le classement XP (`trophy-outline` 20) et
/// la corbeille (`trash-outline` 18, teinte `colors.danger` = `#0A0D0C`, soit
/// l'encre) — absente pour l'inscription et pour les vacances d'été.
/// L'inscription affiche le guide des cinq étapes.
struct HecJourneyBlockDetailView: View {
    let block: HecJourneySceneBlock
    /// Faux pour l'inscription et les vacances d'été, comme la source.
    let canDelete: Bool
    let onClose: () -> Void
    let onOpenRanking: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack(spacing: 0) {
            // `BackButton` : chevron nu, `iconSize` 20.
            HecJourneySheet.IconButton(
                name: "chevron-back",
                label: HecJourneyCopy.a11yBackToJourney,
                size: 20,
                tint: Theme.ink,
                width: 40,
                height: 40,
                action: onClose
            )
            Spacer(minLength: 0)
            // `openedBlockIconButton` : 40×40, radius 12, encadré.
            HecJourneySheet.IconButton(
                name: "trophy-outline",
                label: HecJourneyCopy.a11yRanking,
                size: 20,
                tint: Theme.ink,
                width: 40,
                height: 40,
                bordered: true,
                cornerRadius: 12,
                action: onOpenRanking
            )
            if canDelete {
                HecJourneySheet.IconButton(
                    name: "trash-outline",
                    label: HecJourneyCopy.a11yDeleteBlock,
                    size: 18,
                    tint: Theme.ink,
                    width: 40,
                    height: 40,
                    bordered: true,
                    cornerRadius: 12,
                    action: onDelete
                )
            }
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .offset(y: -7)
    }

    @ViewBuilder
    private var content: some View {
        if block.type == .registration {
            VStack(spacing: 0) {
                Text(HecJourneyCopy.registrationTitle)
                    .font(.system(size: 30, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(HecJourneyCopy.registrationGuide.joined(separator: "\n"))
                    .font(.system(size: 16, weight: .semibold))
                    .lineSpacing(9)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: 300, alignment: .leading)
                    .padding(.top, 24)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(28)
        } else {
            VStack(spacing: 0) {
                Text(block.type.label.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.inkFaint)
                Text(block.title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                Text(HecJourneyDates.format(block.createdAt))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
        }
    }
}
