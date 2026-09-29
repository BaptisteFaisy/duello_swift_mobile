//
//  MathKbDrafts.swift
//  Duello
//
//  Brouillons des outils guidés (matrice, opérateur, intervalle) : l'état
//  d'édition manipulé par les éditeurs du clavier.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//
//  PARITÉ (2026-09-29) — `replacement` des brouillons (`MatrixDraft`,
//  `MathOperatorDraft`, `MathKeyboard.tsx:126,139`) : la plage de la
//  construction visée dans la réponse, pour l'édition d'un symbole déjà écrit
//  (« Modifier … »). Posée par l'hôte à l'ouverture de l'éditeur ; `nil` =
//  l'éditeur insère une construction neuve.
//

import Foundation

// MARK: - Brouillons des outils guidés

/// Brouillon de l'éditeur de matrice (`MatrixDraft`).
struct MathKbMatrixDraft {
    var rows: Int
    var columns: Int
    var cells: [String]
    var active: Int
    var delimiter: MathKbMatrixDelimiter
    /// Plage de la matrice visée dans la réponse (`MatrixDraft.replacement`).
    /// `nil` : l'éditeur insère une nouvelle matrice.
    var replacement: StmtTextSelection? = nil

    /// Deux lignes, deux colonnes, délimiteur carré — valeurs par défaut de
    /// `createMatrixDraft` quand aucune matrice n'est sélectionnée.
    static func initial() -> MathKbMatrixDraft {
        MathKbMatrixDraft(
            rows: 2,
            columns: 2,
            cells: ["", "", "", ""],
            active: 0,
            delimiter: .square
        )
    }

    /// Toutes les cases sont remplies (`matrixComplete`).
    var isComplete: Bool {
        cells.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Redimensionne en conservant les cases qui restent dans la nouvelle
    /// grille et en reculant le curseur dans les bornes (`resizeMatrixDraft`).
    mutating func resize(rows newRows: Int, columns newColumns: Int) {
        let nextRows = min(max(newRows, MathKbLayout.matrixMinSize), MathKbLayout.matrixMaxSize)
        let nextColumns = min(max(newColumns, MathKbLayout.matrixMinSize), MathKbLayout.matrixMaxSize)
        guard nextRows != rows || nextColumns != columns else { return }

        var nextCells: [String] = []
        nextCells.reserveCapacity(nextRows * nextColumns)
        for index in 0..<(nextRows * nextColumns) {
            let row = index / nextColumns
            let column = index % nextColumns
            if row < rows, column < columns, row * columns + column < cells.count {
                nextCells.append(cells[row * columns + column])
            } else {
                nextCells.append("")
            }
        }

        let activeRow = min(active / max(columns, 1), nextRows - 1)
        let activeColumn = min(active % max(columns, 1), nextColumns - 1)

        rows = nextRows
        columns = nextColumns
        cells = nextCells
        active = activeRow * nextColumns + activeColumn
    }

    /// La grille telle qu'attendue par le formateur.
    var grid: [[String]] {
        (0..<rows).map { row in
            (0..<columns).map { column in
                let index = row * columns + column
                return index < cells.count ? cells[index] : ""
            }
        }
    }
}

/// Brouillon de l'éditeur d'opérateur (`MathOperatorDraft`).
struct MathKbOperatorDraft {
    var kind: MathKbOperatorKind
    var values: [String]
    var active: Int
    /// Plage de l'opérateur visé dans la réponse (`MathOperatorDraft.replacement`).
    /// `nil` : l'éditeur insère un nouvel opérateur.
    var replacement: StmtTextSelection?

    /// `createMathOperatorDraft` (`MathKeyboard.tsx:195-210`) : les champs sont
    /// pré-remplis quand l'éditeur rouvre une construction existante, et sa
    /// plage est mémorisée pour la remplacer à la validation.
    init(
        kind: MathKbOperatorKind,
        values: [String: String] = [:],
        replacement: StmtTextSelection? = nil
    ) {
        self.kind = kind
        self.values = MathKbOperatorCatalog.definition(for: kind).fields.map {
            values[$0.id] ?? ""
        }
        self.active = 0
        self.replacement = replacement
    }

    /// Une construction existante est visée : le pied de l'éditeur propose
    /// « Mettre à jour » au lieu d'« Insérer » (`MathKeyboard.tsx:1424`).
    var isReplacing: Bool { replacement != nil }

    /// Champs nommés, pour le formateur et le test de complétude.
    var valueMap: [String: String] {
        var map: [String: String] = [:]
        for (index, field) in MathKbOperatorCatalog.definition(for: kind).fields.enumerated() {
            map[field.id] = index < values.count ? values[index] : ""
        }
        return map
    }

    var isComplete: Bool {
        MathKbOperatorCatalog.isComplete(kind: kind, values: valueMap)
    }

    var preview: String {
        MathKbOperatorCatalog.preview(kind: kind, values: valueMap)
    }
}

/// Brouillon de l'éditeur d'intervalle (`IntervalDraft`).
struct MathKbIntervalDraft {
    var kind: MathKbIntervalKind = .real
    var lower: String = ""
    var upper: String = ""
    var lowerClosed: Bool = true
    var upperClosed: Bool = true
    var active: Int = 0

    /// Les deux bornes sont remplies (`intervalComplete`).
    var isComplete: Bool {
        !lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !upper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var interval: MathKbInterval {
        MathKbInterval(
            kind: kind,
            lower: lower,
            upper: upper,
            lowerClosed: lowerClosed,
            upperClosed: upperClosed
        )
    }

    /// Bornes nommées de l'éditeur (`INTERVAL_BOUNDS`).
    static let boundLabels = ["Borne gauche", "Borne droite"]

    /// Bornes vides de l'éditeur (`createIntervalDraft`).
    static func initial() -> MathKbIntervalDraft {
        MathKbIntervalDraft()
    }
}
