//
//  PlanTaskComposer.swift
//  Duello
//
//  Écran « Plan » — carte de saisie rapide flottante (TaskCaptureCard.tsx) :
//  panneau conditionnel, dictée vocale avec garde Premium, micro toujours ancré.
//
import Foundation
import SwiftUI

// MARK: - Saisie des tâches

/// `TaskCaptureCard` (TaskCaptureCard.tsx) : panneau flottant monté seulement
/// quand il y a quelque chose à montrer (`isPanelVisible`, lignes 51-56) et
/// micro ancré en bas (54×54, lignes 139-164). Le micro applique la garde
/// Premium (`requirePremiumTool('voice-transcription', …)`, lignes 40-49) et la
/// dictée vient de `DictControlModel` (`useDictation`).
struct PlanTaskComposerCard: View {
    @Binding var text: String
    let onValidate: () -> Void

    @EnvironmentObject private var session: SessionStore
    @StateObject private var dictation = DictControlModel()

    /// `permissionMessage` de la source (ligne 20).
    private static let permissionMessage =
        "Autorise le micro et la reconnaissance vocale pour dicter tes tâches."

    private var accountId: String {
        ConsentPremiumGate.accountId(email: session.profile.email)
    }

    /// `!transcript.trim() || isFormatting` (lignes 125-131).
    private var canValidate: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !dictation.isFormatting
    }

    /// `isPanelVisible` (lignes 51-56).
    private var panelVisible: Bool {
        dictation.isListening
            || dictation.isFormatting
            || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !dictation.error.isEmpty
            || !dictation.notice.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if panelVisible { panel }
            micButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
    }

    // MARK: Panneau (wrapper, lignes 196-206)

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
            Text("Une phrase par tâche, même en vrac. Pour bien la placer, indique si possible :")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 15)

            PlanFlowLayout(spacing: 7, lineSpacing: 7) {
                PlanRequirementChip(icon: "flag-outline", label: "Priorité")
                PlanRequirementChip(icon: "calendar-outline", label: "Échéance")
                PlanRequirementChip(icon: "book-outline", label: "Matière")
                PlanRequirementChip(icon: "timer-outline", label: "Durée", optional: true)
            }
            .padding(.top, 11)

            inputCard
            statusRow
            if !dictation.notice.isEmpty {
                Text(dictation.notice)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 8)
            }
            if !dictation.error.isEmpty {
                Text(dictation.error)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
            }
            validateButton
        }
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    /// `headingRow` (lignes 62-70) : icône `sparkles` 17, eyebrow et titre.
    private var heading: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Theme.primaryLight)
                    .frame(width: 38, height: 38)
                IonIcon(name: "sparkles", size: 17, color: Theme.primary)
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
    }

    /// `inputCard` (lignes 82-93) : `minHeight: 150`, bord 1.5, et en écoute le
    /// fond et le bord passent à l'encre claire / pleine.
    private var inputCard: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Ex. Demain, finir le DM de maths — urgent, environ 1 h. Puis apprendre le vocabulaire d’anglais pour vendredi, 30 min.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90)
                .accessibilityLabel("Tâches à ajouter")
        }
        .padding(13)
        .frame(minHeight: 150, alignment: .topLeading)
        .background(dictation.isListening ? Theme.primaryLight : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(dictation.isListening ? Theme.primary : Theme.border, lineWidth: 1.5)
        )
        .padding(.top, 15)
    }

    /// `statusRow` (lignes 95-119) : icône et libellé d'état de la dictée.
    private var statusRow: some View {
        HStack(spacing: 6) {
            IonIcon(
                name: dictation.isListening ? "radio" : "create-outline",
                size: 14,
                color: statusHighlighted ? Theme.ink : Theme.inkSoft
            )
            Text(statusText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusHighlighted ? Theme.ink : Theme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private var statusHighlighted: Bool { dictation.isListening || dictation.isFormatting }

    /// Libellé d'état (lignes 107-117), étape et moteur exacts.
    private var statusText: String {
        if dictation.isFormatting {
            return dictation.stage == .alibaba
                ? "Finalisation de la transcription…"
                : "Mise en forme de la transcription…"
        }
        if dictation.isListening {
            if dictation.engine == .device {
                return "Le téléphone transcrit en direct… appuie sur stop quand tu as terminé."
            }
            if dictation.engine != nil {
                return "Écoute en cours… toute la phrase apparaîtra après stop."
            }
            return "Connexion au service vocal…"
        }
        return "Relis et corrige toujours la transcription avant de valider."
    }

    /// `validateButton` (lignes 123-136) : `arrow-forward` 18 blanc.
    private var validateButton: some View {
        Button(action: validate) {
            HStack(spacing: 8) {
                Text("Organiser dans mon programme")
                    .font(.system(size: 12, weight: .heavy))
                IonIcon(name: "arrow-forward", size: 18, color: Color.white)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(canValidate ? 1 : 0.35)
        }
        .buttonStyle(PlanPressStyle(pressedOpacity: 0.75))
        .disabled(!canValidate)
        .padding(.top, 14)
    }

    /// `micButton` (lignes 139-164) : 54×54, icône 25 (`mic`/`stop`/`sparkles`).
    private var micButton: some View {
        Button(action: requestDictationToggle) {
            IonIcon(
                name: dictation.isFormatting ? "sparkles" : (dictation.isListening ? "stop" : "mic"),
                size: 25,
                color: Color.white
            )
            .frame(width: 54, height: 54)
            .background(Theme.ink)
            .clipShape(Circle())
            .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
            .opacity(dictation.isFormatting ? 0.35 : 1)
        }
        .buttonStyle(PlanPressStyle(pressedOpacity: 0.75))
        .disabled(dictation.isFormatting)
        .padding(.leading, 20)
        .accessibilityLabel(micAccessibilityLabel)
    }

    private var micAccessibilityLabel: String {
        if dictation.isFormatting {
            return dictation.stage == .alibaba
                ? "Transcription haute précision en cours"
                : "Mise en forme mathématique en cours"
        }
        return dictation.isListening ? "Arrêter la dictée" : "Dicter mes tâches"
    }

    // MARK: Actions

    /// `validate` (lignes 32-38) : annule la dictée, transmet le texte, vide le champ.
    private func validate() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !dictation.isFormatting else { return }
        dictation.annuler()
        onValidate()
        text = ""
    }

    /// `requestDictationToggle` (lignes 40-49) : arrêter est direct, démarrer
    /// passe d'abord par la garde Premium (`voice-transcription`).
    private func requestDictationToggle() {
        Task { @MainActor in
            if dictation.isListening {
                await dictation.toggle(
                    currentText: text,
                    math: false,
                    permissionMessage: Self.permissionMessage,
                    apply: { text = $0 }
                )
                return
            }
            _ = await ConsentPremiumGate.gate(tool: .voiceTranscription, accountId: accountId) {
                await dictation.toggle(
                    currentText: text,
                    math: false,
                    permissionMessage: Self.permissionMessage,
                    apply: { text = $0 }
                )
            }
        }
    }
}

/// `Requirement` (TaskCaptureCard.tsx lignes 169-185) : icône 13 encre, libellé
/// 10, mention « optionnel » 8.
struct PlanRequirementChip: View {
    let icon: String
    let label: String
    var optional: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            IonIcon(name: icon, size: 13, color: Theme.primary)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.primary)
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
