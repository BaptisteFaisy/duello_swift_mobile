//
//  Ui2SettingsRow.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/SettingsCategoryRow.tsx (`SettingsCategoryRow`)
//
//  Ligne d'accès aux catégories des réglages : pictogramme à gauche (symbole SF
//  ou image, comme `iconSource` de la source), libellé au centre, chevron à
//  droite. Cible iOS 16.
//
import SwiftUI

/// Ligne de catégorie des réglages (`SettingsCategoryRow.tsx`).
///
/// Hauteur minimale de 60 et libellé en gras, comme la source.
struct Ui2SettingsRow: View {
    /// Symbole SF affiché à gauche (`icon` Ionicons de la source).
    var icon: String? = nil
    /// Image affichée à la place du symbole (`iconSource` de la source).
    var iconImage: Image? = nil
    /// Taille du pictogramme (`iconSize` de la source).
    var iconSize: CGFloat = 22
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                iconView
                Text(label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 60)
            .background(Theme.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir \(label)")
    }

    /// Pictogramme : image si fournie, sinon symbole SF.
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            if let iconImage {
                iconImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .regular))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: 34, height: 34)
    }
}
