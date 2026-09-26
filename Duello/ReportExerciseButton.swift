//
//  ReportExerciseButton.swift
//  Duello
//
//  Lot « Report » — signalement d'un énoncé ou d'un corrigé faux : icône
//  contextuelle et fenêtre partagées par tous les lecteurs d'exercice.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ExerciseReportButton.tsx (ExerciseReportButton,
//                                               TARGET_LABELS,
//                                               TARGET_LABELS_WITH_ARTICLE,
//                                               DIALOG_MARGIN)
//    - src/utils/socialApi.ts                  (submitExerciseReport,
//                                               ExerciseReportSubmission)
//
//  Exposé en `enum` (contrat du lot) : ce module porte les libellés et l'envoi
//  (`POST /exercise-reports`), et `make(...)` rend le déclencheur prêt à poser —
//  icône « bug » et fenêtre incluses. Le nom de la personne vient du profil
//  local (`userId` + `displayName`), comme côté Expo : la copie, les réponses et
//  les verdicts restent locaux.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Signalement d'un énoncé ou d'un corrigé (`ExerciseReportButton.tsx`).
enum ReportExerciseButton {

    /// Air laissé entre la fenêtre et les bords, barres système exclues
    /// (`DIALOG_MARGIN`).
    static let dialogMargin: CGFloat = 28

    /// Longueur maximale du message (`maxLength={1200}`).
    static let messageLimit = 1200

    /// Étiquette du déclencheur, mot pour mot (`accessibilityLabel`).
    static func triggerLabel(for target: ReportExerciseTarget) -> String {
        "Signaler un \(target.label) incorrect ou faux"
    }

    /// Envoie le signalement (`submitExerciseReport`, `POST /exercise-reports`).
    static func submit(
        profile: UserProfile,
        submission: ReportExerciseSubmission,
        token: String?
    ) async throws {
        let body = try DuelloAPI.encodeBody(
            ReportExerciseReportBody(profile: profile, submission: submission)
        )
        _ = try await DuelloAPI.request(
            "exercise-reports",
            method: "POST",
            token: token,
            body: body
        )
    }

    /// Déclencheur + fenêtre, prêts à poser dans un lecteur d'exercice.
    static func make(
        profile: UserProfile,
        target: ReportExerciseTarget,
        source: ReportExerciseSource,
        exerciseId: String,
        exerciseTitle: String,
        subject: String,
        compact: Bool = false
    ) -> some View {
        ReportExerciseTrigger(
            profile: profile,
            target: target,
            source: source,
            exerciseId: exerciseId,
            exerciseTitle: exerciseTitle,
            subject: subject,
            compact: compact
        )
    }
}

/// Corps exact de `POST /exercise-reports` (`submitExerciseReport`).
private struct ReportExerciseReportBody: Encodable {
    var userId: String
    var displayName: String
    var target: ReportExerciseTarget
    var source: ReportExerciseSource
    var exerciseId: String
    var exerciseTitle: String
    var subject: String
    var message: String

    init(profile: UserProfile, submission: ReportExerciseSubmission) {
        userId = DuelloAPI.publicProfileId(email: profile.email)
        displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        target = submission.target
        source = submission.source
        exerciseId = submission.exerciseId.trimmingCharacters(in: .whitespacesAndNewlines)
        exerciseTitle = submission.exerciseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        subject = submission.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        message = submission.message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Déclencheur du signalement : icône discrète, puis fenêtre modale.
private struct ReportExerciseTrigger: View {
    let profile: UserProfile
    let target: ReportExerciseTarget
    let source: ReportExerciseSource
    let exerciseId: String
    let exerciseTitle: String
    let subject: String
    let compact: Bool

    @State private var visible = false

    /// Initialiseur explicite : un `@State` privé rend l'initialiseur membre
    /// synthétisé inaccessible.
    init(
        profile: UserProfile,
        target: ReportExerciseTarget,
        source: ReportExerciseSource,
        exerciseId: String,
        exerciseTitle: String,
        subject: String,
        compact: Bool
    ) {
        self.profile = profile
        self.target = target
        self.source = source
        self.exerciseId = exerciseId
        self.exerciseTitle = exerciseTitle
        self.subject = subject
        self.compact = compact
    }

    private var corner: CGFloat { compact ? 10 : 13 }
    private var side: CGFloat { compact ? 32 : 42 }

    var body: some View {
        Button(action: { visible = true }) {
            Image(systemName: "ladybug")
                .font(.system(size: compact ? 15 : 18, weight: .semibold))
                .foregroundStyle(Theme.like)
                .frame(width: side, height: side)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ReportExerciseButton.triggerLabel(for: target))
        .sheet(isPresented: $visible) {
            ReportExerciseDialog(
                profile: profile,
                target: target,
                source: source,
                exerciseId: exerciseId,
                exerciseTitle: exerciseTitle,
                subject: subject
            )
            .presentationDetents([.medium])
        }
    }
}

/// Fenêtre de signalement (`ExerciseReportButton`).
private struct ReportExerciseDialog: View {
    let profile: UserProfile
    let target: ReportExerciseTarget
    let source: ReportExerciseSource
    let exerciseId: String
    let exerciseTitle: String
    let subject: String

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var sending = false
    @State private var errorMessage = ""
    @State private var sent = false

    /// Initialiseur explicite : les propriétés d'environnement et d'état
    /// privées rendent l'initialiseur membre synthétisé inaccessible.
    init(
        profile: UserProfile,
        target: ReportExerciseTarget,
        source: ReportExerciseSource,
        exerciseId: String,
        exerciseTitle: String,
        subject: String
    ) {
        self.profile = profile
        self.target = target
        self.source = source
        self.exerciseId = exerciseId
        self.exerciseTitle = exerciseTitle
        self.subject = subject
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: ReportExerciseButton.dialogMargin)
            card
            Spacer(minLength: ReportExerciseButton.dialogMargin)
        }
        .background(Theme.background.ignoresSafeArea())
        .alert("Signalement envoyé", isPresented: $sent) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Le compte administrateur a reçu ton signalement concernant \(target.labelWithArticle).")
        }
    }

    /// Carte du dialogue : centrée, largeur bornée comme `maxWidth: 480`.
    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            contextCard
            messageField
            if !errorMessage.isEmpty { errorCard }
            submitButton
        }
        .padding(20)
        .frame(maxWidth: 480)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "ladybug")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.like)
                .frame(width: 42, height: 42)
                .background(Theme.like.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text("SIGNALEMENT")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(Theme.like)
                Text("Signaler \(target.labelWithArticle)")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .disabled(sending)
            .accessibilityLabel("Fermer")
        }
    }

    // MARK: Contexte

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(target.contextType)
                .font(.system(size: 9, weight: .black))
                .tracking(0.8)
                .foregroundStyle(Theme.like)
            Text(exerciseTitle)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.top, 18)
    }

    // MARK: Message

    private var messageField: some View {
        TextEditor(text: $message)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .frame(minHeight: 96)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if message.isEmpty {
                    Text("Ex. : le signe est inversé à la question 2…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 16)
            .onChange(of: message) { value in
                if value.count > ReportExerciseButton.messageLimit {
                    message = String(value.prefix(ReportExerciseButton.messageLimit))
                }
                errorMessage = ""
            }
    }

    private var errorCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.like)
            Text(errorMessage)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.like.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .padding(.top, 12)
    }

    // MARK: Envoi

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 7) {
                if sending {
                    ProgressView().progressViewStyle(.circular).tint(Theme.surface)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.surface)
                    Text("Envoyer")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.surface)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(sending)
        .padding(.top, 18)
        .accessibilityLabel("Envoyer")
    }

    private func submit() {
        guard !sending else { return }
        sending = true
        errorMessage = ""
        let submission = ReportExerciseSubmission(
            target: target,
            source: source,
            exerciseId: exerciseId,
            exerciseTitle: exerciseTitle,
            subject: subject,
            message: message
        )
        Task {
            do {
                try await ReportExerciseButton.submit(
                    profile: profile,
                    submission: submission,
                    token: session.token
                )
                sending = false
                sent = true
            } catch let failure {
                sending = false
                errorMessage = (failure as? LocalizedError)?.errorDescription
                    ?? "Le signalement n’a pas pu être envoyé."
            }
        }
    }
}
