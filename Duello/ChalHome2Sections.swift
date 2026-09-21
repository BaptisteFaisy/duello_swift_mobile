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
//  Substitutions SF Symbols (Ionicons → SF Symbols) : flash-outline → bolt ;
//  calendar-outline → calendar.
//
//  Limite assumée : le geste de retour du pager vers l'onglet Entraînement
//  (`onBack` de `OrderedTabPager`) n'est pas repris — `TabView` en style page ne
//  l'expose pas. Le basculement se fait par les onglets ou le balayage natif.
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

    /// Icône de l'onglet (Ionicons → SF Symbols).
    var icon: String {
        switch self {
        case .challenges: return "bolt"
        case .events: return "calendar"
        }
    }
}

/// Double bouton Défis / Événements, posé au centre exact de la barre grise
/// (`challengeSectionTabs`). Il partage l'état de section avec le pager.
struct ChalHome2SectionTabs: View {
    @Binding var section: ChalHome2Section

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
        .accessibilityLabel("Sections de l’accueil des défis")
    }

    /// Un onglet : icône + libellé, encre pleine quand il est sélectionné.
    private func tab(_ item: ChalHome2Section) -> some View {
        let selected = section == item
        return Button {
            section = item
        } label: {
            HStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(item.title)
                    .font(.system(size: 12, weight: .heavy))
            }
            .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
            .frame(minHeight: 30)
            .padding(.horizontal, 12)
            .background(selected ? Theme.ink : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityLabel(item.title)
    }
}

/// Pager des deux sections (`OrderedTabPager`) : la page Défis à gauche, la
/// page Événements à droite. Le balayage horizontal bascule de l'une à l'autre.
struct ChalHome2SectionPager<ChallengesContent: View, EventsContent: View>: View {
    @Binding var section: ChalHome2Section
    @ViewBuilder var challenges: () -> ChallengesContent
    @ViewBuilder var events: () -> EventsContent

    var body: some View {
        TabView(selection: $section) {
            challenges()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tag(ChalHome2Section.challenges)
            events()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tag(ChalHome2Section.events)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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
    var onOpenLeaderboard: () -> Void
    @ViewBuilder var challenges: () -> ChallengesContent
    @ViewBuilder var events: () -> EventsContent

    var body: some View {
        VStack(spacing: 0) {
            ChalHomeHeader(
                elo: elo,
                centered: AnyView(ChalHome2SectionTabs(section: $section)),
                onOpenLeaderboard: onOpenLeaderboard
            )
            ChalHome2SectionPager(
                section: $section,
                challenges: challenges,
                events: events
            )
        }
        .background(Theme.background)
    }
}
