//
//  OnbUiChoices.swift
//  Duello
//
//  Groupes de choix et puces de sélection de l'inscription.
//  Porté de `src/screens/OnboardingScreen.tsx`, plage 1494-1703 :
//    `ChoiceSection`, `ChoiceChip`.
//
//  Préfixe réservé du lot : `OnbUi`. Aucune dépendance externe. iOS 16.
//  Réutilise `Theme` uniquement ; ne redéfinit aucun type existant
//  (`DuelloChip` du kit partagé reste distinct : capsule de filtre, pas de
//  radio à description).
//

import SwiftUI

/// `ChoiceSection` — groupe de choix avec légende optionnelle.
///
/// Limite documentée : la source répartit les puces dans une grille qui
/// s'enroule (`choiceGrid`, `flexWrap`). SwiftUI n'a pas d'équivalent direct
/// ici : le contenu est laissé au choix de l'appelant (`VStack` pour des puces
/// pleine largeur, `LazyVGrid` pour un enroulement).
struct OnbUiChoiceSection<Content: View>: View {
    /// Omis quand le bandeau de l'étape dit déjà ce qui est demandé.
    var label: String? = nil
    var dark: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label = label {
                Text(label)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(dark ? Color.white : Theme.ink)
            }
            content()
        }
    }
}

/// `ChoiceChip` — puce de choix (rôle radio) avec description optionnelle.
struct OnbUiChoiceChip: View {
    let label: String
    var description: String? = nil
    let isSelected: Bool
    let action: () -> Void
    /// Puce pleine largeur : libellé à gauche, coche à droite.
    var wide: Bool = false
    /// Variante invité : fond noir, contours blancs.
    var dark: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(labelColor)
                    if let description = description {
                        Text(description)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(descriptionColor)
                            .multilineTextAlignment(.leading)
                    }
                }

                if wide { Spacer(minLength: 0) }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(dark ? Color.black : Color.white)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 15)
            .frame(minHeight: 45)
            .frame(maxWidth: wide ? .infinity : nil, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(borderColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(description.map { "\(label) — \($0)" } ?? label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Fond : surface blanche, encre pleine si sélectionnée ; transparent en
    /// variante invité, blanc si sélectionnée.
    private var background: Color {
        if dark { return isSelected ? .white : .clear }
        return isSelected ? Theme.ink : Theme.surface
    }

    /// Bordure : fine grise, encre si sélectionnée ; blanche en variante invité.
    private var borderColor: Color {
        if dark { return .white }
        return isSelected ? Theme.ink : Theme.border
    }

    /// Libellé : encre douce, blanc si sélectionnée ; inversé en variante invité.
    private var labelColor: Color {
        if dark { return isSelected ? .black : .white }
        return isSelected ? Theme.surface : Theme.inkSoft
    }

    /// Description : teinte verte claire si sélectionnée, gris sinon.
    private var descriptionColor: Color {
        if dark { return isSelected ? Color(white: 0.2) : Color(white: 0.72) }
        return isSelected ? Theme.progressLight : Theme.inkSoft
    }
}
