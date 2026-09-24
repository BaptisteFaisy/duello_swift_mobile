//
//  EvEventPresenceViews.swift
//  Duello
//
//  Rail des présents et feuille des vues d'un événement.
//
//  Port de src/components/event/EventPresenceStrip.tsx (rail d'avatars le long
//  du bord droit) et de src/components/event/EventViewersSheet.tsx (onglet des
//  vues ouvert depuis l'œil de la barre d'actions). Le cycle de vie de la
//  socket (`useEventPresence`) est monté par `.evEventPresence(...)`.
//
//  Réductions / divergences assumées (24/09/2026) :
//    - la feuille est présentée par `.sheet` natif (voile, poignée de
//      glissement et fermeture fournis par le système) au lieu de l'animation
//      manuelle translateY + opacité de la source ; titre et états conservés ;
//    - la source replie un échec de chargement sur la liste vide
//      (`catch(() => setViewers([]))`) ; ici l'échec garde son propre état, avec
//      un bouton « Réessayer », pour ne pas confondre « personne n'a vu » et
//      « liste injoignable » ;
//    - la feuille reçoit le jeton de session explicitement (l'API Swift n'a pas
//      de session globale implicite), là où la source lit la session courante ;
//    - l'avatar réutilise `LeaderboardAvatar` : l'initiale est dessinée à
//      `taille × 0,4` (12 pt pour 30 pt) au lieu des 14 pt de la source, écart
//      d'un pixel et demi.
//
//  Cible : iOS 16.
//
import SwiftUI

// MARK: - Rail des présents

/// Rail des présents sur la page d'un événement, le long du bord droit sans le
/// toucher (`EventPresenceStrip`) : icône et prénom de chaque **autre** compte
/// en ligne, pastille verte sur l'icône. La pile part du bas et remonte ; au-delà
/// de la hauteur d'écran, elle défile. Vide, elle ne dessine rien.
struct EvEventPresenceStrip: View {
    let viewers: [EvEventPresenceViewer]
    let ownId: String?

    /// Les autres présents : le sien est retiré de la pile (`others`).
    private var others: [EvEventPresenceViewer] {
        viewers.filter { $0.id != ownId }
    }

    var body: some View {
        if others.isEmpty {
            EmptyView()
        } else {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(others) { viewer in
                                EvEventPresencePerson(viewer: viewer)
                            }
                        }
                        .frame(width: 64)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .padding(.top, proxy.safeAreaInsets.top + 64)
                .padding(.bottom, proxy.safeAreaInsets.bottom + 84)
            }
        }
    }
}

/// Un présent du rail : avatar 30×30 à pastille verte, prénom en dessous.
struct EvEventPresencePerson: View {
    let viewer: EvEventPresenceViewer

    var body: some View {
        VStack(spacing: 2) {
            SocialAvatarPresence(online: true, dotSize: 10) {
                LeaderboardAvatar(
                    initial: initial,
                    photoUri: viewer.photoUri,
                    size: 30,
                    background: Theme.border,
                    foreground: Theme.inkSoft
                )
            }
            Text(viewer.displayName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 64)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewer.displayName), en ligne")
    }

    /// Première lettre du prénom, en capitale (repli sans photo).
    private var initial: String {
        String(viewer.displayName.prefix(1)).uppercased()
    }
}

/// Rail connecté : lit le store injecté par `.evEventPresence(...)` et le passe
/// au rail pur — la source montait `EventPresenceStrip` avec `presence.viewers`.
struct EvEventPresenceRail: View {
    let ownId: String?

    @EnvironmentObject private var presence: EvEventPresenceStore

    var body: some View {
        EvEventPresenceStrip(viewers: presence.viewers, ownId: ownId)
    }
}

// MARK: - Feuille des vues

/// État de chargement de la liste des vues.
enum EvViewersLoadState: Equatable {
    case loading
    case loaded([EvEventPresenceViewer])
    case failed(String)
}

/// Onglet des vues d'un événement, ouvert depuis l'œil de la barre d'actions
/// (`EventViewersSheet`) : la liste des personnes ayant ouvert la page, les
/// en-ligne d'abord, la pastille verte sur l'icône des présents. Chaque ligne
/// ouvre le profil du compte.
struct EvEventViewersSheet: View {
    let eventId: String
    let token: String?
    let ownId: String?
    /// Vrai lorsque l'identifiant public est actuellement connecté
    /// (`isOnline` du contexte de présence).
    var isOnline: (String) -> Bool = { SocPresenceStore.shared.isOnline($0) }
    /// Ouvre le profil du compte choisi ; `nil` laisse les lignes inactives.
    var onOpenProfile: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var state: EvViewersLoadState = .loading

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Theme.border)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            Text("Vues de l’événement")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 12)
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(Theme.surface)
        .presentationDetents([.fraction(0.75)])
        .task { await load() }
    }

    /// Chargement (jeton), liste, ou état vide.
    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .tint(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        case let .failed(message):
            failedState(message)
        case let .loaded(viewers):
            if viewers.isEmpty {
                Text("Aucune vue pour le moment.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(sorted(viewers)) { viewer in
                            row(viewer)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    /// Charge la liste des vues (`fetchEventViewers`), à l'ouverture.
    private func load() async {
        state = .loading
        do {
            let viewers = try await EvEventPresenceAPI.viewers(eventId: eventId, token: token)
            state = .loaded(viewers)
        } catch {
            state = .failed("Impossible de charger les vues. Vérifie ta connexion et réessaie.")
        }
    }

    /// Les en-ligne d'abord, puis par prénom (`localeCompare(…, 'fr')`).
    private func sorted(_ viewers: [EvEventPresenceViewer]) -> [EvEventPresenceViewer] {
        viewers.sorted { lhs, rhs in
            let lhsOnline = isOnline(lhs.id)
            let rhsOnline = isOnline(rhs.id)
            if lhsOnline != rhsOnline { return lhsOnline }
            let order = lhs.displayName.compare(
                rhs.displayName,
                options: [.caseInsensitive],
                locale: Locale(identifier: "fr")
            )
            return order == .orderedAscending
        }
    }

    /// Une ligne : avatar à pastille, pseudo, mention « (toi) » pour soi.
    private func row(_ viewer: EvEventPresenceViewer) -> some View {
        Button {
            dismiss()
            onOpenProfile?(viewer.id)
        } label: {
            HStack(spacing: 10) {
                SocialAvatarPresence(online: isOnline(viewer.id), dotSize: 10) {
                    LeaderboardAvatar(
                        initial: String(viewer.displayName.prefix(1)).uppercased(),
                        photoUri: viewer.photoUri,
                        size: 32,
                        background: Theme.border,
                        foreground: Theme.inkSoft
                    )
                }
                Text(viewer.id == ownId ? "\(viewer.displayName) (toi)" : viewer.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onOpenProfile == nil)
        .accessibilityLabel("Voir le profil de \(viewer.displayName)")
    }

    /// Échec de chargement : message et nouvelle tentative.
    private func failedState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                Task { await load() }
            } label: {
                Text("Réessayer")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Theme.surfaceMuted)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Cycle de vie

/// Monte la présence live d'un événement (`useEventPresence.ts`) : démarrage à
/// l'apparition, arrêt à la disparition, fermeture en arrière-plan et
/// réouverture au retour au premier plan. Le store est injecté dans
/// l'environnement, si bien que la barre d'actions lit les mêmes compteurs.
struct EvEventPresenceModifier: ViewModifier {
    let eventId: String
    let token: String?

    @StateObject private var presence = EvEventPresenceStore()
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .environmentObject(presence)
            .task(id: eventId) { presence.start(eventId: eventId, token: token) }
            .onDisappear { presence.stop() }
            .onChange(of: scenePhase) { phase in
                presence.setActive(phase == .active)
            }
    }
}

extension View {
    /// Monte la présence live d'un événement (`useEventPresence`).
    func evEventPresence(eventId: String, token: String?) -> some View {
        modifier(EvEventPresenceModifier(eventId: eventId, token: token))
    }
}
