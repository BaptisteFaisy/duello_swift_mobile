//
//  KbSupSuggestionsRow.swift
//  Duello
//
//  Rangée de suggestions « propres à l'exercice », posée en tête du clavier
//  maths.
//
//  Fichiers source Expo portés :
//    - `src/components/MathKeyboard.tsx` — la rangée `pinnedKeys` (défilement
//      horizontal, `styles.suggestions`, touche en variante `styles.keySuggested`
//      : bord et fond d'accent), le rendu de touche `renderKey` (mode indice
//      `toScript(text, SUBSCRIPTS)`) et les libellés d'accessibilité `named` ;
//    - `src/utils/mathOperator.ts` — les libellés d'accessibilité des cinq
//      opérateurs guidés ;
//    - `src/utils/mathKeySuggestions.ts` — le calcul de la rangée, porté dans
//      `KbSupSuggestions`.
//
//  `MathKeyboardView` (lot 4) ne porte pas cette rangée : son contrat
//  d'intégration ne transporte pas les suggestions. Cette vue la met à la
//  disposition de l'écran parent, qui la pose juste au-dessus du clavier et
//  masque la rangée en passant une liste vide (comme la source, qui n'affiche
//  rien quand `pinnedKeys` est vide) :
//
//  ```swift
//  KbSupSuggestionsRow(
//      keys: KbSupSuggestions.suggest(KbSupInput(statement: énoncé, chapterId: chapitre)),
//      onInsert: { texte, recul in réponse.insert(texte, back: recul) },
//      onAction: { action in ouvrirL’Outil(action) }
//  )
//  ```
//
//  Cible : iOS 16, aucune dépendance externe.
//

import SwiftUI

/// Rangée horizontale des touches épinglées pour le contenu ouvert.
struct KbSupSuggestionsRow: View {

    /// Touches calculées par `KbSupSuggestions.suggest(_:)`.
    let keys: [MathKbKey]
    /// Insère la touche au curseur ; `back` recule ensuite le curseur d'autant.
    let onInsert: (String, Int) -> Void
    /// Ouvre l'outil guidé d'une touche d'action. Sans lui, les touches
    /// d'action ne sont pas proposées : une rangée ne doit pas promettre un
    /// outil que l'écran ne sait pas ouvrir.
    var onAction: ((MathKbAction) -> Void)? = nil
    /// Mode indice du clavier : les touches s'écrivent alors en forme basse,
    /// comme dans l'onglet « Base ».
    var lowering: Bool = false

    var body: some View {
        Group {
            if available.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(available) { key in
                            button(key)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    /// Les touches réellement proposées : celles dont l'action sait s'ouvrir.
    private var available: [MathKbKey] {
        keys.filter { $0.action == nil || onAction != nil }
    }

    private func button(_ key: MathKbKey) -> some View {
        Button {
            if let action = key.action {
                onAction?(action)
            } else {
                onInsert(text(for: key), key.back)
            }
        } label: {
            Text(shown(key))
                .font(.system(size: key.wide ? 11 : 14, weight: key.wide ? .heavy : .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, key.wide ? 8 : 4)
                .frame(minWidth: 32, minHeight: 30)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.primary, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    /// Le libellé affiché : la forme basse en mode indice, le libellé sinon.
    private func shown(_ key: MathKbKey) -> String {
        guard lowering else { return key.label }
        return MathKbScript.toScript(text(for: key), MathKbScript.subscripts) ?? key.label
    }

    /// Le texte que la touche insère quand elle n'ouvre pas d'outil.
    private func text(for key: MathKbKey) -> String {
        key.action == nil ? key.text : ""
    }

    /// Libellés d'accessibilité, mot pour mot de la source : le nom de l'outil
    /// (`named`), suivi de la mention qui distingue cette rangée de la même
    /// touche, plus bas dans son onglet.
    private func accessibilityLabel(for key: MathKbKey) -> String {
        "\(named(key) ?? "Insérer \(key.label)"), proposé pour cet exercice"
    }

    /// `named` : le nom d'un outil guidé, ou rien pour une touche d'insertion.
    private func named(_ key: MathKbKey) -> String? {
        guard let action = key.action else { return nil }
        switch action {
        case .matrix: return "Créer une matrice"
        case .interval: return "Construire un intervalle de réels ou d’entiers"
        case .exponent: return "Construire un exposant libre"
        case .limit: return "Construire une limite avec sa variable et sa valeur"
        case .integral: return "Construire une intégrale avec ses deux bornes"
        case .sum: return "Construire une somme avec son indice et ses bornes"
        case .product: return "Construire un produit avec son indice et ses bornes"
        }
    }
}
