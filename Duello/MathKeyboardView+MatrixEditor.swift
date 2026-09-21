//
//  MathKeyboardView+MatrixEditor.swift
//  Duello
//
//  Éditeur guidé de matrice : titre, grille de cases, navigation et
//  insertion.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import SwiftUI

extension MathKeyboardView {
    // MARK: Éditeur de matrice
    func matrixEditor(_ draft: MathKbMatrixDraft) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            matrixEditorHeader(draft)
            matrixEditorGrid(draft)
            matrixEditorFooter(draft)
        }
        .padding(8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Titre, aide et compteurs de lignes / colonnes.
    func matrixEditorHeader(_ draft: MathKbMatrixDraft) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Matrice \(draft.rows) × \(draft.columns)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Choisis une case, puis utilise les touches.")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                Text("Les touches s’ajoutent en fin de case.")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                MathKbStepper(
                    label: "Lignes",
                    value: draft.rows,
                    canDecrease: draft.rows > MathKbLayout.matrixMinSize,
                    canIncrease: draft.rows < MathKbLayout.matrixMaxSize,
                    decrease: { resizeMatrix(rows: draft.rows - 1, columns: draft.columns) },
                    increase: { resizeMatrix(rows: draft.rows + 1, columns: draft.columns) }
                )
                MathKbStepper(
                    label: "Colonnes",
                    value: draft.columns,
                    canDecrease: draft.columns > MathKbLayout.matrixMinSize,
                    canIncrease: draft.columns < MathKbLayout.matrixMaxSize,
                    decrease: { resizeMatrix(rows: draft.rows, columns: draft.columns - 1) },
                    increase: { resizeMatrix(rows: draft.rows, columns: draft.columns + 1) }
                )
            }
        }
    }

    /// Cases saisissables de la matrice.
    func matrixEditorGrid(_ draft: MathKbMatrixDraft) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 4) {
                ForEach(0..<draft.rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<draft.columns, id: \.self) { column in
                            matrixCell(row: row, column: column, draft: draft)
                        }
                    }
                }
            }
            .padding(.vertical, 1)
        }
        .frame(maxHeight: 70)
    }

    /// Navigation entre les cases et validation.
    func matrixEditorFooter(_ draft: MathKbMatrixDraft) -> some View {
        HStack(spacing: 4) {
            Text("Case \(draft.active + 1)/\(max(draft.cells.count, 1))")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            MathKbMiniButton(
                systemImage: "chevron.backward",
                enabled: draft.active > 0
            ) {
                moveMatrixCell(-1)
            }
            MathKbMiniButton(
                systemImage: "chevron.forward",
                enabled: draft.active < draft.cells.count - 1
            ) {
                moveMatrixCell(1)
            }
            Spacer(minLength: 4)
            MathKbMiniButton(label: "Annuler") {
                matrixDraft = nil
            }
            MathKbMiniButton(label: "Insérer", wide: true, prominent: true, enabled: draft.isComplete) {
                commitMatrix()
            }
        }
    }

    func matrixCell(row: Int, column: Int, draft: MathKbMatrixDraft) -> some View {
        let index = row * draft.columns + column
        let selected = index == draft.active
        return TextField("…", text: matrixCellBinding(index))
            .font(.system(size: 12, weight: .heavy))
            .multilineTextAlignment(.center)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($matrixFocus, equals: index)
            .frame(width: 56, height: 30)
            .background(selected ? Theme.primaryLight : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
            )
            .onTapGesture {
                matrixDraft?.active = index
                matrixFocus = index
            }
            .accessibilityLabel(
                "Case ligne \(row + 1), colonne \(column + 1)"
            )
    }

    func matrixCellBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let draft = matrixDraft, index < draft.cells.count else { return "" }
                return draft.cells[index]
            },
            set: { newValue in
                guard var draft = matrixDraft, index < draft.cells.count else { return }
                draft.cells[index] = newValue
                matrixDraft = draft
            }
        )
    }

    func resizeMatrix(rows: Int, columns: Int) {
        guard var draft = matrixDraft else { return }
        draft.resize(rows: rows, columns: columns)
        matrixDraft = draft
    }

    func moveMatrixCell(_ step: Int) {
        guard var draft = matrixDraft, !draft.cells.isEmpty else { return }
        let active = max(0, min(draft.cells.count - 1, draft.active + step))
        guard active != draft.active else { return }
        draft.active = active
        matrixDraft = draft
        matrixFocus = active
    }

    func commitMatrix() {
        guard let draft = matrixDraft, draft.isComplete else { return }
        guard let text = MathKbMatrixFormatter.format(
            rows: draft.grid,
            delimiter: draft.delimiter
        ) else { return }
        insertText(text, 0)
        matrixDraft = nil
        sectionId = "algebre"
    }
}
