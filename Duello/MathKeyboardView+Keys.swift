//
//  MathKeyboardView+Keys.swift
//  Duello
//
//  Grille de touches du clavier (disposition en flux) et libellés
//  d'accessibilité.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import SwiftUI

extension MathKeyboardView {
    // MARK: Grille de touches

    var keysScroll: some View {
        ScrollView(.vertical, showsIndicators: true) {
            MathKbFlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(currentSection.keys) { key in
                    keyButton(key)
                }
            }
            .padding(.bottom, 1)
        }
        .frame(maxHeight: draftOpen ? 66 : 70)
        // Le glissement horizontal change d'onglet sans bloquer le défilement
        // vertical de la grille (`simultaneousGesture`).
        .simultaneousGesture(sectionSwipeGesture)
    }

    func keyButton(_ key: MathKbKey) -> some View {
        let base = key.text
        let lowered = lowering ? MathKbScript.toScript(base, MathKbScript.subscripts) : nil
        let muted = lowering && lowered == nil
        let shown = lowered ?? base
        return Button {
            if let action = key.action {
                startTool(action)
            } else {
                insertDraftText(shown, back: key.back)
            }
        } label: {
            Text(shown)
                .font(.system(size: key.wide ? 11 : 14, weight: key.wide ? .heavy : .bold))
                .foregroundStyle(muted ? Theme.inkSoft : Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, key.wide ? 8 : 4)
                .frame(minWidth: 32, minHeight: 30)
        }
        .buttonStyle(MathKbPressStyle(
            cornerRadius: Theme.radiusSmall,
            background: muted ? Theme.surfaceMuted : Theme.surface
        ))
        .accessibilityLabel(accessibilityLabel(for: key, muted: muted))
    }

    func accessibilityLabel(for key: MathKbKey, muted: Bool) -> String {
        if let action = key.action {
            switch action {
            case .matrix:
                return "Créer une matrice"
            case .interval:
                return "Construire un intervalle de réels ou d’entiers"
            case .exponent, .limit, .integral, .sum, .product:
                if let kind = operatorKind(for: action) {
                    return "Construire \(MathKbOperatorCatalog.definition(for: kind).title.lowercased())"
                }
                return "Insérer \(key.label)"
            }
        }
        return muted ? "Insérer \(key.label), sans indice possible" : "Insérer \(key.label)"
    }
}
