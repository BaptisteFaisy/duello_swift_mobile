//
//  ReportSafetyMenu.swift
//  Duello
//
//  Lot « Report » — menu d'actions de sécurité d'une fiche : signaler, puis
//  bloquer.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ProfileSafetyMenu.tsx (ProfileSafetyMenu,
//                                            ProfileSafetyMenuItems)
//
//  Le menu ancré est le **voile flottant partagé** (`DropdownOverlay`), comme
//  Expo — et non plus le `Menu` natif SwiftUI (dont la présentation n'était pas
//  reproductible) : `minWidth` 164, **sans** portée de coordination
//  (`coordinationScope`), panneau **simple** (`scrollable: false`, rogné comme
//  l'`overflow: hidden` du RN). Le déclencheur noir (32 × 40) porte l'ellipse
//  verticale — ou une roue d'attente pendant le blocage — et publie son cadre
//  dans le registre (`anchorRef` du RN).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Menu d'actions de sécurité d'une fiche (`ProfileSafetyMenu.tsx`).
struct ReportSafetyMenu: View {
    /// Blocage en cours : le déclencheur montre une roue d'attente.
    let blocking: Bool
    /// Blocage indisponible : l'action « Bloquer » est désactivée.
    let disabled: Bool
    let memberName: String
    let onBlock: () -> Void
    let onReport: () -> Void

    /// `registeredDropdowns` du RN : le déclencheur s'y inscrit et le voile y lit
    /// son cadre. Une instance par menu (le menu d'actions n'a pas de portée).
    @StateObject private var registry = DropdownOverlayRegistry()
    /// `open` du RN : menu déplié ou non.
    @State private var open = false
    /// Identité du déclencheur dans `registry` (l'`anchorRef` du RN).
    private let anchorID = "report-safety-menu"

    var body: some View {
        trigger
            .dropdownAnchor(
                anchorID,
                in: registry,
                onRequestOpen: { open = true }
            )
            .overlay {
                DropdownOverlay(
                    isPresented: $open,
                    anchorID: anchorID,
                    registry: registry,
                    minWidth: 164,
                    scrollable: false
                ) {
                    menuPanel
                }
            }
    }

    /// Déclencheur (`trigger`) : bouton noir de 32 × 40 à l'ellipse verticale
    /// (roue d'attente pendant le blocage). Ouvre et referme le voile.
    private var trigger: some View {
        Button {
            open.toggle()
        } label: {
            Group {
                if blocking {
                    ProgressView().progressViewStyle(.circular).tint(Theme.surface)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.surface)
                        .rotationEffect(.degrees(90))
                }
            }
            .frame(width: 32, height: 40)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Plus d’actions pour \(memberName)")
    }

    /// `ProfileSafetyMenuItems` : « Signaler », un filet, « Bloquer ». Le panneau
    /// porte le fond et le cadre de `styles.menu` (encre, bord 1, rayon medium,
    /// ombre de carte, `overflow: hidden`).
    private var menuPanel: some View {
        VStack(spacing: 0) {
            menuItem(
                title: "Signaler",
                icon: "flag",
                accessibilityLabel: "Signaler \(memberName)",
                enabled: true,
                busy: false,
                action: onReport
            )

            // `divider` : filet `rgba(255, 255, 255, 0.18)`.
            Rectangle()
                .fill(Theme.surface.opacity(0.18))
                .frame(height: 0.5)

            menuItem(
                title: "Bloquer",
                icon: "hand.raised",
                accessibilityLabel: "Bloquer \(memberName)",
                enabled: !disabled,
                busy: blocking,
                action: onBlock
            )
        }
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.ink, lineWidth: 1)
        )
        .duelloShadow()
    }

    /// `item` du RN : ligne de 44 pt minimum, écart 9, marges horizontales 14,
    /// icône blanche de 17 (ou roue d'attente), libellé blanc 12 / `'800'`. Une
    /// action désactivée passe à 50 % d'opacité (`styles.disabled`).
    private func menuItem(
        title: String,
        icon: String,
        accessibilityLabel: String,
        enabled: Bool,
        busy: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if busy {
                    ProgressView().progressViewStyle(.circular).tint(Theme.surface)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.surface)
                }
                Text(title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.surface)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .accessibilityLabel(accessibilityLabel)
    }
}
