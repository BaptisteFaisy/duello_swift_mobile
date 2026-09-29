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
//  Les onglets sont dessinés ici (capsule noire, pastille blanche, texte encre
//  ou blanc) ; la pastille de statut n'apparaît que pendant l'épreuve
//  (`status === 'en-cours'`).
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

    /// Onglets Correction / Classement, reliés dans une capsule **noire**
    /// (`sectionTabs`) : pastille blanche sur l'onglet choisi, texte encre ;
    /// l'autre onglet reste en blanc.
    private var tabs: some View {
        HStack(spacing: 3) {
            sectionTab(EvEventSection.correction, selected: section == .correction)
            sectionTab(EvEventSection.classement, selected: section == .classement)
        }
        .padding(2)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    /// Un onglet de section : fond blanc et texte encre quand il est choisi,
    /// texte blanc sur la capsule noire sinon (`sectionTab` /
    /// `sectionTabSelected` / `sectionTabText` de `EventWorkspace.tsx:657-693`).
    private func sectionTab(_ item: EvEventSection, selected: Bool) -> some View {
        Button {
            section = item
        } label: {
            Text(item.label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(selected ? Theme.ink : Color.white)
                .frame(minHeight: 30)
                .padding(.horizontal, 12)
                .background(selected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// Pastille de statut, alignée à droite sous la barre du haut : affichée
    /// **seulement pendant l'épreuve** (`status === 'en-cours'`,
    /// `EventWorkspace.tsx:385`) — sur un événement terminé, elle disparaît.
    @ViewBuilder private var statusBadgeRow: some View {
        if let status = EvEventSchedule.statusBadge(event, now: model.now, results: model.results),
           status == .enCours {
            HStack {
                Spacer(minLength: 0)
                EvEventStatusBadge(status: status)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
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
