//
//  DuelloBottomBar.swift
//  Duello
//
//  Barre d'onglets principale — port de `src/components/BottomNavigation.tsx`.
//
//  L'original **dessine** sa barre (React Native) : trois cellules égales, une
//  icône surmontant son libellé, l'onglet actif marqué par une pastille
//  `#000000` derrière l'icône et un libellé plus gras. La barre native d'iOS
//  (`TabView`/`tabItem`) ne sait rendre ni cette pastille, ni l'avatar du
//  profil, ni l'ordre exact des libellés : d'où ce composant maison.
//
//  Mesures et couleurs reprises telles quelles de la source : conteneur
//  `minHeight` 72, marges 8/7/`max(insets.bottom, 5)`, icône 21 (Ionicons
//  `person-outline` / `barbell-outline` / `flash-outline`), pastille 32×32
//  (rayon `radii.small` = 10), avatar 30×30 (rayon 15, bord 1,5), libellé 9
//  (700 inactif / 900 actif). L'onglet actif **interpole** son opacité et son
//  échelle avec la progression du pager (`selectedPage`, `:136-148`).
//
//  V1 (29/09/2026, écart 23#1) : l'encre de la barre est un noir franc
//  `#000000` — icône, initiale d'avatar et libellé inactifs, pastille et avatar
//  actifs (`BottomNavigation.tsx:214,299,331,336-337,356,365`, commit
//  `423b1039c`) —, au lieu de `inkSoft`/`primary` du thème partagé.
//
//  V1 (29/09/2026, écart 23#8) : le filet de séparation du haut de la barre est
//  retiré (`BottomNavigation.tsx:269-277`, commit `efce77f88` « ligne grise
//  supprimée »).
//
import SwiftUI

/// Encre de la barre d'onglets : noir franc `#000000` de la source Expo, au lieu
/// de `inkSoft`/`primary` du thème partagé. La couleur reste locale à la barre
/// (un `Theme.inkBar` global appartiendrait à `Theme.swift`, hors lot).
private let inkBar = Color(hex: 0x000000)

/// Cellule de la barre (`tab` de `BottomNavigation.tsx:39-52`).
private struct DuelloBottomTabSpec {
    let key: String
    let label: String
    let icon: String
}

struct DuelloBottomBar: View {
    @Binding var selection: Int
    /// Progression continue du pager : l'onglet actif interpole opacité/échelle.
    @ObservedObject var pager: DuelloTabPagerModel
    /// Initiale de l'avatar (onglet Profil) — `getProfileInitial` de la source.
    var avatarInitial: String = "P"
    /// Photo de profil (`photoUri`, `:167-192`) : prioritaire sur l'initiale.
    var photoUri: String? = nil
    /// Pastille rouge de notification, onglet Profil (`hasUnreadNotifications`).
    var hasUnreadNotifications: Bool = false
    /// Inset bas de la fenêtre (`Math.max(insets.bottom, 5)`, `:69`).
    var bottomSafeAreaInset: CGFloat = 0

    /// Même ordre que `BOTTOM_TAB_ORDER` et `tabs` de `BottomNavigation.tsx`.
    private static let tabs: [DuelloBottomTabSpec] = [
        DuelloBottomTabSpec(key: "account", label: "Profil", icon: "person-outline"),
        DuelloBottomTabSpec(key: "training", label: "Entraînement", icon: "barbell-outline"),
        DuelloBottomTabSpec(key: "challenges", label: "Défis", icon: "flash-outline"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.tabs.enumerated()), id: \.offset) { index, spec in
                DuelloBottomTabCell(
                    spec: spec,
                    index: index,
                    selection: $selection,
                    pager: pager,
                    avatarInitial: avatarInitial,
                    photoUri: photoUri,
                    hasUnreadNotifications: hasUnreadNotifications
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, max(bottomSafeAreaInset, 5))
        .frame(minHeight: 72)
        .background(Theme.surface, ignoresSafeAreaEdges: .bottom)
    }
}

/// Une cellule de la barre (`NavigationTab`, `BottomNavigation.tsx:114-261`).
private struct DuelloBottomTabCell: View {
    let spec: DuelloBottomTabSpec
    let index: Int
    @Binding var selection: Int
    @ObservedObject var pager: DuelloTabPagerModel
    let avatarInitial: String
    let photoUri: String?
    let hasUnreadNotifications: Bool

    /// `activateOnPressIn` : l'onglet change dès le contact (`AppPressable`).
    private static let iconSize: CGFloat = 21

    var body: some View {
        let progress = max(0, 1 - min(1, abs(pager.progress - CGFloat(index))))
        let unselected = min(1, abs(pager.progress - CGFloat(index)))
        let isSelected = selection == index

        return VStack(spacing: 4) {
            ZStack {
                if spec.key == "account" {
                    avatar(isActive: false)
                        .opacity(unselected)
                    avatar(isActive: true)
                        .opacity(progress)
                        .scaleEffect(0.94 + 0.06 * progress)
                } else {
                    symbol(isActive: false)
                        .opacity(unselected)
                    symbol(isActive: true)
                        .opacity(progress)
                        .scaleEffect(0.94 + 0.06 * progress)
                }
            }
            .frame(width: 44, height: 32)
            .overlay(alignment: .topTrailing) {
                if spec.key == "account" && hasUnreadNotifications {
                    Circle()
                        .fill(Theme.like)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                        .padding(.trailing, 5)
                }
            }

            ZStack {
                Text(spec.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(inkBar)
                    .opacity(unselected)
                Text(spec.label)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(inkBar)
                    .opacity(progress)
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        // `activateOnPressIn` (`AppPressable`) : l'onglet change dès le contact,
        // sans attendre le relâchement (`minimumDuration: 0`).
        // `perform:`/`onPressingChanged:` explicites : la surface SwiftUI
        // expose DEUX surcharges `onLongPressGesture(minimumDuration:maximumDistance:…)`
        // (celle avec `perform:onPressingChanged:` et l'ancienne avec
        // `pressing:perform:`) ; fournir `maximumDistance:` + une closure finale
        // seule est ambigu. On lève l'ambiguïté sans changer le comportement.
        .onLongPressGesture(
            minimumDuration: 0, maximumDistance: .infinity,
            perform: { selection = index }, onPressingChanged: nil
        )
        .accessibilityElement()
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityLabel(
            spec.key == "account" && hasUnreadNotifications
                ? "\(spec.label), notification non lue"
                : spec.label
        )
        .accessibilityAction { selection = index }
    }

    /// Icône Ionicons, `#000000` inactif / `white` sur pastille `#000000` actif.
    private func symbol(isActive: Bool) -> some View {
        IonIcon(name: spec.icon, size: Self.iconSize, color: isActive ? .white : inkBar)
            .frame(width: 32, height: 32)
            .background(isActive ? inkBar : Color.clear)
            .clipShape(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
            )
    }

    /// Avatar 30×30 (`avatar`, `:317-343`) : photo `cover` ou initiale.
    private func avatar(isActive: Bool) -> some View {
        Group {
            if let uri = photoUri, let url = URL(string: uri) {
                CachedRemoteImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    avatarInitialLabel(isActive: isActive)
                }
            } else {
                avatarInitialLabel(isActive: isActive)
            }
        }
        .frame(width: 30, height: 30)
        .background(isActive ? inkBar : Theme.primaryLight)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(isActive ? inkBar : Theme.border, lineWidth: 1.5)
        )
    }

    /// Initiale de l'avatar (`avatarInitial` / `activeAvatarInitial`).
    private func avatarInitialLabel(isActive: Bool) -> some View {
        Text(avatarInitial)
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(isActive ? Color.white : inkBar)
    }
}
