//
//  PlanTaskComposer.swift
//  Duello
//
//  Écran « Plan » — carte de saisie rapide des tâches et ses puces d'exigence (TaskCaptureCard.tsx).
//
import Foundation
import SwiftUI

// MARK: - Saisie des tâches

/// `TaskCaptureCard` (TaskCaptureCard.tsx) : mêmes libellés, saisie au clavier.
/// La dictée vocale et la garde premium du composant d'origine ne sont pas
/// portées par ce lot.
struct PlanTaskComposerCard: View {
    @Binding var text: String
    let isAnalyzing: Bool
    let onValidate: () -> Void

    private var canValidate: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Theme.primaryLight)
                        .frame(width: 38, height: 38)
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AJOUT RAPIDE")
                        .font(.system(size: 8, weight: .black))
                        .kerning(1.1)
                        .foregroundStyle(Theme.ink)
                    Text("Dis tout ce que tu as à faire")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 0)
            }

            Text("Une phrase par tâche, même en vrac. Pour bien la placer, indique si possible :")
                .font(.system(size: 12, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 15)

            PlanFlowLayout(spacing: 7, lineSpacing: 7) {
                PlanRequirementChip(icon: "flag", label: "Priorité")
                PlanRequirementChip(icon: "calendar", label: "Échéance")
                PlanRequirementChip(icon: "book", label: "Matière")
                PlanRequirementChip(icon: "timer", label: "Durée", optional: true)
            }
            .padding(.top, 11)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Ex. Demain, finir le DM de maths — urgent, environ 1 h. Puis apprendre le vocabulaire d’anglais pour vendredi, 30 min.")
                        .font(.system(size: 13, weight: .medium))
                        .lineSpacing(6)
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(6)
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .accessibilityLabel("Tâches à ajouter")
            }
            .padding(13)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1.5)
            )
            // `inputCard` : hauteur minimale 150, l'`input` interne 90 (lignes
            // 232-242 de TaskCaptureCard.tsx).
            .frame(minHeight: 150, alignment: .top)
            .padding(.top, 15)

            Button(action: onValidate) {
                HStack(spacing: 8) {
                    Text("Organiser dans mon programme")
                        .font(.system(size: 12, weight: .heavy))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(Theme.white)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PlanValidateButtonStyle())
            .disabled(!canValidate)
            .opacity(canValidate ? 1 : 0.35)
            .padding(.top, 14)
        }
        // `wrapper` (TaskCaptureCard.tsx) : marge horizontale 20, `padding` 18,
        // rayon `radii.large` 18, bord 1 et ombre de carte — et non le motif
        // `.duelloCard()` (padding 16, rayon 14, sans ombre).
        .padding(18)
        .background(Theme.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .duelloShadow()
        .padding(.horizontal, 20)
    }
}

/// `validateButton` (TaskCaptureCard.tsx) : fond encre, rayon 16, hauteur
/// minimale 50, texte blanc 12 en gras ; à l'appui, opacité 0.75.
struct PlanValidateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// `Requirement` (TaskCaptureCard.tsx lignes 169-185).
struct PlanRequirementChip: View {
    let icon: String
    let label: String
    var optional: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.ink)
            if optional {
                Text("optionnel")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(Theme.primaryLight)
        .clipShape(Capsule())
    }
}
