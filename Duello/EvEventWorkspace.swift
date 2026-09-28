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
//  (aiguillage des phases, barre du haut `EventTopBar`, onglets `SectionTab`,
//  geste de retour `useEventBackSwipe`).
//
//  Icône Ionicons : le chevron retour d'`AppPressable`/`BackButton` est
//  `chevron-back` (21 pt) dans un cadre de 36×36, comme la source.
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
    /// Ouvre le profil d'un participant (classement, chat) ; `nil` laisse les
    /// lignes inactives.
    var onOpenProfile: ((String) -> Void)? = nil

    @StateObject private var model: EvEventSession
    @State private var section: EvEventSection = .correction
    @State private var splitRatio: Double = 0.5
    @State private var photosVisible = false

    init(
        event: EvEvent,
        email: String,
        token: String?,
        onBack: @escaping () -> Void,
        onOpenProfile: ((String) -> Void)? = nil
    ) {
        self.event = event
        self.email = email
        self.token = token
        self.onBack = onBack
        self.onOpenProfile = onOpenProfile
        _model = StateObject(wrappedValue: EvEventSession(event: event, email: email, token: token))
    }

    private var subject: EvEventSubject? { EvEventCatalog.subject(for: event.id) }

    /// Identifiant public du compte courant, pour retirer son avatar du rail des
    /// présents et marquer « (toi) » dans la feuille des vues.
    private var ownId: String { DuelloAPI.publicProfileId(email: email) }

    /// Retour au geste : un swipe horizontal vers la droite dans les trois états
    /// de la page (décompte, épreuve, correction/classement). Seuls les gestes
    /// francs partent : plus de 32 pt, ou un flick rapide, avec une nette
    /// dominance horizontale — un défilement vertical garde la main.
    private var backSwipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard dx > 0, dx > abs(dy) * 1.5 else { return }
                let velocityX = value.predictedEndTranslation.width - dx
                let quickFlick = dx > 12 && abs(velocityX) > 380
                if dx > 32 || quickFlick { onBack() }
            }
    }

    var body: some View {
        Group {
            if model.phase == .finished {
                EvEventFinishedView(
                    event: event,
                    model: model,
                    section: $section,
                    onBack: onBack,
                    onOpenProfile: onOpenProfile
                )
            } else if model.phase == .live, let subject {
                EvEventLiveView(
                    subject: subject,
                    model: model,
                    splitRatio: $splitRatio,
                    photosVisible: $photosVisible,
                    onBack: onBack
                )
            } else {
                EvEventWaitingView(
                    event: event,
                    model: model,
                    onBack: onBack,
                    onOpenProfile: onOpenProfile
                )
            }
        }
        .background(Theme.surface)
        .simultaneousGesture(backSwipe)
        // Le rail des présents hérite du store injecté par `.evEventPresence`,
        // qui doit donc rester le plus à l'extérieur (sinon « No
        // ObservableObject found »).
        .overlay { EvEventPresenceRail(ownId: ownId) }
        .evEventPresence(eventId: event.id, token: token)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

// MARK: - Barre du haut

/// Barre du haut de l'espace événement : chevron retour, titre facultatif
/// (texte ou vue, comme le décompte et les onglets) et contenu de droite
/// facultatif (`EventTopBar`). Même géométrie que l'en-tête du classement Elo :
/// barre de 48, chevron 36×36 à 24 du bord gauche, titre centré par un espaceur
/// symétrique.
struct EvEventTopBar: View {
    var title: String? = nil
    var titleView: AnyView? = nil
    var trailing: AnyView? = nil
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                IonIcon(name: "chevron-back", size: 21, color: Theme.ink)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retour")

            if let titleView {
                titleView
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let title {
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
        .frame(minHeight: 48)
        .padding(.horizontal, 24)
    }
}

// MARK: - Onglet de section

/// Onglet de section (Correction / Classement) d'un événement terminé.
/// Le fond commun (gris) vit dans le conteneur, comme `sectionTabs`.
struct EvEventSectionTab: View {
    let label: String
    let selected: Bool
    let onPress: () -> Void

    var body: some View {
        Button(action: onPress) {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(selected ? Color.white : Theme.inkSoft)
                .frame(minHeight: 30)
                .padding(.horizontal, 12)
                .background(selected ? Theme.primary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
