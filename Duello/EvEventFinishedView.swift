//
//  EvEventFinishedView.swift
//  Duello
//
//  Vue d'un événement terminé : sections Correction et Classement en onglets,
//  puis barre d'actions. Le classement reste en attente tant que toutes les
//  copies ne sont pas corrigées ; pour un événement passé, le corrigé, le
//  compte rendu et le classement publié restent consultables.
//
//  Fichier source Expo porté : `EventFinishedView` de
//  `src/components/event/EventWorkspace.tsx`.
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventFinishedView: View {
    let event: EvEvent
    @ObservedObject var model: EvEventSession
    @Binding var section: EvEventSection
    let onBack: () -> Void

    private var subject: EvEventSubject? { EvEventCatalog.subject(for: event.id) }
    private var ownId: String { DuelloAPI.publicProfileId(email: model.email) }

    var body: some View {
        VStack(spacing: 0) {
            EvEventTopBar(title: event.title, onBack: onBack)
            tabs
            sectionBody
            EvEventActionsBar(event: event, token: model.token)
        }
        .background(Theme.surface)
    }

    /// Onglets Correction / Classement.
    private var tabs: some View {
        HStack(spacing: 8) {
            EvEventSectionTab(label: EvEventSection.correction.label, selected: section == .correction) {
                section = .correction
            }
            EvEventSectionTab(label: EvEventSection.classement.label, selected: section == .classement) {
                section = .classement
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    /// Corps de la section choisie : correction, classement ou attente.
    @ViewBuilder private var sectionBody: some View {
        if let results = model.results {
            if section == .correction {
                ScrollView {
                    EvEventCorrectionView(
                        results: results,
                        questions: subject?.questions ?? [],
                        durationMinutes: model.durationMinutes
                    )
                }
            } else if let board = results.leaderboard {
                ScrollView {
                    EvEventLeaderboardView(entries: board, ownId: ownId)
                        .padding(16)
                }
            } else {
                Text(pendingText(results))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Message d'attente du classement, avec la progression des corrections.
    private func pendingText(_ results: EvResultsState) -> String {
        "Le classement sera publié quand toutes les copies seront corrigées (\(results.gradedParticipants)/\(results.participants))."
    }
}
