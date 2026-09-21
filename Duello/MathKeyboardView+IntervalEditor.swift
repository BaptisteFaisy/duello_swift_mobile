//
//  MathKeyboardView+IntervalEditor.swift
//  Duello
//
//  Éditeur guidé d'intervalle : crochets, bornes et insertion.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import SwiftUI

extension MathKeyboardView {
    // MARK: Éditeur d'intervalle
    func intervalEditor(_ draft: MathKbIntervalDraft) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            intervalEditorHeader(draft)
            HStack(alignment: .bottom, spacing: 5) {
                intervalBracketButton(index: 0)
                intervalBoundField(index: 0)
                Text(",")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 9)
                intervalBoundField(index: 1)
                intervalBracketButton(index: 1)
            }
            infiniteBoundKeys(
                target: MathKbIntervalDraft.boundLabels[min(max(draft.active, 0), 1)].lowercased()
            )
            intervalEditorFooter(draft)
        }
        .padding(8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Aperçu, aide et choix réels / entiers.
    func intervalEditorHeader(_ draft: MathKbIntervalDraft) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(draft.interval.preview)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 86, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text("Intervalle")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Touche un crochet pour inclure ou exclure sa borne.")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                HStack(spacing: 4) {
                    ForEach(MathKbIntervalKind.allCases, id: \.self) { kind in
                        intervalKindButton(kind, selected: kind == draft.kind)
                    }
                }
            }
            Spacer(minLength: 4)
        }
    }

    /// Borne active et validation.
    func intervalEditorFooter(_ draft: MathKbIntervalDraft) -> some View {
        HStack(spacing: 4) {
            Text(MathKbIntervalDraft.boundLabels[min(max(draft.active, 0), 1)])
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            MathKbMiniButton(systemImage: "chevron.backward", enabled: draft.active > 0) {
                moveIntervalBound(-1)
            }
            MathKbMiniButton(systemImage: "chevron.forward", enabled: draft.active < 1) {
                moveIntervalBound(1)
            }
            Spacer(minLength: 4)
            MathKbMiniButton(label: "Annuler") {
                intervalDraft = nil
            }
            MathKbMiniButton(label: "Insérer", wide: true, prominent: true, enabled: draft.isComplete) {
                commitInterval()
            }
        }
    }

    func intervalKindButton(_ kind: MathKbIntervalKind, selected: Bool) -> some View {
        Button {
            intervalDraft?.kind = kind
        } label: {
            Text(kind.label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .padding(.vertical, 3)
                .padding(.horizontal, 9)
                .background(selected ? Theme.ink : Theme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Intervalle de \(kind.label.lowercased())")
    }

    func intervalBracketButton(index: Int) -> some View {
        let interval = intervalDraft?.interval ?? MathKbInterval()
        let value = index == 0 ? interval.lower : interval.upper
        let infinite = MathKbInterval.isInfinite(value)
        let closed = index == 0 ? interval.lowerClosed : interval.upperClosed
        let symbol = index == 0 ? interval.brackets.lower : interval.brackets.upper
        let accessibility: String
        if infinite {
            accessibility = index == 0
                ? "Borne gauche infinie, toujours exclue"
                : "Borne droite infinie, toujours exclue"
        } else if closed {
            accessibility = index == 0 ? "Exclure la borne gauche" : "Exclure la borne droite"
        } else {
            accessibility = index == 0 ? "Inclure la borne gauche" : "Inclure la borne droite"
        }
        return Button {
            toggleIntervalBound(index)
        } label: {
            Text(symbol)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 30, height: 34)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(closed && !infinite ? Theme.ink : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(infinite)
        .opacity(infinite ? 0.48 : 1)
        .accessibilityLabel(accessibility)
    }

    func intervalBoundField(index: Int) -> some View {
        let label = MathKbIntervalDraft.boundLabels[min(max(index, 0), 1)]
        let placeholder = index == 0 ? "0" : "1"
        let selected = (intervalDraft?.active ?? 0) == index
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(label) *")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            TextField("ex. \(placeholder)", text: intervalBoundBinding(index))
                .font(.system(size: 12, weight: .heavy))
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($intervalFocus, equals: index)
                .frame(height: 34)
                .padding(.horizontal, 4)
                .background(selected ? Theme.primaryLight : Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
                .onTapGesture {
                    intervalDraft?.active = index
                    intervalFocus = index
                }
                .accessibilityLabel(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func intervalBoundBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let draft = intervalDraft else { return "" }
                return index == 0 ? draft.lower : draft.upper
            },
            set: { newValue in
                guard var draft = intervalDraft else { return }
                if index == 0 { draft.lower = newValue } else { draft.upper = newValue }
                intervalDraft = draft
            }
        )
    }

    func toggleIntervalBound(_ index: Int) {
        guard var draft = intervalDraft else { return }
        if index == 0 {
            draft.lowerClosed.toggle()
        } else {
            draft.upperClosed.toggle()
        }
        intervalDraft = draft
    }

    func moveIntervalBound(_ step: Int) {
        guard var draft = intervalDraft else { return }
        let active = max(0, min(1, draft.active + step))
        guard active != draft.active else { return }
        draft.active = active
        intervalDraft = draft
        intervalFocus = active
    }

    func commitInterval() {
        guard let draft = intervalDraft, draft.isComplete else { return }
        insertText(draft.interval.formatted, 0)
        intervalDraft = nil
        sectionId = "ensembles"
    }
}
