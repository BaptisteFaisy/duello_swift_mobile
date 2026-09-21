//
//  MathKbKeyboardModel.swift
//  Duello
//
//  Modèle du clavier mathématique : mode de saisie, action d'outil, nature
//  d'opérateur, touche et section (`MathKey`, `MathSection` de
//  `utils/mathKeySections.ts`).
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import Foundation

// MARK: - Mode de saisie

/// Mode du clavier, repris de `ExerciseAnswerInputMode` côté Expo (`'math'` /
/// `'python'`). `text` privilégie les raccourcis de code (onglet « Python »
/// en tête) ; `math` ouvre sur « Base ».
enum MathKbMode: Hashable {
    case math
    case text
}

// MARK: - Outils guidés

/// Outil ouvert par une touche au lieu d'une insertion : les trois
/// constructions guidées (`'matrix'`, `'interval'`) et les opérateurs
/// mathématiques (`MathOperatorKind`). Cf. `MathKeyAction` de la source.
enum MathKbAction: Hashable {
    case matrix
    case interval
    case exponent
    case limit
    case integral
    case sum
    case product
}

/// Les cinq opérateurs à champs de `mathOperator.ts`.
enum MathKbOperatorKind: String, CaseIterable, Hashable {
    case exponent
    case limit
    case integral
    case sum
    case product

    /// L'outil correspondant, pour `MathKbKey.action`.
    var action: MathKbAction {
        switch self {
        case .exponent: return .exponent
        case .limit: return .limit
        case .integral: return .integral
        case .sum: return .sum
        case .product: return .product
        }
    }
}

// MARK: - Définition d'une touche

/// Une touche du clavier — `MathKey` de `utils/mathKeySections.ts`.
struct MathKbKey: Identifiable, Hashable {
    /// Libellé affiché sur la touche.
    let label: String
    /// Texte inséré s'il diffère du libellé.
    var insert: String? = nil
    /// Recul du curseur après insertion, pour se placer entre les délimiteurs.
    var back: Int = 0
    /// Touche à libellé long : elle occupe plus de largeur.
    var wide: Bool = false
    /// Ouvre un outil du clavier au lieu d'insérer le libellé.
    var action: MathKbAction? = nil

    /// Libellé unique dans une section : sert d'identité à la liste.
    var id: String { label }

    /// Texte réellement inséré quand la touche n'ouvre pas d'outil.
    var text: String { insert ?? label }
}

/// Un onglet du clavier et ses touches — `MathSection` de la source.
struct MathKbSection: Identifiable, Hashable {
    let id: String
    let label: String
    let keys: [MathKbKey]
}
