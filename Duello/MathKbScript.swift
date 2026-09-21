//
//  MathKbScript.swift
//  Duello
//
//  Écriture en exposant / en indice (`SUPERSCRIPTS`, `SUBSCRIPTS`, `toScript`
//  de `utils/mathLayout.ts`).
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import Foundation

// MARK: - Écriture en exposant / en indice

/// Tables et rendu des scripts Unicode (`SUPERSCRIPTS`, `SUBSCRIPTS`,
/// `toScript` de `utils/mathLayout.ts`).
enum MathKbScript {

    static let superscripts: [Character: String] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ",
        "j": "ʲ", "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ", "p": "ᵖ", "r": "ʳ", "s": "ˢ",
        "t": "ᵗ", "u": "ᵘ", "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
        "T": "ᵀ", "N": "ᴺ",
    ]

    static let subscripts: [Character: String] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "−": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ",
        "n": "ₙ", "o": "ₒ", "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ",
    ]

    /// Un exposant tient en quelques caractères ; au-delà, c'est de la prose.
    private static let maxScriptLength = 4

    /// Rend la mise en Unicode, ou `nil` si un seul caractère résiste ou si le
    /// texte dépasse `maxScriptLength` (`toScript`).
    static func toScript(_ text: String, _ table: [Character: String]) -> String? {
        guard !text.isEmpty, text.count <= maxScriptLength else { return nil }
        return render(text, table)
    }

    /// Même rendu, sans limite de longueur : c'est celui des bornes
    /// d'opérateur (`enScript` de `mathOperator.ts`).
    static func toScriptUnbounded(_ text: String, _ table: [Character: String]) -> String? {
        guard !text.isEmpty else { return nil }
        return render(text, table)
    }

    private static func render(_ text: String, _ table: [Character: String]) -> String? {
        var rendu = ""
        for caractere in text {
            guard let equivalent = table[caractere] else { return nil }
            rendu += equivalent
        }
        return rendu.isEmpty ? nil : rendu
    }
}
