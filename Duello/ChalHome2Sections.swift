//
//  ChalHome2Sections.swift
//  Duello
//
//  Lot 11-B — accueil des défis : les deux sections (Défis / Événements) et la
//  surface de l'onglet « Défis ».
//
//  Fichier source Expo porté (libellés, icônes et mesures repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx
//        · `ChallengeHomeSection` (ligne 248) : `'challenges' | 'events'` ;
//        · double bouton central `challengeSectionTabs` (lignes 2723-2776) ;
//        · pager `OrderedTabPager` (lignes 2787-2935) qui bascule les deux pages ;
//        · section Événements (ligne 2932) déléguée à `EventsList`.
//
//  Réutilise sans les recréer : `ChalHomeHeader` (barre ELO + zone centrée,
//  `ChalHomeOverview.swift`), `EventsView` (liste des concours blancs) et `Theme`.
//  La carte d'accueil (blason + boutons Défi-Exercice / Défi-Cours) vit déjà dans
//  `ChalHomeActions` : le contenu de la page « Défis » lui est injecté ici, sans
//  duplication.
//
//  Substitutions remplacées : les onglets rendent les glyphes Ionicons exacts
//  (`flash-outline` / `calendar-outline`, `IonIcon`) au lieu de SF Symbols.
//
//  Retour par balayage : le geste est repris par un pager maison (instantané,
//  `animated={false}`) ; le balayage vers la droite depuis les Défis appelle
//  `onBack`, à raccorder par la racine (`MainTabView`) au pager d'onglets
//  (`yieldBackSwipeToTabPager` de `OrderedTabPager`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Espaces en tête d'écran des défis (`ChallengeHomeSection`).
enum ChalHome2Section: String, Equatable, CaseIterable {
    case challenges
    case events

    /// Libellé de l'onglet, mot pour mot de la source.
    var title: String {
        switch self {
        case .challenges: return "Défis"
        case .events: return "Événements"
        }
    }

    /// Glyphe Ionicons de l'onglet, mot pour mot de la source
    /// (`flash-outline` / `calendar-outline`, `ChallengesScreen.tsx:2750,2779`).
    var icon: String {
        switch self {
        case .challenges: return "flash-outline"
        case .events: return "calendar-outline"
        }
    }
}

/// Double bouton Défis / Événements, posé au centre exact de la barre grise
/// (`challengeSectionTabs`). Il partage l'état de section avec le pager.
struct ChalHome2SectionTabs: View {
    @Binding var section: ChalHome2Section
    /// Allume la pastille « nouvel événement » sur l'onglet Événements tant que
    /// la section n'est pas affichée (`hasUnseenEvents` de la source).
    var hasUnseenEvents: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ChalHome2Section.allCases, id: \.self) { item in
                tab(item)
            }
        }
        .padding(2)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// Un onglet : icône + libellé, encre pleine quand il est sélectionné.
    private func tab(_ item: ChalHome2Section) -> some View {
        let selected = section == item
        let showsNewDot = hasUnseenEvents && item == .events && !selected
        return Button {
            section = item
        } label: {
            HStack(spacing: 4) {
                IonIcon(name: item.icon, size: 14, color: selected ? Theme.surface : Theme.inkSoft)
                Text(item.title)
                    .font(.system(size: 12, weight: .heavy))
                // Pastille « nouveau » : un événement ajouté au catalogue se
                // repère depuis l'accueil Défis, hors section seulement.
                if showsNewDot {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 8, height: 8)
                }
            }
            .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
            .frame(minHeight: 30)
            .padding(.horizontal, 12)
            .background(selected ? Theme.ink : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityLabel(showsNewDot ? "\(item.title), nouvel événement" : item.title)
    }
}

/// Pager des deux sections (`OrderedTabPager`) : la page Défis à gauche, la
/// page Événements à droite. Le balayage horizontal bascule de l'une à l'autre.
///
/// `animated={false}` de la source (`ChallengesScreen.tsx:2812`) : la bascule
/// est **instantanée**, sans la transition animée que `TabView(.page)` imposait.
/// Le balayage vers la droite depuis les Défis est rendu au pager d'onglets
/// parent (`yieldBackSwipeToTabPager`) : `onBack` sert de repli quand aucun
/// pager parent n'écoute le geste.
struct ChalHome2SectionPager<ChallengesContent: View, EventsContent: View>: View {
    @Binding var section: ChalHome2Section
    /// Retour par balayage vers Entraînement (`onBack` de `OrderedTabPager`).
    var onBack: (() -> Void)? = nil
    @ViewBuilder var challenges: () -> ChallengesContent
    @ViewBuilder var events: () -> EventsContent

    /// Distance minimale de balayage qui bascule de section.
    private let switchThreshold: CGFloat = 60

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            HStack(spacing: 0) {
                challenges()
                    .frame(width: width, alignment: .top)
                events()
                    .frame(width: width, alignment: .top)
            }
            .frame(width: width * 2, alignment: .leading)
            // Aucune animation : la section change d'un coup, comme la source.
            .offset(x: section == .events ? -width : 0)
            .contentShape(Rectangle())
            // `simultaneousGesture` : le balayage horizontal ne prend pas le pas
            // sur le défilement vertical des pages.
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        let dx = value.translation.width
                        if dx <= -switchThreshold, section == .challenges {
                            section = .events
                        } else if dx >= switchThreshold {
                            if section == .events {
                                section = .challenges
                            } else {
                                onBack?()
                            }
                        }
                    }
            )
        }
        .clipped()
    }
}

/// Surface complète de l'onglet « Défis » : la barre ELO surmontée du double
/// bouton de section, puis le pager des deux pages.
///
/// L'appelant fournit le contenu de chaque page (carte d'accueil + annonces pour
/// « Défis », `EventsView` pour « Événements ») : la surface n'impose rien sur
/// leur composition.
struct ChalHome2HomeSurface<ChallengesContent: View, EventsContent: View>: View {
    /// Cote affichée en tête de barre (`formatElo(overallElo)`).
    var elo: String
    @Binding var section: ChalHome2Section
    /// Allume la pastille « nouvel événement » sur l'onglet Événements.
    var hasUnseenEvents: Bool = false
    var onOpenLeaderboard: () -> Void
    /// Retour par balayage vers l'onglet Entraînement (`onBack` de
    /// `OrderedTabPager`) : posé par la racine, absent ⇒ geste inerte.
    var onBack: (() -> Void)? = nil
    @ViewBuilder var challenges: () -> ChallengesContent
    @ViewBuilder var events: () -> EventsContent

    var body: some View {
        VStack(spacing: 0) {
            ChalHomeHeader(
                elo: elo,
                centered: AnyView(
                    ChalHome2SectionTabs(section: $section, hasUnseenEvents: hasUnseenEvents)
                ),
                onOpenLeaderboard: onOpenLeaderboard
            )
            ChalHome2SectionPager(
                section: $section,
                onBack: onBack,
                challenges: challenges,
                events: events
            )
        }
        .background(Theme.background)
    }
}
