//
//  AnnReaderSubmitUI.swift
//  Duello
//
//  Zone de soumission du lecteur d'annale (P0 18#2) : panneaux d'erreur de
//  correction, programme Python en échec, bouton « Soumettre l'exercice entier »
//  et bouton principal (question ou copie entière).
//
//  Fichier source Expo porté : `src/components/AnnaleViewer.tsx` (:4817, :4853,
//  :4898 — `submitDock`, `wholeSubmitButton`, `gradingErrorPanel`,
//  `pythonBlockedPanel`).
//
//  Cible : iOS 16.
//
import SwiftUI

extension AnnReaderView {
    /// Zone sous l'atelier : le dock de correction remplace le bouton de
    /// soumission pendant la correction d'une copie entière ; sinon le bouton
    /// principal, suivi du bouton d'exercice entier quand il fait plus.
    @ViewBuilder
    var submitArea: some View {
        if correctionDockActive, let correction = correctionDockCorrection, !correction.completed {
            AnnCorrectionDock(correction: correction)
        } else if wholeExerciseSubmissionOnly || (currentReview == nil && currentGradingError == nil) {
            submitButton
        }
        gradingNotices
        if showSupplementalWholeSubmit { wholeSubmitButton }
    }

    /// Bouton principal : « Soumettre cette réponse » (annale) ou « Soumettre
    /// l'exercice » (entraînement), avec la variante « malgré l'erreur » quand un
    /// programme Python retient la correction.
    var submitButton: some View {
        let whole = wholeExerciseSubmissionOnly
        let pythonBlockedNow = whole ? (pythonBlocked != nil) : (currentPythonBlocked != nil)
        let busy = batchProgress != nil || activeQuestionGrading || pythonRunning
        return Button {
            if whole {
                Task { @MainActor in await submitWholeExercise(skipPythonRun: pythonBlockedNow) }
            } else {
                Task { @MainActor in await submitCurrentAnswer(skipPythonRun: pythonBlockedNow) }
            }
        } label: {
            HStack(spacing: 8) {
                if busy {
                    ProgressView().tint(Theme.surface)
                } else {
                    IonIcon(name: "send-outline", size: 15, color: Theme.surface)
                }
                Text(submitButtonLabel(pythonBlocked: pythonBlockedNow))
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(submitButtonDisabled)
        .opacity(submitButtonDisabled ? 0.45 : 1)
        .accessibilityLabel(submitButtonAccessibility(pythonBlocked: pythonBlockedNow))
    }

    /// `wholeSubmitButton` : corrige d'un coup les autres réponses écrites.
    var wholeSubmitButton: some View {
        Button {
            Task { @MainActor in await submitWholeExercise() }
        } label: {
            HStack(spacing: 8) {
                if batchProgress != nil {
                    ProgressView().tint(Theme.primary)
                } else {
                    IonIcon(name: "documents-outline", size: 16, color: Theme.primary)
                }
                Text(wholeSubmitLabel)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(batchProgress != nil || pythonRunning)
        .opacity(batchProgress != nil || pythonRunning ? 0.45 : 1)
        .accessibilityLabel(
            "Soumettre l’exercice entier, \(submittableQuestionIds.count) réponses à corriger"
        )
    }

    /// Panneaux d'erreur : correction en échec (avec relance) et programme Python
    /// en échec — dans ce cas aucune correction n'a été consommée.
    @ViewBuilder
    var gradingNotices: some View {
        if let error = currentGradingError {
            VStack(alignment: .leading, spacing: 8) {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.like)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !wholeExerciseSubmissionOnly {
                    Button(action: retryAutomaticGrade) {
                        HStack(spacing: 6) {
                            IonIcon(name: "refresh", size: 16, color: Theme.surface)
                            Text("Relancer la correction automatique")
                                .font(.system(size: 12, weight: .heavy))
                        }
                        .foregroundStyle(Theme.surface)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.like)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        if let blocked = currentPythonBlocked {
            Text(pythonBlockedMessage(blocked.result))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
    }

    // MARK: Libellés dérivés

    private var submitButtonDisabled: Bool {
        if wholeExerciseSubmissionOnly {
            return submittableQuestionIds.isEmpty || pythonRunning || batchProgress != nil
        }
        return currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || pythonRunning || activeQuestionGrading
    }

    private var wholeSubmitLabel: String {
        guard let progress = batchProgress else {
            return "Soumettre l’exercice entier (\(submittableQuestionIds.count))"
        }
        return "Correction \(min(progress.done + 1, progress.total))/\(progress.total)…"
    }

    private func submitButtonLabel(pythonBlocked: Bool) -> String {
        if pythonRunning { return "Exécution de ton programme…" }
        if let progress = batchProgress {
            return "Correction \(min(progress.done + 1, progress.total))/\(progress.total)…"
        }
        if activeQuestionGrading { return "Correction en cours…" }
        if wholeExerciseSubmissionOnly {
            return pythonBlocked ? "Faire corriger l’exercice malgré l’erreur" : "Soumettre l’exercice"
        }
        return pythonBlocked ? "Faire corriger malgré l’erreur" : "Soumettre cette réponse"
    }

    private func submitButtonAccessibility(pythonBlocked: Bool) -> String {
        if wholeExerciseSubmissionOnly {
            return pythonBlocked
                ? "Faire corriger l’exercice malgré l’erreur d’exécution"
                : "Soumettre l’exercice"
        }
        if pythonBlocked { return "Faire corriger malgré l’erreur d’exécution" }
        return "Soumettre la réponse \(currentQuestionLabel)"
    }

    /// `pythonBlockedText` : le programme ne tourne pas, donc la correction
    /// attend — aucune correction n'a été consommée.
    private func pythonBlockedMessage(_ result: PyConRunResult) -> String {
        result.status == .timeout
            ? "Ton programme ne s’arrête pas : la correction attend que tu règles la boucle. Aucune correction n’a été utilisée."
            : "Ton programme s’arrête sur une erreur, lis la console au-dessus. Aucune correction n’a été utilisée."
    }
}
