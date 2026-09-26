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
                        .font(.system(size: 16, weight: .semibold))
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
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .accessibilityLabel("Tâches à ajouter")
            }
            .padding(13)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1.5)
            )
            .padding(.top, 15)

            Button(action: onValidate) {
                HStack(spacing: 8) {
                    Text("Organiser dans mon programme")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(!canValidate)
            .opacity(canValidate ? 1 : 0.35)
            .padding(.top, 14)
        }
        .duelloCard()
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
                .font(.system(size: 11, weight: .semibold))
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
