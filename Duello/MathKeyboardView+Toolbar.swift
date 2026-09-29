//
//  MathKeyboardView+Toolbar.swift
//  Duello
//
//  Port de components/MathKeyboard.tsx (bandeau d'onglets, fermeture et
//  rangée d'actions). Écarts assumés : aucun.
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
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(sections) { item in
                            tabButton(item)
                                .id(item.id)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.trailing, 2)
                }
                // Recentrage sur l'onglet actif (`tabsRef.scrollTo`, RN) :
                // `MathKeyboard.tsx:907-911` glisse nativement ; on approxime
                // avec `.easeInOut(duration: 0.25)`.
                .onChange(of: sectionId) { newValue in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
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
        }
        .buttonStyle(MathKbPressStyle(
            background: selected ? Theme.primary : Theme.surface,
            border: selected ? Theme.primary : Theme.border,
            capsule: true
        ))
        .accessibilityLabel("Onglet \(item.label)")
    }

    var closeButton: some View {
        Button {
            close()
        } label: {
            // Icône du RN : `chevron-up` size 17 color inkSoft.
            IonIcon(name: "chevron-up", size: 17, color: Theme.inkSoft)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(MathKbPressStyle(cornerRadius: Theme.radiusSmall))
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
                    labelSize: 15,
                    labelColor: Theme.ink
                ) {
                    subscriptMode.toggle()
                }
            }

            // La touche espace occupe la largeur restante (`spaceKey` `flex:1`).
            MathKbActionKey(accessibility: "Espace", label: "espace", expandable: true) {
                insertDraftText(" ")
            }

            MathKbActionKey(
                accessibility: returnAccessibilityLabel,
                ionIcon: draftOpen ? "chevron-forward" : "return-down-back"
            ) {
                handleReturn()
            }

            MathKbActionKey(accessibility: "Effacer", ionIcon: "backspace-outline", iconSize: 18) {
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
