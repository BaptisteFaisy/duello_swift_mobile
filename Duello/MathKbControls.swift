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

// MARK: - Boutons du clavier

/// Touche de la rangée d'actions (espace, retour, effacer) et du mode indice.
struct MathKbActionKey: View {
    let accessibility: String
    var label: String? = nil
    var systemImage: String? = nil
    var highlighted: Bool = false
    var labelSize: CGFloat = 11
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: labelSize, weight: .heavy))
                }
            }
            .foregroundStyle(highlighted ? Theme.surface : Theme.ink)
            .frame(minWidth: 42, minHeight: 30)
            .padding(.horizontal, 8)
            .background(highlighted ? Theme.ink : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}

/// Petit bouton d'éditeur : navigation entre champs, secondaire, primaire.
struct MathKbMiniButton: View {
    var systemImage: String? = nil
    var label: String? = nil
    var wide: Bool = false
    var prominent: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                } else if let label = label {
                    Text(label)
                        .font(.system(size: 8, weight: prominent ? .black : .heavy))
                }
            }
            .foregroundStyle(prominent ? Theme.surface : Theme.ink)
            .frame(minWidth: systemImage != nil ? 27 : 0, minHeight: 26)
            .padding(.horizontal, wide ? 9 : 6)
            .background(prominent ? Theme.ink : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(prominent ? Theme.ink : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
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
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.48)
    }
}
