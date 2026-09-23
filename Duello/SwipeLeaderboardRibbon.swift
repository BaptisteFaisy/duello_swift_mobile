//
//  SwipeLeaderboardRibbon.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichiers source Expo portés :
//    - src/screens/LeaderboardScreen.tsx — ruban `OrderedTabPager` des
//      `SECTIONS` (« Ligues Elo », « XP »), son `onPageSelected` et le compte à
//      rebours de remise à zéro (`xpResetCountdown`, section XP) ;
//    - src/utils/leaderboardSectionSwipe.ts — décision du swipe
//      (`SwipeLeaderboardSections`).
//
//  Les deux classements d'une matière sont côte à côte, balayables
//  horizontalement, avec les mêmes puces que `RankingsView` (déjà livré, non
//  modifié). Le rendu du ruban est celui du lot 7-F
//  (`Ui2OrderedTabPager`, portage d'`OrderedTabPager`).
//
//  Chaque page porte son propre `ScrollView` : le pager impose une largeur de
//  page et découpe (`clipped()`) le débordement ; le classement Elo y ancre
//  aussi son dock « Moi · rang ».
//
import SwiftUI

/// Ruban « Ligues Elo » / « XP » d'un classement de matière, geste compris
/// (`LeaderboardScreen.tsx`).
struct SwipeLeaderboardRibbon: View {

    /// Matière classée, transmise telle quelle aux deux classements
    /// (« Mathématiques »).
    let subject: String
    /// Portée du classement : « Moi » par défaut.
    var scope: LeaderboardScope = .me

    @State private var section: SwipeLeaderboardSections.Section

    init(
        subject: String = "Mathématiques",
        initialSection: SwipeLeaderboardSections.Section = .elo,
        scope: LeaderboardScope = .me
    ) {
        self.subject = subject
        self.scope = scope
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
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

    /// En-tête : puces d'onglet, puis le compte à rebours sur la section XP.
    private var header: some View {
        HStack(spacing: 12) {
            chips
            if section == .xp {
                Spacer(minLength: 8)
                xpResetCountdown
            }
        }
    }

    /// Puces d'onglet : même motif que `RankingsView` (`DuelloChip`), libellés
    /// « Ligues Elo » et « XP » (`SECTIONS`).
    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(SwipeLeaderboardSections.sections) { item in
                DuelloChip(title: item.label, selected: section == item) {
                    select(item)
                }
            }
        }
    }

    /// Compte à rebours avant la remise à zéro du classement XP
    /// (`xpResetCountdown`), rafraîchi chaque seconde.
    private var xpResetCountdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let parts = weeklyXpResetCountdownParts(week: WeeklyXP.weekKey(), now: context.date)
            HStack(spacing: 12) {
                ForEach(parts.indices, id: \.self) { index in
                    Text(parts[index])
                        .font(.system(size: 13, weight: .black).monospacedDigit())
                        .tracking(0.5)
                        .foregroundStyle(Theme.ink)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(parts.joined(separator: " "))
        }
    }

    /// Les deux sections côte à côte : le voisin apparaît sous le doigt.
    private var pages: some View {
        HStack(spacing: 0) {
            ribbonPage(SubjectLeaderboardView(subject: subject, scope: scope))
            ribbonPage(xpPage)
        }
    }

    /// Page XP hebdo : elle porte son propre défilement.
    private var xpPage: some View {
        ScrollView {
            WeeklyXpRankingView(subject: subject)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 28)
        }
    }

    /// Une page du ruban : contenu à la largeur d'une page du pager.
    private func ribbonPage<Content: View>(_ content: Content) -> some View {
        content.frame(maxWidth: .infinity)
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
