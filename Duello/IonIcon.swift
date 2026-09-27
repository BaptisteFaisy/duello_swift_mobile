//
//  IonIcon.swift
//  Duello
//
//  Icône Ionicons rendue avec la police embarquée (`Ionicons.ttf`) : les glyphes
//  sont IDENTIQUES à la source React Native (`@expo/vector-icons`), au lieu d'un
//  substitut SF Symbol approximatif. À utiliser partout où la source rend
//  `<Ionicons name=… size=… color=… />`.
//
//  Nom logique : exactement celui du RN (`person-outline`, `barbell-outline`,
//  `flash-outline`, `chevron-forward`, …), table dans `IoniconsGlyphs.map`.
//
import SwiftUI

/// Vue d'une icône Ionicons (police embarquée, glyphes du RN).
struct IonIcon: View {
    /// Nom logique Ionicons, tel qu'écrit dans la source RN.
    let name: String
    /// Taille en points (équivaut à `size` de `@expo/vector-icons`).
    var size: CGFloat = 24
    /// Couleur du glyphe (équivaut à `color`).
    var color: Color = .primary

    var body: some View {
        Text(IoniconsGlyphs.character(name) ?? "")
            .font(.custom("Ionicons", size: size))
            .foregroundColor(color)
    }
}

extension IonIcon {
    /// Icône colorée depuis un entier hexadécimal `0xRRGGBB` (couleurs de
    /// `theme.ts` de la source, souvent écrites en littéral hex).
    init(name: String, size: CGFloat = 24, hex: Int) {
        self.init(name: name, size: size, color: Color(hex: hex))
    }
}
