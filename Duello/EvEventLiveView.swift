//
//  EvEventLiveView.swift
//  Duello
//
//  Phase « live » de l'épreuve : sujet en haut, champs de réponse en bas,
//  séparés par une ligne amovible ; les photos du sujet remplacent les champs
//  écrits. Le bouton « Soumettre à la correction » demande confirmation.
//
//  Fichier source Expo porté : branche `live` de
//  `src/components/event/EventWorkspace.tsx` (décompte de fin en en-tête,
//  volet du sujet, séparateur, volet des réponses, barre d'actions, alerte
//  `AppAlert` de soumission).
//
//  Substitutions SF Symbols : images-outline → photo.on.rectangle.angled ;
//  list → list.bullet.
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventLiveView: View {
    let subject: EvEventSubject
    @ObservedObject var model: EvEventSession
    @Binding var splitRatio: Double
    @Binding var photosVisible: Bool
    let onBack: () -> Void

    @State private var confirmingSubmit = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                EvEventTopBar(title: subject.title, trailing: AnyView(timerText), onBack: onBack)
                EvEventStatementPane(title: subject.title, questions: subject.questions)
                    .frame(height: max(0, geo.size.height * splitRatio))
                EvEventSplitHandle(height: geo.size.height) { delta in
                    splitRatio = min(0.8, max(0.2, splitRatio + delta))
                }
                answersPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                actionBar
                if !model.submitError.isEmpty {
                    Text(model.submitError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.like)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(Theme.surface)
        .alert("Soumettre à la correction ?", isPresented: $confirmingSubmit) {
            Button("Annuler", role: .cancel) {}
            Button("Soumettre") { model.submit() }
        } message: {
            Text("Impossible de revenir en arrière après l’envoi de ta copie.")
        }
    }

    /// Temps de participation restant, affiché en en-tête de l'épreuve.
    private var timerText: some View {
        Text(remainingText)
            .font(.system(size: 15, weight: .black))
            .monospacedDigit()
            .foregroundStyle(Theme.ink)
    }

    /// Reste-t-il du temps de participation ? `formatRemaining` de la source.
    private var remainingText: String {
        let remaining = max(0, model.joinDeadlineDate.timeIntervalSince(model.now))
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Volet bas : champs de réponse, ou pellicule des photos du sujet.
    @ViewBuilder private var answersPane: some View {
        if photosVisible {
            EvEventPhotoSheet(photoUris: model.draft.photoUris) { uris in
                model.attachPhotos(uris)
            }
        } else {
            ScrollView {
                EvEventAnswerFields(
                    questions: subject.questions,
                    answers: model.draft.answers,
                    token: model.token,
                    onAnswer: { questionId, text in model.setAnswer(questionId, text) }
                )
            }
        }
    }

    /// Barre d'actions : bascule champs/photos, puis soumission de la copie.
    private var actionBar: some View {
        HStack(spacing: 10) {
            Button { photosVisible.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: photosVisible ? "list.bullet" : "photo.on.rectangle.angled")
                        .font(.system(size: 15, weight: .semibold))
                    Text(photosVisible ? "Champs de réponse" : "Photos du sujet")
                        .font(.system(size: 12, weight: .heavy))
                }
                .foregroundStyle(Theme.inkSoft)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            }
            .buttonStyle(.plain)

            Button { confirmingSubmit = true } label: {
                Group {
                    if model.submission == .submitting {
                        ProgressView().tint(Color.white)
                    } else {
                        Text(model.submission == .submitted ? "Copie rendue" : "Soumettre à la correction")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(!model.draftHasContent || model.submission != .draft)
            .opacity(!model.draftHasContent || model.submission != .draft ? 0.4 : 1)
            .accessibilityLabel("Soumettre à la correction")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }
}
