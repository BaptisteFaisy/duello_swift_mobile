//
//  KbSupVocabulary.swift
//  Duello
//
//  Vocabulaire détectable du clavier maths : les touches qu'un texte permet de
//  reconnaître, et de quelle façon.
//
//  Fichiers source Expo portés :
//    - `src/utils/mathKeyVocabulary.ts` — `SymbolProbe`, `WordProbe`, `Probe`,
//      `symbol`, `word`, `KEY_PROBES`, `SUGGESTIBLE_KEY_LABELS`, `WORD_PATTERN`,
//      `countSymbol`, `countMathKeyLabels`, `rankMathKeyLabels` ;
//    - `src/utils/latexToUnicode.ts` — `latexToUnicodeMath` : le comptage
//      convertit le texte en notation Unicode avant de le parcourir
//      (`LatexToUnicode.toUnicodeMath`, déjà porté).
//
//  Ce module ne dépend d'aucune donnée d'exercice, exprès : la table des
//  chapitres (`KbSupChapterAlphabet`) et la lecture de l'énoncé ouvert
//  (`KbSupSuggestions`) s'appuient sur le même comptage.
//
//  Cible : iOS 16, aucune dépendance externe.
//

import Foundation

// MARK: - Sondes

/// Ce que chaque touche laisse comme trace dans un texte (`SymbolProbe` /
/// `WordProbe`) : un symbole cherché tel quel, ou un mot cherché entier, sans
/// distinction de casse.
enum KbSupProbe: Hashable {
    case symbol(String)
    case word(String)
}

/// Une touche détectable et ses sondes (`KEY_PROBES`).
///
/// Une touche absente de la table n'est jamais proposée. Y manquent exprès les
/// caractères que le clavier du téléphone donne déjà — `+`, `=`, `(`, `<`… — qui
/// rempliraient la rangée sans rien faire gagner, ainsi que les seconds porteurs
/// d'un même symbole (`M⁻¹` à côté de `x⁻¹`), qui la rempliraient en double.
struct KbSupProbeTable {
    let label: String
    let probes: [KbSupProbe]
}

// MARK: - Vocabulaire

/// `mathKeyVocabulary.ts` : comptage et classement des libellés d'un texte.
enum KbSupVocabulary {

    /// `SUGGESTIBLE_KEY_LABELS` : libellés détectables, dans l'ordre du
    /// vocabulaire — il départage les égalités de fréquence.
    static let suggestibleKeyLabels: [String] = keyProbes.map { $0.label }

    /// Compte, libellé par libellé, ce qu'un texte contient
    /// (`countMathKeyLabels`).
    ///
    /// Le texte est d'abord converti en notation Unicode : les banques mêlent
    /// des énoncés déjà écrits en `∑` et des corrigés restés en `\sum`, et le
    /// clavier pose des `∑`. Sans cette conversion, la moitié du corpus serait
    /// muette.
    ///
    /// Les mots sont relevés en une seule passe : chercher soixante mots un par
    /// un dans un énoncé de plusieurs milliers de caractères se paierait à
    /// l'ouverture de chaque exercice.
    static func countLabels(_ source: String) -> [String: Int] {
        var counts: [String: Int] = [:]
        guard !source.isEmpty else { return counts }

        let text = LatexToUnicode.toUnicodeMath(source)
        let foundWords = words(in: text.lowercased(with: Locale(identifier: "fr-FR")))

        for entry in keyProbes {
            var total = 0
            for probe in entry.probes {
                switch probe {
                case .word(let token): total += foundWords[token] ?? 0
                case .symbol(let token): total += countSymbol(text, token)
                }
            }
            if total > 0 { counts[entry.label] = total }
        }
        return counts
    }

    /// Classe des libellés par fréquence décroissante, l'ordre du vocabulaire
    /// départageant les égalités (`rankMathKeyLabels`).
    static func rankLabels(_ counts: [String: Int]) -> [String] {
        counts.keys.sorted { left, right in
            let leftCount = counts[left] ?? 0
            let rightCount = counts[right] ?? 0
            if leftCount == rightCount {
                return (labelOrder[left] ?? Int.max) < (labelOrder[right] ?? Int.max)
            }
            return leftCount > rightCount
        }
    }

    // MARK: Table des sondes

    /// `KEY_PROBES` : ce que chaque touche laisse comme trace dans un texte,
    /// dans l'ordre de la source.
    static let keyProbes: [KbSupProbeTable] = [
        KbSupProbeTable(label: "−", probes: [.symbol("−")]),
        KbSupProbeTable(label: "×", probes: [.symbol("×")]),
        KbSupProbeTable(label: "÷", probes: [.symbol("÷")]),
        KbSupProbeTable(label: "±", probes: [.symbol("±")]),
        KbSupProbeTable(label: "·", probes: [.symbol("·")]),
        KbSupProbeTable(label: "≠", probes: [.symbol("≠")]),
        KbSupProbeTable(label: "≈", probes: [.symbol("≈")]),
        KbSupProbeTable(label: "≤", probes: [.symbol("≤")]),
        KbSupProbeTable(label: "≥", probes: [.symbol("≥")]),
        KbSupProbeTable(label: "π", probes: [.symbol("π")]),
        KbSupProbeTable(label: "√", probes: [.symbol("√")]),
        KbSupProbeTable(label: "x²", probes: [.symbol("²")]),
        KbSupProbeTable(label: "x³", probes: [.symbol("³")]),
        KbSupProbeTable(label: "x⁻¹", probes: [.symbol("⁻¹")]),
        KbSupProbeTable(label: "uₙ", probes: [.symbol("ₙ")]),
        KbSupProbeTable(label: "uₙ₊₁", probes: [.symbol("ₙ₊₁")]),
        KbSupProbeTable(label: "uₙ₋₁", probes: [.symbol("ₙ₋₁")]),
        KbSupProbeTable(label: "aₖ", probes: [.symbol("ₖ")]),
        KbSupProbeTable(label: "a₀", probes: [.symbol("₀")]),
        KbSupProbeTable(label: "a₁", probes: [.symbol("₁")]),
        KbSupProbeTable(label: "lim x→a", probes: [.symbol("lim")]),
        KbSupProbeTable(label: "→", probes: [.symbol("→")]),
        KbSupProbeTable(label: "↦", probes: [.symbol("↦")]),
        KbSupProbeTable(label: "+∞", probes: [.symbol("+∞")]),
        KbSupProbeTable(label: "−∞", probes: [.symbol("−∞")]),
        KbSupProbeTable(label: "∫ₐᵇ", probes: [.symbol("∫")]),
        KbSupProbeTable(label: "∑ₖ₌ₐᵇ", probes: [.symbol("∑")]),
        KbSupProbeTable(label: "∏ₖ₌ₐᵇ", probes: [.symbol("∏")]),
        KbSupProbeTable(label: "∂", probes: [.symbol("∂")]),
        KbSupProbeTable(label: "∇", probes: [.symbol("∇")]),
        KbSupProbeTable(label: "f′", probes: [.symbol("′")]),
        KbSupProbeTable(label: "dx", probes: [.word("dx")]),
        KbSupProbeTable(label: "dt", probes: [.word("dt")]),
        KbSupProbeTable(label: "ln", probes: [.word("ln")]),
        KbSupProbeTable(label: "exp", probes: [.word("exp")]),
        KbSupProbeTable(label: "cos", probes: [.word("cos")]),
        KbSupProbeTable(label: "sin", probes: [.word("sin")]),
        KbSupProbeTable(label: "tan", probes: [.word("tan")]),
        KbSupProbeTable(label: "∼", probes: [.symbol("∼")]),
        KbSupProbeTable(label: "≡", probes: [.symbol("≡")]),
        KbSupProbeTable(label: "ε", probes: [.symbol("ε")]),
        KbSupProbeTable(label: "δ", probes: [.symbol("δ")]),
        KbSupProbeTable(label: "Intervalle", probes: [.word("intervalle"), .word("intervalles")]),
        KbSupProbeTable(label: "∈", probes: [.symbol("∈")]),
        KbSupProbeTable(label: "∉", probes: [.symbol("∉")]),
        KbSupProbeTable(label: "⊂", probes: [.symbol("⊂")]),
        KbSupProbeTable(label: "⊆", probes: [.symbol("⊆")]),
        KbSupProbeTable(label: "∪", probes: [.symbol("∪")]),
        KbSupProbeTable(label: "∩", probes: [.symbol("∩")]),
        KbSupProbeTable(label: "⋃", probes: [.symbol("⋃")]),
        KbSupProbeTable(label: "⋂", probes: [.symbol("⋂")]),
        KbSupProbeTable(label: "∖", probes: [.symbol("∖")]),
        KbSupProbeTable(label: "∅", probes: [.symbol("∅")]),
        KbSupProbeTable(label: "ℕ", probes: [.symbol("ℕ")]),
        KbSupProbeTable(label: "ℤ", probes: [.symbol("ℤ")]),
        KbSupProbeTable(label: "ℚ", probes: [.symbol("ℚ")]),
        KbSupProbeTable(label: "ℝ", probes: [.symbol("ℝ")]),
        KbSupProbeTable(label: "ℂ", probes: [.symbol("ℂ")]),
        KbSupProbeTable(label: "card", probes: [.word("card")]),
        KbSupProbeTable(label: "sup", probes: [.word("sup")]),
        KbSupProbeTable(label: "inf", probes: [.word("inf")]),
        KbSupProbeTable(label: "max", probes: [.word("max")]),
        KbSupProbeTable(label: "min", probes: [.word("min")]),
        KbSupProbeTable(label: "ℙ", probes: [.symbol("ℙ")]),
        KbSupProbeTable(label: "𝔼", probes: [.symbol("𝔼")]),
        KbSupProbeTable(label: "𝕍", probes: [.symbol("𝕍")]),
        KbSupProbeTable(label: "σ", probes: [.symbol("σ")]),
        KbSupProbeTable(label: "Ω", probes: [.symbol("Ω")]),
        KbSupProbeTable(label: "Cov", probes: [.word("cov")]),
        KbSupProbeTable(label: "↪→", probes: [.symbol("↪")]),
        KbSupProbeTable(label: "∀", probes: [.symbol("∀")]),
        KbSupProbeTable(label: "∃", probes: [.symbol("∃")]),
        KbSupProbeTable(label: "∄", probes: [.symbol("∄")]),
        KbSupProbeTable(label: "⇒", probes: [.symbol("⇒")]),
        KbSupProbeTable(label: "⇐", probes: [.symbol("⇐")]),
        KbSupProbeTable(label: "⇔", probes: [.symbol("⇔")]),
        KbSupProbeTable(label: "¬", probes: [.symbol("¬")]),
        KbSupProbeTable(label: "∧", probes: [.symbol("∧")]),
        KbSupProbeTable(label: "∨", probes: [.symbol("∨")]),
        KbSupProbeTable(label: "⊥", probes: [.symbol("⊥")]),
        KbSupProbeTable(label: "Matrice", probes: [.word("matrice"), .word("matrices"), .word("matriciel"), .word("matricielle")]),
        KbSupProbeTable(label: "⟨ ⟩", probes: [.symbol("⟨")]),
        KbSupProbeTable(label: "‖ ‖", probes: [.symbol("‖")]),
        KbSupProbeTable(label: "⌊ ⌋", probes: [.symbol("⌊")]),
        KbSupProbeTable(label: "⌈ ⌉", probes: [.symbol("⌈")]),
        KbSupProbeTable(label: "Mᵀ", probes: [.symbol("ᵀ")]),
        KbSupProbeTable(label: "∘", probes: [.symbol("∘")]),
        KbSupProbeTable(label: "⊕", probes: [.symbol("⊕")]),
        KbSupProbeTable(label: "⊗", probes: [.symbol("⊗")]),
        KbSupProbeTable(label: "≅", probes: [.symbol("≅")]),
        KbSupProbeTable(label: "det", probes: [.word("det")]),
        KbSupProbeTable(label: "tr", probes: [.word("tr")]),
        KbSupProbeTable(label: "rg", probes: [.word("rg")]),
        KbSupProbeTable(label: "ker", probes: [.word("ker")]),
        KbSupProbeTable(label: "Im", probes: [.word("im")]),
        KbSupProbeTable(label: "dim", probes: [.word("dim")]),
        KbSupProbeTable(label: "Vect", probes: [.word("vect")]),
        KbSupProbeTable(label: "α", probes: [.symbol("α")]),
        KbSupProbeTable(label: "β", probes: [.symbol("β")]),
        KbSupProbeTable(label: "γ", probes: [.symbol("γ")]),
        KbSupProbeTable(label: "ζ", probes: [.symbol("ζ")]),
        KbSupProbeTable(label: "η", probes: [.symbol("η")]),
        KbSupProbeTable(label: "θ", probes: [.symbol("θ")]),
        KbSupProbeTable(label: "κ", probes: [.symbol("κ")]),
        KbSupProbeTable(label: "λ", probes: [.symbol("λ")]),
        KbSupProbeTable(label: "μ", probes: [.symbol("μ")]),
        KbSupProbeTable(label: "ν", probes: [.symbol("ν")]),
        KbSupProbeTable(label: "ξ", probes: [.symbol("ξ")]),
        KbSupProbeTable(label: "ρ", probes: [.symbol("ρ")]),
        KbSupProbeTable(label: "τ", probes: [.symbol("τ")]),
        KbSupProbeTable(label: "φ", probes: [.symbol("φ")]),
        KbSupProbeTable(label: "χ", probes: [.symbol("χ")]),
        KbSupProbeTable(label: "ψ", probes: [.symbol("ψ")]),
        KbSupProbeTable(label: "ω", probes: [.symbol("ω")]),
        KbSupProbeTable(label: "Γ", probes: [.symbol("Γ")]),
        KbSupProbeTable(label: "Δ", probes: [.symbol("Δ")]),
        KbSupProbeTable(label: "Θ", probes: [.symbol("Θ")]),
        KbSupProbeTable(label: "Λ", probes: [.symbol("Λ")]),
        KbSupProbeTable(label: "Ξ", probes: [.symbol("Ξ")]),
        KbSupProbeTable(label: "Π", probes: [.symbol("Π")]),
        KbSupProbeTable(label: "Σ", probes: [.symbol("Σ")]),
        KbSupProbeTable(label: "Φ", probes: [.symbol("Φ")]),
        KbSupProbeTable(label: "Ψ", probes: [.symbol("Ψ")]),

    ]

    // MARK: Outils privés

    /// Rang d'un libellé dans l'ordre du vocabulaire, pour départager deux
    /// fréquences égales.
    private static let labelOrder: [String: Int] = {
        var order: [String: Int] = [:]
        for (index, label) in suggestibleKeyLabels.enumerated() where order[label] == nil {
            order[label] = index
        }
        return order
    }()

    /// Occurrences d'un symbole (`countSymbol`), sans chevauchement et
    /// comparées littéralement — comme `indexOf`, sans repli de casse ni de
    /// diacritiques.
    private static func countSymbol(_ text: String, _ token: String) -> Int {
        guard !token.isEmpty else { return 0 }
        var count = 0
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let found = text.range(
                  of: token,
                  options: .literal,
                  range: searchStart..<text.endIndex,
                  locale: Locale(identifier: "en_US_POSIX")
              ) {
            count += 1
            searchStart = found.upperBound
        }
        return count
    }

    /// Mots d'un texte, comptés en une seule passe (`WORD_PATTERN`). Le texte
    /// est déjà en minuscules : `toLocaleLowerCase('fr-FR')`.
    private static func words(in text: String) -> [String: Int] {
        var counts: [String: Int] = [:]
        var current = ""
        for scalar in text.unicodeScalars {
            if isWordScalar(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                counts[current, default: 0] += 1
                current = ""
            }
        }
        if !current.isEmpty { counts[current, default: 0] += 1 }
        return counts
    }

    /// `WORD_PATTERN` (`/[a-zà-öø-ÿ]+/gi`) : sépare les mots latins d'un texte,
    /// accents compris, sans ramasser `÷`.
    private static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x61...0x7A, 0xE0...0xF6, 0xF8...0xFF: return true
        default: return false
        }
    }
}
