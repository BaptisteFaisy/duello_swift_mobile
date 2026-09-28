//
//  SwipeLeaderboardRibbon.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichiers source Expo portés :
//    - src/screens/LeaderboardScreen.tsx — ruban `OrderedTabPager` des
//      `SECTIONS` (« Ligues Elo », « XP »), ses onglets **segmentés**
//      (`styles.tabs` / `styles.tab`), son `onPageSelected`, le chevron de
//      fermeture (`BackButton`) et le compte à rebours de remise à zéro
//      (`xpResetCountdown`, section XP) ;
//    - src/utils/leaderboardSectionSwipe.ts — décision du swipe
//      (`SwipeLeaderboardSections`).
//
//  Les deux classements d'une matière sont côte à côte, balayables
//  horizontalement. Le mode à onglet unique (`eloOnly` / `xpOnly`) masque les
//  puces et désactive le balayage (`singleSection`). Le rendu du ruban est
//  celui du lot 7-F (`Ui2OrderedTabPager`, portage d'`OrderedTabPager`).
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
    /// Masque l'accès au classement XP (coupe de Défis).
    var eloOnly: Bool = false
    /// Masque l'accès aux ligues Elo (coupe d'Entraînement).
    var xpOnly: Bool = false
    /// Ouvre la fiche d'un joueur (`onOpenProfile`).
    var onOpenProfile: ((String) -> Void)? = nil
    /// Ferme l'écran depuis la première section (`onBack` du pager).
    var onBack: (() -> Void)? = nil

    @State private var section: SwipeLeaderboardSections.Section

    init(
        subject: String = "Mathématiques",
        initialSection: SwipeLeaderboardSections.Section = .elo,
        scope: LeaderboardScope = .me,
        eloOnly: Bool = false,
        xpOnly: Bool = false,
        onOpenProfile: ((String) -> Void)? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.subject = subject
        self.scope = scope
        self.eloOnly = eloOnly
        self.xpOnly = xpOnly
        self.onOpenProfile = onOpenProfile
        self.onBack = onBack
        _section = State(initialValue: initialSection)
    }

    /// Un seul onglet (`singleSection` de la source) : puces masquées, balayage
    /// désactivé.
    private var singleSection: Bool { eloOnly || xpOnly }

    /// Sections effectivement montées (`sectionPages`).
    private var visibleSections: [SwipeLeaderboardSections.Section] {
        if eloOnly { return [.elo] }
        if xpOnly { return [.xp] }
        return SwipeLeaderboardSections.sections
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 6)

            Ui2OrderedTabPager(
                pageCount: visibleSections.count,
                page: pageIndex,
                onPageSelected: selectSection,
                onBack: onBack,
                swipeEnabled: !singleSection
            ) {
                pages
            }
        }
        .background(Theme.background)
    }

    /// Index de la section ouverte dans le ruban.
    private var pageIndex: Int {
        visibleSections.firstIndex(of: section) ?? 0
    }

    /// En-tête : chevron de fermeture, compte à rebours centré sur la section
    /// XP, puis les onglets segmentés (`topBar` de la source).
    private var header: some View {
        ZStack {
            HStack(spacing: 0) {
                if onBack != nil {
                    backButton
                        .padding(.leading, singleSection ? 24 : 0)
                }
                if !singleSection {
                    segmentedTabs
                        .padding(.leading, 8)
                        .padding(.trailing, 36)
                } else {
                    Spacer(minLength: 0)
                }
            }
            if section == .xp {
                xpResetCountdown
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 48)
    }

    /// Chevron de fermeture (`BackButton`, `chevron-back`).
    private var backButton: some View {
        Button { onBack?() } label: {
            IonIcon(name: "chevron-back", size: 21, color: Theme.ink)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fermer le classement")
    }

    /// Onglets segmentés (`styles.tabs` / `styles.tab`) : conteneur gris arrondi,
    /// onglet sélectionné sur fond primaire, libellé blanc.
    private var segmentedTabs: some View {
        HStack(spacing: 3) {
            ForEach(visibleSections) { item in
                Button { select(item) } label: {
                    Text(item.label)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(section == item ? Theme.surface : Theme.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(section == item ? Theme.primary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(section == item ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    /// Compte à rebours avant la remise à zéro du classement XP
    /// (`xpResetCountdown`), rafraîchi chaque seconde.
    private var xpResetCountdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let parts = weeklyXpResetCountdownParts(week: WeeklyXP.weekKey(), now: context.date)
            HStack(spacing: 12) {
                ForEach(parts.indices, id: \.self) { index in
                    Text(parts[index])
                        .font(.system(size: 13, weight: .heavy).monospacedDigit())
                        .tracking(0.5)
                        .foregroundStyle(Theme.ink)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(parts.joined(separator: " "))
        }
    }

    /// Les sections montées côte à côte : le voisin apparaît sous le doigt.
    private var pages: some View {
        HStack(spacing: 0) {
            ForEach(visibleSections) { item in
                ribbonPage(page(for: item))
            }
        }
    }

    /// Page d'une section : le classement Elo ancre son dock, la page XP porte
    /// son propre défilement.
    @ViewBuilder
    private func page(for item: SwipeLeaderboardSections.Section) -> some View {
        switch item {
        case .elo:
            SubjectLeaderboardView(subject: subject, scope: scope, onOpenProfile: onOpenProfile)
        case .xp:
            ScrollView {
                WeeklyXpRankingView(subject: subject, scope: scope, onOpenProfile: onOpenProfile)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
            }
        }
    }

    /// Une page du ruban : contenu à la largeur d'une page du pager.
    private func ribbonPage<Content: View>(_ content: Content) -> some View {
        content.frame(maxWidth: .infinity)
    }

    /// Sélection par une puce : la prop contrôlée du pager porte l'animation
    /// (aucun `withAnimation` local, comme `setSection` de la source).
    private func select(_ item: SwipeLeaderboardSections.Section) {
        guard item != section else { return }
        section = item
    }

    /// Sélection indexée du pager (geste horizontal déjà décidé par le pager).
    private func selectSection(_ index: Int) {
        guard visibleSections.indices.contains(index) else { return }
        select(visibleSections[index])
    }
}
