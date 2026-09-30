//
//  MathKeyboardView+EditExisting.swift
//  Duello
//
//  Rangée « Modifier … » d'une construction écrite (`MathKeyboard.tsx:1038-1060`)
//  et le relevé de la construction sous le curseur (`selectedExistingStructure`,
//  `MathKeyboard.tsx:468-478`). Extrait de `MathKeyboardViewCore.swift` pour
//  rester sous les seuils du ratchet de complexité (fichier < 500 lignes,
//  ≤ 10 fonctions) — aucun renommage, aucune signature modifiée.
//
//  Écart A7-12 #11 : la logique d'édition d'une construction existante était
//  portée (`startTool` relit la réponse) mais l'UI qui l'ouvre manquait.
//

import SwiftUI

/// `mathOperatorEditLabel(kind)` : libellé de la construction guidée dans la
/// rangée « Modifier … » (`MathKeyboard.tsx:218-224`).
func mathOperatorEditLabel(_ kind: MathKbOperatorKind) -> String {
    switch kind {
    case .exponent: return "l’exposant"
    case .limit: return "la limite"
    case .integral: return "l’intégrale"
    case .sum: return "la somme"
    case .product: return "le produit"
    }
}

extension MathKeyboardView {

    /// Construction écrite sous le curseur (`selectedExistingStructure`,
    /// `MathKeyboard.tsx:468-478`) : une matrice l'emporte (modifier ses cases
    /// est l'action la plus englobante), sinon l'opérateur guidé relevé.
    var selectedExistingStructure: (action: MathKbAction, label: String)? {
        if StmtMatrixParse.findMatrixAtSelection(answer, answerSelection) != nil {
            return (.matrix, "la matrice")
        }
        if let parsed = StmtOperatorParse.findMathOperatorAtSelection(answer, answerSelection),
           let kind = MathKbOperatorKind(rawValue: parsed.kind.rawValue) {
            return (kind.action, mathOperatorEditLabel(kind))
        }
        return nil
    }

    /// Rangée « Modifier … » d'une construction écrite
    /// (`MathKeyboard.tsx:1038-1060`) : rouvre l'éditeur guidé de la construction
    /// relevée, sans toucher au reste de la réponse. Absente tant qu'aucun
    /// éditeur guidé n'est ouvert et qu'aucune construction n'est sous le curseur.
    @ViewBuilder var editExistingRow: some View {
        if !draftOpen, let structure = selectedExistingStructure {
            Button {
                startTool(structure.action)
            } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "create-outline", size: 16, color: Theme.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Modifier \(structure.label)")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Theme.ink)
                        Text("Corrige ses valeurs sans la supprimer ni la refaire.")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    IonIcon(name: "chevron-forward", size: 15, color: Theme.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            }
            .buttonStyle(MathKbPressStyle(
                cornerRadius: Theme.radiusSmall,
                background: Theme.primaryLight,
                border: Theme.primary
            ))
            .padding(.bottom, 8)
            .accessibilityLabel("Modifier \(structure.label) dans la réponse")
            .accessibilityHint("Ouvre ses valeurs sans supprimer le reste de la réponse.")
        }
    }
}
