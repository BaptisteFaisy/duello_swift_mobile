//
//  MathKeyboardView+Toolbar.swift
//  Duello
//
//  Bandeau d'onglets, bouton de fermeture et rangée d'actions (espace,
//  retour, effacer, mode indice) de la barre de symboles.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import SwiftUI

extension MathKeyboardView {
    // MARK: Bandeau d'onglets et fermeture

    var tabsRow: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(sections) { item in
                        tabButton(item)
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 2)
            }
            closeButton
        }
    }

    func tabButton(_ item: MathKbSection) -> some View {
        let selected = item.id == currentSection.id
        return Button {
            sectionId = item.id
        } label: {
            Text(item.label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .padding(.vertical, 4)
                .padding(.horizontal, 9)
                .background(selected ? Theme.ink : Theme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Onglet \(item.label)")
    }

    var closeButton: some View {
        Button {
            close()
        } label: {
            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 28, height: 24)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fermer le clavier maths")
    }
    // MARK: Rangée d'actions

    var actionsRow: some View {
        HStack(spacing: 5) {
            if operatorDraft == nil, currentSection.id == MathKbLayout.subscriptSectionId {
                MathKbActionKey(
                    accessibility: subscriptMode ? "Écrire sur la ligne" : "Écrire en indice",
                    label: "xₙ",
                    highlighted: subscriptMode,
                    labelSize: 15
                ) {
                    subscriptMode.toggle()
                }
            }

            MathKbActionKey(accessibility: "Espace", label: "espace") {
                insertDraftText(" ")
            }

            MathKbActionKey(
                accessibility: returnAccessibilityLabel,
                systemImage: draftOpen ? "chevron.forward" : "return"
            ) {
                handleReturn()
            }

            MathKbActionKey(accessibility: "Effacer", systemImage: "delete.left") {
                handleBackspace()
            }
        }
        .padding(.top, 5)
    }

    var returnAccessibilityLabel: String {
        if operatorDraft != nil { return "Champ suivant" }
        if intervalDraft != nil { return "Borne suivante" }
        if matrixDraft != nil { return "Case suivante" }
        return "Nouvelle ligne"
    }
}
