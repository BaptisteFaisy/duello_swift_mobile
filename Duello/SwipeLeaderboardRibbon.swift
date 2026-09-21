//
//  SwipeLeaderboardRibbon.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichiers source Expo portés :
//    - src/screens/LeaderboardScreen.tsx — ruban `OrderedTabPager` des
//      `SECTIONS` (« Ligues Elo », « XP ») et son `onPageSelected` ;
//    - src/utils/leaderboardSectionSwipe.ts — décision du swipe
//      (`SwipeLeaderboardSections`).
//
//  Surface neuve : les deux classements d'une matière côte à côte, balayables
//  horizontalement, avec les mêmes puces que `RankingsView` (déjà livré, non
//  modifié). Le rendu du ruban est celui du lot 7-F
//  (`Ui2OrderedTabPager`, portage d'`OrderedTabPager`).
//
//  Limite documentée : `RankingsView` empile ses classements dans un
//  `ScrollView` parent ; ici chaque page porte son propre `ScrollView`, car le
//  pager impose une largeur de page et découpe (`clipped()`) le débordement.
//  Aucun écran existant n'est monté sur cette vue : le câblage reste à faire.
//
import SwiftUI

/// Ruban « Ligues Elo » / « XP » d'un classement de matière, geste compris
/// (`LeaderboardScreen.tsx`).
struct SwipeLeaderboardRibbon: View {

    /// Matière classée, transmise telle quelle aux deux classements
    /// (« Mathématiques »).
    let subject: String

    @State private var section: SwipeLeaderboardSections.Section

    init(
        subject: String = "Mathématiques",
        initialSection: SwipeLeaderboardSections.Section = .elo
    ) {
        self.subject = subject
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chips
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Ui2OrderedTabPager(
                pageCount: SwipeLeaderboardSections.sections.count,
                page: pageIndex,
                onPageSelected: selectSection
            ) {
                pages
            }
        }
        .background(Theme.background)
    }

    /// Index de la section ouverte dans le ruban.
    private var pageIndex: Int {
        SwipeLeaderboardSections.sections.firstIndex(of: section) ?? 0
    }

    /// Puces d'onglet : même motif que `RankingsView` (`DuelloChip`).
    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(SwipeLeaderboardSections.sections) { item in
                DuelloChip(title: item.label, selected: section == item) {
                    select(item)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Les deux sections côte à côte : le voisin apparaît sous le doigt.
    private var pages: some View {
        HStack(spacing: 0) {
            ribbonPage(SubjectLeaderboardView(subject: subject))
            ribbonPage(WeeklyXpRankingView(subject: subject))
        }
    }

    /// Une page du ruban : contenu défilant, largeur d'une page du pager.
    private func ribbonPage<Content: View>(_ content: Content) -> some View {
        ScrollView {
            content
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
    }

    /// Sélection par une puce ou par le geste (`onPageSelected`).
    private func select(_ item: SwipeLeaderboardSections.Section) {
        guard item != section else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            section = item
        }
    }

    /// Sélection indexée du pager (geste horizontal déjà décidé par le pager).
    private func selectSection(_ index: Int) {
        guard SwipeLeaderboardSections.sections.indices.contains(index) else { return }
        select(SwipeLeaderboardSections.sections[index])
    }
}
