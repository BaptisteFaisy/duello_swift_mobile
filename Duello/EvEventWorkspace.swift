//
//  EvEventWorkspace.swift
//  Duello
//
//  Espace événement : la page sur laquelle arrive l'élève depuis la section
//  Événements, quel que soit le moment. Avant l'épreuve, le décompte puis la
//  salle d'attente ; pendant l'épreuve, le sujet et les champs de réponse ;
//  après, la correction puis le classement.
//
//  Fichier source Expo porté : `src/components/event/EventWorkspace.tsx`
//  (aiguillage des phases, barre du haut `EventTopBar`, onglets `SectionTab`).
//  Substitution SF Symbols : le chevron retour d'`AppPressable`/`BackButton`
//  devient `chevron.left`.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Sections d'un événement terminé (`EventSection`).
enum EvEventSection: String, CaseIterable, Identifiable {
    case correction, classement

    var id: String { rawValue }

    /// Libellé d'onglet, mot pour mot de la source.
    var label: String { self == .correction ? "Correction" : "Classement" }
}

struct EvEventWorkspace: View {
    let event: EvEvent
    let email: String
    let token: String?
    let onBack: () -> Void

    @StateObject private var model: EvEventSession
    @State private var section: EvEventSection = .correction
    @State private var splitRatio: Double = 0.5
    @State private var photosVisible = false

    init(event: EvEvent, email: String, token: String?, onBack: @escaping () -> Void) {
        self.event = event
        self.email = email
        self.token = token
        self.onBack = onBack
        _model = StateObject(wrappedValue: EvEventSession(event: event, email: email, token: token))
    }

    private var subject: EvEventSubject? { EvEventCatalog.subject(for: event.id) }

    var body: some View {
        Group {
            if model.phase == .finished {
                EvEventFinishedView(event: event, model: model, section: $section, onBack: onBack)
            } else if model.phase == .live, let subject {
                EvEventLiveView(
                    subject: subject,
                    model: model,
                    splitRatio: $splitRatio,
                    photosVisible: $photosVisible,
                    onBack: onBack
                )
            } else {
                EvEventWaitingView(event: event, model: model, onBack: onBack)
            }
        }
        .background(Theme.surface)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

// MARK: - Barre du haut

/// Barre du haut de l'espace événement : chevron retour, titre facultatif et
/// contenu de droite facultatif (`EventTopBar`).
struct EvEventTopBar: View {
    var title: String? = nil
    var trailing: AnyView? = nil
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retour")

            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }

            if let trailing {
                trailing
            } else {
                Color.clear.frame(width: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Onglet de section

/// Onglet de section (Correction / Classement) d'un événement terminé.
struct EvEventSectionTab: View {
    let label: String
    let selected: Bool
    let onPress: () -> Void

    var body: some View {
        Button(action: onPress) {
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(selected ? Color.white : Theme.inkSoft)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(selected ? Theme.ink : Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
