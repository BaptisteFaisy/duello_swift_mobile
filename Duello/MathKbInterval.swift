//
//  MathKbInterval.swift
//  Duello
//
//  Intervalle : nature (réels / entiers), crochets et rendu
//  (`utils/mathInterval.ts`).
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import Foundation

// MARK: - Intervalles

/// Nature de l'intervalle : crochets simples pour les réels, doubles pour les
/// entiers (`IntervalKind`).
enum MathKbIntervalKind: String, CaseIterable, Hashable {
    case real
    case integer

    var label: String {
        switch self {
        case .real: return "Réels"
        case .integer: return "Entiers"
        }
    }
}

/// Un intervalle prêt à être rendu (`MathInterval` de `utils/mathInterval.ts`).
struct MathKbInterval {
    var kind: MathKbIntervalKind = .real
    var lower: String = ""
    var upper: String = ""
    var lowerClosed: Bool = true
    var upperClosed: Bool = true

    /// Une borne infinie n'est jamais atteinte (`isInfiniteBound`).
    static func isInfinite(_ value: String) -> Bool {
        value.contains("∞")
    }

    /// Crochets effectivement écrits de chaque côté (`intervalBrackets`) :
    /// une borne infinie ouvre son crochet quoi qu'ait choisi l'élève.
    var brackets: (lower: String, upper: String) {
        let lowerClosed = self.lowerClosed && !Self.isInfinite(lower)
        let upperClosed = self.upperClosed && !Self.isInfinite(upper)
        switch kind {
        case .real:
            return (lowerClosed ? "[" : "]", upperClosed ? "]" : "[")
        case .integer:
            return (lowerClosed ? "⟦" : "⟧", upperClosed ? "⟧" : "⟦")
        }
    }

    /// `[0, 1]`, `]−∞, 0]`, `⟦1, n⟧`… (`formatInterval`).
    var formatted: String {
        let left = lower.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = upper.trimmingCharacters(in: .whitespacesAndNewlines)
        let pair = brackets
        return "\(pair.lower)\(left), \(right)\(pair.upper)"
    }

    /// Aperçu : tant qu'une borne manque, `a` et `b` tiennent sa place plutôt
    /// que de laisser un trou dans l'intervalle.
    var preview: String {
        var copie = self
        if copie.lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copie.lower = "a"
        }
        if copie.upper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copie.upper = "b"
        }
        return copie.formatted
    }
}
