//
//  MathKbOperatorCatalog.swift
//  Duello
//
//  Opérateurs guidés : définitions, complétude et rendu Unicode
//  (`utils/mathOperator.ts`).
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import Foundation

// MARK: - Opérateurs guidés

/// Un champ obligatoire d'un opérateur guidé (`MathOperatorFieldDefinition`).
struct MathKbOperatorField {
    let id: String
    let label: String
    let placeholder: String
    /// Borne qui peut être infinie : l'éditeur pose alors `−∞` / `+∞` sur place.
    let infinite: Bool
}

/// La définition complète d'un opérateur guidé (`MathOperatorDefinition`).
struct MathKbOperatorDefinition {
    let kind: MathKbOperatorKind
    let keyLabel: String
    let title: String
    let hint: String
    let fields: [MathKbOperatorField]
}

/// Définitions, complétude et rendu Unicode des opérateurs guidés.
enum MathKbOperatorCatalog {

    static func definition(for kind: MathKbOperatorKind) -> MathKbOperatorDefinition {
        switch kind {
        case .exponent: return exponentDefinition
        case .limit: return limitDefinition
        case .integral: return integralDefinition
        case .sum: return sumDefinition
        case .product: return productDefinition
        }
    }

    private static let exponentDefinition = MathKbOperatorDefinition(
        kind: .exponent,
        keyLabel: "x^…",
        title: "Exposant libre",
        hint: "Écris d’abord la base, puis renseigne ici son exposant.",
        fields: [
            MathKbOperatorField(id: "exponent", label: "Exposant", placeholder: "n+1", infinite: false),
        ]
    )

    private static let limitDefinition = MathKbOperatorDefinition(
        kind: .limit,
        keyLabel: "lim x→a",
        title: "Limite",
        hint: "Renseigne la variable et la valeur vers laquelle elle tend.",
        fields: [
            MathKbOperatorField(id: "variable", label: "Variable", placeholder: "x", infinite: false),
            MathKbOperatorField(id: "target", label: "Tend vers", placeholder: "+∞", infinite: true),
        ]
    )

    private static let integralDefinition = MathKbOperatorDefinition(
        kind: .integral,
        keyLabel: "∫ₐᵇ",
        title: "Intégrale bornée",
        hint: "Renseigne les deux bornes avant de saisir l’intégrande.",
        fields: [
            MathKbOperatorField(id: "lower", label: "Borne basse", placeholder: "0", infinite: true),
            MathKbOperatorField(id: "upper", label: "Borne haute", placeholder: "1", infinite: true),
        ]
    )

    private static let sumDefinition = MathKbOperatorDefinition(
        kind: .sum,
        keyLabel: "∑ₖ₌ₐᵇ",
        title: "Somme",
        hint: "Renseigne l’indice, sa valeur de départ et la borne supérieure.",
        fields: [
            MathKbOperatorField(id: "index", label: "Indice", placeholder: "k", infinite: false),
            MathKbOperatorField(id: "lower", label: "Départ", placeholder: "1", infinite: true),
            MathKbOperatorField(id: "upper", label: "Arrivée", placeholder: "n", infinite: true),
        ]
    )

    private static let productDefinition = MathKbOperatorDefinition(
        kind: .product,
        keyLabel: "∏ₖ₌ₐᵇ",
        title: "Produit",
        hint: "Renseigne l’indice, sa valeur de départ et la borne supérieure.",
        fields: [
            MathKbOperatorField(id: "index", label: "Indice", placeholder: "k", infinite: false),
            MathKbOperatorField(id: "lower", label: "Départ", placeholder: "1", infinite: true),
            MathKbOperatorField(id: "upper", label: "Arrivée", placeholder: "n", infinite: true),
        ]
    )

    /// Tous les champs obligatoires sont remplis (`isMathOperatorComplete`).
    static func isComplete(kind: MathKbOperatorKind, values: [String: String]) -> Bool {
        definition(for: kind).fields.allSatisfy { field in
            !normalized(values[field.id]).isEmpty
        }
    }

    /// Rendu Unicode de l'opérateur, ou `nil` tant qu'un champ manque
    /// (`formatMathOperator`). Les bornes simples utilisent les vrais exposants
    /// et indices (`∑ₖ₌₁ⁿ`) ; lorsqu'Unicode ne sait pas représenter un
    /// caractère, la notation explicite reste non ambiguë (`∫_(-∞)^(+∞)`).
    static func format(kind: MathKbOperatorKind, values: [String: String]) -> String? {
        guard isComplete(kind: kind, values: values) else { return nil }

        if kind == .exponent {
            let exponent = compact(values["exponent"])
            return MathKbScript.toScriptUnbounded(exponent, MathKbScript.superscripts)
                ?? "^(\(exponent))"
        }

        if kind == .limit {
            let variable = compact(values["variable"])
            let target = compact(values["target"])
            return "lim_(\(variable)→\(target)) "
        }

        let lower: String
        if kind == .sum || kind == .product {
            lower = "\(compact(values["index"]))=\(compact(values["lower"]))"
        } else {
            lower = compact(values["lower"])
        }
        let symbol: String
        switch kind {
        case .sum: symbol = "∑"
        case .product: symbol = "∏"
        default: symbol = "∫"
        }
        let borneBasse = scriptedBound(lower, marker: "_", table: MathKbScript.subscripts)
        let borneHaute = scriptedBound(values["upper"], marker: "^", table: MathKbScript.superscripts)
        return "\(symbol)\(borneBasse)\(borneHaute) "
    }

    /// Aperçu affiché dans l'éditeur : la forme insérée dès que l'opérateur est
    /// complet, sinon son libellé de touche (`mathOperatorPreview`).
    static func preview(kind: MathKbOperatorKind, values: [String: String]) -> String {
        guard let formatted = format(kind: kind, values: values) else {
            return definition(for: kind).keyLabel
        }
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        return kind == .exponent ? "x\(trimmed)" : trimmed
    }

    /// Une borne : les vrais caractères Unicode si tous existent, sinon la
    /// notation explicite `_(…)` / `^(…)` (`borne` de `mathOperator.ts`).
    private static func scriptedBound(
        _ value: String?,
        marker: String,
        table: [Character: String]
    ) -> String {
        let compacted = compact(value)
        return MathKbScript.toScriptUnbounded(compacted, table) ?? "\(marker)(\(compacted))"
    }

    /// Espaces multiples repliés en une espace, extrémités retirées
    /// (`valeurPropre`).
    private static func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// Forme sans aucun blanc (`valeurCompacte`).
    private static func compact(_ value: String?) -> String {
        normalized(value).filter { !$0.isWhitespace }
    }
}
