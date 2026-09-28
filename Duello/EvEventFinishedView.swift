//
//  EvEventFinishedView.swift
//  Duello
//
//  Vue d'un événement terminé : sections Correction et Classement en onglets
//  dans la barre du haut, pastille de statut, puis barre d'actions. Le
//  classement reste en attente tant que toutes les copies ne sont pas
//  corrigées ; pour un événement passé, le corrigé, le compte rendu et le
//  classement publié restent consultables.
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
    /// Ouvre le profil d'un participant (classement) ; `nil` inactif.
    var onOpenProfile: ((String) -> Void)? = nil

    private var subject: EvEventSubject? { EvEventCatalog.subject(for: event.id) }
    private var ownId: String { DuelloAPI.publicProfileId(email: model.email) }

    var body: some View {
        VStack(spacing: 0) {
            // Pas de titre texte : Correction et Classement sont reliés dans la
            // barre, comme le double bouton Défis / Événements de l'accueil.
            EvEventTopBar(titleView: AnyView(tabs), onBack: onBack)
            statusBadgeRow
            sectionBody
            EvEventActionsBar(
                event: event,
                token: model.token,
                ownId: ownId,
                onOpenProfile: onOpenProfile,
                chatOpen: EvEventSchedule.isChatOpen(event, now: model.now)
            )
        }
        .background(Theme.surface)
    }

    /// Onglets Correction / Classement, reliés dans un fond gris commun
    /// (`sectionTabs`).
    private var tabs: some View {
        HStack(spacing: 3) {
            EvEventSectionTab(label: EvEventSection.correction.label, selected: section == .correction) {
                section = .correction
            }
            EvEventSectionTab(label: EvEventSection.classement.label, selected: section == .classement) {
                section = .classement
            }
        }
        .padding(2)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    /// Pastille de statut, alignée à droite sous la barre du haut.
    private var statusBadgeRow: some View {
        HStack {
            Spacer(minLength: 0)
            if let status = EvEventSchedule.statusBadge(event, now: model.now, results: model.results) {
                EvEventStatusBadge(status: status)
            }
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
                    EvEventLeaderboardView(entries: board, ownId: ownId, onOpenProfile: onOpenProfile)
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
