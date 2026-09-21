import SwiftUI

/// Détail d'un bloc ouvert depuis la frise, superposé au parcours.
///
/// Porté de `openedBlockOverlay` de `src/components/HecJourney.tsx` : le détail
/// **reste au-dessus** de la frise au lieu de la remplacer, pour que la scène
/// garde son cadrage et se retrouve instantanément à la fermeture. L'en-tête
/// porte le retour, le classement XP et la corbeille (absente pour
/// l'inscription et pour les vacances d'été) ; l'inscription affiche le guide
/// des cinq étapes.
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
            Spacer(minLength: 0)
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HecJourneySheet.IconButton(
                systemName: "chevron.left",
                label: HecJourneyCopy.a11yBackToJourney,
                size: 20,
                tint: Theme.ink,
                frame: 40,
                action: onClose
            )
            Spacer(minLength: 0)
            HecJourneySheet.IconButton(
                systemName: "trophy",
                label: HecJourneyCopy.a11yRanking,
                size: 20,
                tint: Theme.ink,
                frame: 40,
                action: onOpenRanking
            )
            if canDelete {
                HecJourneySheet.IconButton(
                    systemName: "trash",
                    label: HecJourneyCopy.a11yDeleteBlock,
                    size: 18,
                    tint: Theme.like,
                    frame: 40,
                    action: onDelete
                )
            }
        }
        .padding(.horizontal, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if block.type == .registration {
            VStack(spacing: 10) {
                Text(HecJourneyCopy.registrationTitle)
                    .font(.system(size: 13, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(HecJourneyCopy.registrationGuide, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(block.type.label.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Theme.inkFaint)
                Text(block.title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(HecJourneyDates.format(block.createdAt))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}
