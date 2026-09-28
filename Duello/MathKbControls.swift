//
//  MathKbControls.swift
//  Duello
//
//  Petits contrôles du clavier : touche de la rangée d'actions, mini-bouton
//  d'éditeur, compteur de dimension.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import SwiftUI

// MARK: - Appui des touches

/// Appui d'une touche du clavier : fond `primaryLight` pendant l'appui
/// (`styles.keyPressed` du RN), chrome `surface`/`border` au repos.
struct MathKbPressStyle: ButtonStyle {
    var cornerRadius: CGFloat = Theme.radiusSmall
    var background: Color = Theme.surface
    var border: Color = Theme.border
    var pressedBackground: Color = Theme.primaryLight
    /// Onglets : la forme est une capsule (`radii.pill` du RN).
    var capsule: Bool = false

    private var shape: AnyShape {
        capsule ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? pressedBackground : background)
            .clipShape(shape)
            .overlay(shape.stroke(border, lineWidth: 1))
    }
}

// MARK: - Boutons du clavier

/// Touche de la rangée d'actions (espace, retour, effacer) et du mode indice.
struct MathKbActionKey: View {
    let accessibility: String
    var label: String? = nil
    var systemImage: String? = nil
    /// Icône Ionicons (portage RN) : prioritaire sur `systemImage`.
    var ionIcon: String? = nil
    /// Taille de l'icône Ionicons (`size` du RN).
    var iconSize: CGFloat = 17
    var highlighted: Bool = false
    var labelSize: CGFloat = 11
    /// Couleur du libellé hors touche active (`actionText` du RN = inkSoft).
    var labelColor: Color = Theme.inkSoft
    /// Touche extensible : occupe la largeur restante (`spaceKey` `flex:1`).
    var expandable: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let ionIcon = ionIcon {
                    IonIcon(name: ionIcon, size: iconSize, color: highlighted ? Theme.surface : Theme.ink)
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(highlighted ? Theme.surface : Theme.ink)
                } else if let label = label {
                    Text(label)
                        .font(.system(size: labelSize, weight: .heavy))
                        .foregroundStyle(highlighted ? Theme.surface : labelColor)
                }
            }
            .frame(minWidth: 42, minHeight: 30)
            .frame(maxWidth: expandable ? .infinity : nil)
            .padding(.horizontal, 8)
        }
        .buttonStyle(MathKbPressStyle(
            cornerRadius: Theme.radiusSmall,
            background: highlighted ? Theme.primary : Theme.surface,
            border: highlighted ? Theme.primary : Theme.border
        ))
        .accessibilityLabel(accessibility)
    }
}

/// Petit bouton d'éditeur : navigation entre champs, secondaire, primaire.
struct MathKbMiniButton: View {
    var systemImage: String? = nil
    /// Icône Ionicons (portage RN) : prioritaire sur `systemImage`.
    var ionIcon: String? = nil
    /// Taille de l'icône Ionicons (`size` du RN).
    var iconSize: CGFloat = 14
    var label: String? = nil
    var wide: Bool = false
    var prominent: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let ionIcon = ionIcon {
                    IonIcon(name: ionIcon, size: iconSize, color: Theme.ink)
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(prominent ? Theme.surface : Theme.ink)
                } else if let label = label {
                    Text(label)
                        .font(.system(size: 8, weight: prominent ? .black : .heavy))
                        .foregroundStyle(prominent ? Theme.surface : Theme.inkSoft)
                }
            }
            .frame(minWidth: (ionIcon != nil || systemImage != nil) ? 27 : 0, minHeight: 26)
            .padding(.horizontal, wide ? 9 : 8)
        }
        .buttonStyle(MathKbPressStyle(cornerRadius: 8, background: fillColor, border: strokeColor))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
    }

    /// Fond selon la variante RN : navigation `surfaceMuted`, insérer `primary`,
    /// annuler `surface`.
    private var fillColor: Color {
        if ionIcon != nil { return Theme.surfaceMuted }
        return prominent ? Theme.primary : Theme.surface
    }

    /// Bord selon la variante RN : navigation et annuler en `border`, insérer
    /// en `primary`.
    private var strokeColor: Color {
        if ionIcon != nil { return Theme.border }
        return prominent ? Theme.primary : Theme.border
    }
}

/// Compteur d'une dimension de matrice : libellé, `−`, valeur, `+`.
struct MathKbStepper: View {
    let label: String
    let value: Int
    let canDecrease: Bool
    let canIncrease: Bool
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 43, alignment: .leading)
            button("−", enabled: canDecrease, action: decrease)
            Text("\(value)")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 13)
            button("+", enabled: canIncrease, action: increase)
        }
    }

    func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(width: 24, height: 22)
        }
        .buttonStyle(MathKbPressStyle(cornerRadius: 7, background: Theme.surfaceMuted))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
    }
}
