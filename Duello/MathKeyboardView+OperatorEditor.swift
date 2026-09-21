//
//  MathKeyboardView+OperatorEditor.swift
//  Duello
//
//  Éditeur guidé d'opérateur : limite, intégrale, somme, produit, exposant
//  (aperçu, champs obligatoires, bornes infinies, insertion).
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import SwiftUI

extension MathKeyboardView {
    // MARK: Éditeur d'opérateur
    func operatorEditor(_ draft: MathKbOperatorDraft) -> some View {
        let definition = MathKbOperatorCatalog.definition(for: draft.kind)
        return VStack(alignment: .leading, spacing: 7) {
            operatorEditorHeader(draft, definition: definition)
            operatorEditorFields(draft, definition: definition)
            if let activeField = operatorActiveField(draft), activeField.infinite {
                infiniteBoundKeys(target: activeField.label.lowercased())
            }
            operatorEditorFooter(draft, definition: definition)
        }
        .padding(8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Aperçu, titre et aide de l'opérateur.
    func operatorEditorHeader(
        _ draft: MathKbOperatorDraft,
        definition: MathKbOperatorDefinition
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(draft.preview)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 86, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.title)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text(definition.hint)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                Text("Champs obligatoires · touche une valeur pour la corriger.")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 4)
        }
    }

    /// Un champ par entrée de la définition.
    func operatorEditorFields(
        _ draft: MathKbOperatorDraft,
        definition: MathKbOperatorDefinition
    ) -> some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(definition.fields.indices, id: \.self) { index in
                operatorField(index: index, field: definition.fields[index], draft: draft)
            }
        }
    }

    /// Navigation entre les champs et validation.
    func operatorEditorFooter(
        _ draft: MathKbOperatorDraft,
        definition: MathKbOperatorDefinition
    ) -> some View {
        HStack(spacing: 4) {
            Text("Champ \(draft.active + 1)/\(definition.fields.count)")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            MathKbMiniButton(systemImage: "chevron.backward", enabled: draft.active > 0) {
                focusOperatorField(draft.active - 1)
            }
            MathKbMiniButton(
                systemImage: "chevron.forward",
                enabled: draft.active < definition.fields.count - 1
            ) {
                focusOperatorField(draft.active + 1)
            }
            Spacer(minLength: 4)
            MathKbMiniButton(label: "Annuler") {
                operatorDraft = nil
            }
            MathKbMiniButton(label: "Insérer", wide: true, prominent: true, enabled: draft.isComplete) {
                commitOperator()
            }
        }
    }

    func operatorField(
        index: Int,
        field: MathKbOperatorField,
        draft: MathKbOperatorDraft
    ) -> some View {
        let selected = index == draft.active
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(field.label) *")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            TextField("ex. \(field.placeholder)", text: operatorFieldBinding(index))
                .font(.system(size: 12, weight: .heavy))
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($operatorFocus, equals: index)
                .frame(height: 34)
                .padding(.horizontal, 4)
                .background(selected ? Theme.primaryLight : Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
                .onTapGesture {
                    operatorDraft?.active = index
                    operatorFocus = index
                }
                .accessibilityLabel(field.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func operatorFieldBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let draft = operatorDraft, index < draft.values.count else { return "" }
                return draft.values[index]
            },
            set: { newValue in
                guard var draft = operatorDraft, index < draft.values.count else { return }
                draft.values[index] = newValue
                operatorDraft = draft
            }
        )
    }

    func operatorActiveField(_ draft: MathKbOperatorDraft) -> MathKbOperatorField? {
        let fields = MathKbOperatorCatalog.definition(for: draft.kind).fields
        return draft.active < fields.count ? fields[draft.active] : nil
    }

    func focusOperatorField(_ index: Int) {
        guard var draft = operatorDraft else { return }
        let count = MathKbOperatorCatalog.definition(for: draft.kind).fields.count
        let active = max(0, min(count - 1, index))
        draft.active = active
        operatorDraft = draft
        operatorFocus = active
    }

    func commitOperator() {
        guard let draft = operatorDraft, draft.isComplete else { return }
        guard let text = MathKbOperatorCatalog.format(kind: draft.kind, values: draft.valueMap) else {
            return
        }
        insertText(text, 0)
        operatorDraft = nil
        sectionId = draft.kind == .exponent ? "base" : "analyse"
    }
}
