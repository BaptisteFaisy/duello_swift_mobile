import SwiftUI

/// Barre d'onglets principale — port de `src/components/BottomNavigation.tsx`.
///
/// L'original **dessine** sa barre (React Native) : trois cellules égales, une
/// icône surmontant son libellé, l'onglet actif marqué par une pastille
/// `primary` derrière l'icône et un libellé plus gras. La barre native d'iOS
/// (`TabView`/`tabItem`) ne sait rendre ni cette pastille, ni l'avatar du
/// profil, ni l'ordre exact des libellés : d'où ce composant maison.
///
/// Mesures et couleurs reprises telles quelles de la source : conteneur
/// `minHeight` 72, marges 8/7/5, icône 21, pastille 32×32 (rayon `radii.small`
/// = 10), avatar 30×30 (rayon 15, bord 1,5), libellé 9 (700 inactif / 900 actif).
struct DuelloBottomBar: View {
    @Binding var selection: Int
    /// Initiale de l'avatar (onglet Profil) — `getProfileInitial` de la source.
    var avatarInitial: String = "P"
    /// Pastille rouge de notification, onglet Profil (`hasUnreadNotifications`).
    var hasUnreadNotifications: Bool = false

    private struct TabItem {
        let label: String
        let symbol: String
    }

    /// Même ordre que `BOTTOM_TAB_ORDER` et `tabs` de `BottomNavigation.tsx`.
    private static let tabs: [TabItem] = [
        TabItem(label: "Profil", symbol: "person"),
        TabItem(label: "Entraînement", symbol: "dumbbell"),
        TabItem(label: "Défis", symbol: "bolt"),
    ]

    private static let iconSize: CGFloat = 21

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.tabs.enumerated()), id: \.offset) { index, tab in
                cell(tab, index: index)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 5)
        .frame(minHeight: 72)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 0.5)
        }
    }

    private func cell(_ tab: TabItem, index: Int) -> some View {
        let isActive = selection == index
        return Button {
            selection = index
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if index == 0 {
                        avatar(isActive: isActive)
                    } else {
                        symbol(tab.symbol, isActive: isActive)
                    }
                }
                .frame(width: 44, height: 32)

                Text(tab.label)
                    .font(.system(size: 9, weight: isActive ? .black : .bold))
                    .foregroundStyle(isActive ? Theme.primary : Theme.inkSoft)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private func symbol(_ name: String, isActive: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: Self.iconSize, weight: .regular))
            .foregroundStyle(isActive ? Color.white : Theme.inkSoft)
            .frame(width: 32, height: 32)
            .background(isActive ? Theme.primary : Color.clear)
            .clipShape(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
            )
    }

    private func avatar(isActive: Bool) -> some View {
        Text(avatarInitial)
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(isActive ? Color.white : Theme.inkSoft)
            .frame(width: 30, height: 30)
            .background(isActive ? Theme.primary : Theme.primaryLight)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(isActive ? Theme.primary : Theme.border, lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if hasUnreadNotifications {
                    Circle()
                        .fill(Theme.like)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                        .offset(x: 5)
                }
            }
    }
}
