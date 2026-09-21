//
//  EvEventAnswerFields.swift
//  Duello
//
//  Champs de réponse d'un événement, un par question du sujet, comme dans un
//  lecteur d'exercice. Le bouton « Photo » photographie la réponse et la fait
//  transcrire par le relais premium dans le champ ciblé.
//
//  Fichier source Expo porté : `src/components/event/EventAnswerFields.tsx`.
//
//  Hors périmètre, volontairement : la dictée vocale (`useDictation`, relais
//  temps réel et moteur système) et l'aperçu composé (`AnswerComposition`,
//  WebView de composition LaTeX) ne sont pas portés — aucune brique native ne
//  les remplace ici et l'Info.plist n'est pas modifiable dans ce lot. Le champ
//  garde le texte exact qui partira à la correction.
//
//  Substitutions SF Symbols : camera-outline → camera.
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventAnswerFields: View {
    let questions: [EvEventQuestion]
    let answers: [String: String]
    let token: String?
    let onAnswer: (String, String) -> Void

    @State private var activeQuestionId: String

    init(
        questions: [EvEventQuestion],
        answers: [String: String],
        token: String?,
        onAnswer: @escaping (String, String) -> Void
    ) {
        self.questions = questions
        self.answers = answers
        self.token = token
        self.onAnswer = onAnswer
        _activeQuestionId = State(initialValue: questions.first?.id ?? "")
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                EvEventAnswerField(
                    question: question,
                    index: index,
                    answer: answers[question.id] ?? "",
                    active: question.id == activeQuestionId,
                    token: token,
                    onFocus: { activeQuestionId = question.id },
                    onAnswer: { text in onAnswer(question.id, text) }
                )
            }
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Champ d'une question

/// Champ d'une question : numéro, points, bouton photo et saisie multiligne.
private struct EvEventAnswerField: View {
    let question: EvEventQuestion
    let index: Int
    let answer: String
    let active: Bool
    let token: String?
    let onFocus: () -> Void
    let onAnswer: (String) -> Void

    @State private var photoBusy = false
    @State private var photoError = ""
    @State private var picking = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            answerEditor
            if !photoError.isEmpty {
                Text(photoError)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.like)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(active ? Theme.ink : Theme.border, lineWidth: 1)
        )
        .sheet(isPresented: $picking) {
            EvEventCameraPicker(
                onPick: { base64 in
                    picking = false
                    transcribe(base64)
                },
                onCancel: { picking = false }
            )
        }
    }

    /// Numéro, points et bouton de transcription photo.
    private var header: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 24, height: 24)
                .background(Theme.surfaceMuted)
                .clipShape(Circle())
            Text("\(question.points) pts")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
            Spacer(minLength: 0)
            Button { picking = true } label: {
                HStack(spacing: 4) {
                    if photoBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "camera")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text("Photo")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundStyle(Theme.inkSoft)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            }
            .buttonStyle(.plain)
            .disabled(photoBusy)
            .accessibilityLabel("Transcrire une photo de la réponse")
        }
    }

    /// Saisie multiligne, avec le texte d'invite de la source.
    private var answerEditor: some View {
        ZStack(alignment: .topLeading) {
            if answer.isEmpty {
                Text("Ta réponse…")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: Binding(get: { answer }, set: { onAnswer($0) }))
                .focused($focused)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 72)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .onChange(of: focused) { value in
            if value { onFocus() }
        }
    }

    /// Photo → relais premium → texte transcrit dans le champ ciblé.
    private func transcribe(_ base64: String) {
        guard !photoBusy else { return }
        photoBusy = true
        photoError = ""
        let token = self.token
        Task {
            do {
                let text = try await EvEventPhotoRelay.transcribe(imageBase64: base64, token: token)
                await MainActor.run {
                    onAnswer(text)
                    photoBusy = false
                }
            } catch {
                await MainActor.run {
                    photoError = (error as? DirectoryError)?.message ?? "La photo n’a pas pu être transcrite."
                    photoBusy = false
                }
            }
        }
    }
}
