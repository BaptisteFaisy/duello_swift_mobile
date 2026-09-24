//
//  SwipeLeaderboardRibbon.swift
//  Duello
//
//  Lot 7-G « gestes d'onglets et visibilité de ligne » (préfixe `Swipe`).
//
//  Fichiers source Expo portés :
//    - src/screens/LeaderboardScreen.tsx — l'en-tête (`header` / `topBar` :
//      bouton de retour, barre segmentée des `SECTIONS` « Ligues Elo » / « XP »,
//      compte à rebours `xpResetCountdown`), le mode section unique
//      (`eloOnly` / `xpOnly`) et le ruban `OrderedTabPager` avec son
//      `onPageSelected` ;
//    - src/utils/leaderboardSectionSwipe.ts — décision du swipe
//      (`SwipeLeaderboardSections`).
//
//  Les deux classements d'une matière sont côte à côte, balayables
//  horizontalement, avec la même barre segmentée que `LeaderboardScreen.tsx`.
//  Le rendu du ruban est celui du lot 7-F (`Ui2OrderedTabPager`, portage
//  d'`OrderedTabPager`).
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
    /// Masque l'accès au classement XP : le classement reste sur les ligues Elo
    /// (`eloOnly`, coupe de Défis). En-tête absolu, onglets masqués.
    var eloOnly: Bool = false
    /// Masque l'accès aux ligues Elo : le classement reste sur les XP
    /// (`xpOnly`, coupe d'Entraînement). Onglets masqués.
    var xpOnly: Bool = false
    /// Ferme le classement : chevron de l'en-tête et geste de retour du pager.
    var onBack: (() -> Void)? = nil
    /// Réinitialise le sélecteur chaque fois que la fenêtre est rouverte.
    var active: Bool = true

    /// Section ouverte au premier affichage (`initialSection`).
    private let initialSection: SwipeLeaderboardSections.Section

    @State private var section: SwipeLeaderboardSections.Section

    init(
        subject: String = "Mathématiques",
        initialSection: SwipeLeaderboardSections.Section = .elo,
        scope: LeaderboardScope = .me,
        eloOnly: Bool = false,
        xpOnly: Bool = false,
        onBack: (() -> Void)? = nil,
        active: Bool = true
    ) {
        self.subject = subject
        self.scope = scope
        self.eloOnly = eloOnly
        self.xpOnly = xpOnly
        self.onBack = onBack
        self.active = active
        self.initialSection = initialSection
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        Group {
            if eloOnly {
                // `challengesHeader` : en-tête en position absolue, transparent,
                // au-dessus du classement qui défile dessous.
                pager
                    .overlay(alignment: .top) { header }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    pager
                }
            }
        }
        .background(Theme.background)
        // `active` (LeaderboardScreen.tsx:100-104) : la fenêtre rouverte repart
        // de la section initiale.
        .onChange(of: active) { isActive in
            if isActive { section = initialSection }
        }
    }

    // MARK: Sections

    /// Une seule section accessible : onglets et balayage disparaissent.
    private var singleSection: Bool { eloOnly || xpOnly }

    /// Sections montées dans le ruban (`sectionPages` de la source) : les deux,
    /// ou la seule autorisée par `eloOnly` / `xpOnly`.
    private var sections: [SwipeLeaderboardSections.Section] {
        if eloOnly { return [.elo] }
        if xpOnly { return [.xp] }
        return SwipeLeaderboardSections.sections
    }

    /// Index de la section ouverte dans le ruban.
    private var pageIndex: Int {
        sections.firstIndex(of: section) ?? 0
    }

    // MARK: En-tête

    /// En-tête (`header`) : barre du haut puis 6 pt de marge basse.
    ///
    /// `paddingHorizontal: 20` de `header` est annulé par le
    /// `marginHorizontal: -20` de `topBar` : la barre est donc pleine largeur,
    /// sans marge horizontale propre.
    private var header: some View {
        topBar
            .padding(.bottom, 6)
    }

    /// Barre du haut (`topBar`) : minHeight 48, contenu centré.
    private var topBar: some View {
        HStack(spacing: 0) {
            backButton
                .padding(.leading, singleSection ? 24 : 0)
            if !singleSection {
                segmentedTabs
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        // `xpResetCountdown` : superposé, remplissant la barre, centré.
        .overlay {
            if section == .xp {
                xpResetCountdown
            }
        }
    }

    /// Retour de l'en-tête (`BackButton` de la source) : chevron d'encre, sans
    /// fond. Cadre 36×36 (`backButton`) contraint par les minima 40×40 du
    /// `BackButton` → 40×40 rendus ; pictogramme 21 pt décalé de 4 pt à gauche
    /// (`translateX(-4)`).
    private var backButton: some View {
        Button {
            onBack?()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.ink)
                .offset(x: -4)
                .frame(width: 36, height: 36)
                .frame(minWidth: 40, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fermer le classement")
    }

    /// Barre segmentée des sections (`tabs` + `topTabs`) : conteneur gris,
    /// onglets de largeur égale, sélection en encre sur libellé blanc.
    private var segmentedTabs: some View {
        HStack(spacing: 3) {
            ForEach(sections) { item in
                Button {
                    select(item)
                } label: {
                    Text(item.label)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(section == item ? Theme.white : Theme.mutedSurfaceText)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(section == item ? Theme.primary : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
        .padding(.trailing, 36)
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
                        // `lineHeight: 18` → `lineSpacing = 18 − 13`.
                        .lineSpacing(5)
                        .foregroundStyle(Theme.ink)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(parts.joined(separator: " "))
        }
        // `pointerEvents: 'none'`.
        .allowsHitTesting(false)
    }

    // MARK: Ruban

    /// Pager des sections : balayage autorisé seulement à deux sections.
    private var pager: some View {
        Ui2OrderedTabPager(
            pageCount: sections.count,
            page: pageIndex,
            onPageSelected: selectSection,
            onBack: onBack,
            swipeEnabled: !singleSection
        ) {
            pages
        }
    }

    /// Les sections montées, côte à côte : le voisin apparaît sous le doigt.
    private var pages: some View {
        HStack(spacing: 0) {
            ForEach(sections) { item in
                ribbonPage(page(for: item))
            }
        }
    }

    /// Contenu d'une section.
    @ViewBuilder
    private func page(for item: SwipeLeaderboardSections.Section) -> some View {
        switch item {
        case .elo:
            // `contentTopInset: 30` (section unique) : 24 ici, les 6 pt du haut
            // étant déjà portés par `SubjectLeaderboardView`
            // (`.padding(.top, 6)`), qui n'expose pas encore ce réglage.
            SubjectLeaderboardView(subject: subject, scope: scope)
                .padding(.top, eloOnly ? 24 : 0)
        case .xp:
            // La page XP porte son propre défilement (le contenu RN le fait
            // lui-même) : `scrollContent` de `WeeklyXpRankingScreen.tsx`.
            ScrollView {
                WeeklyXpRankingView(subject: subject)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
            }
        }
    }

    /// Une page du ruban : contenu à la largeur d'une page du pager.
    private func ribbonPage<Content: View>(_ content: Content) -> some View {
        content.frame(maxWidth: .infinity)
    }

    // MARK: Sélection

    /// Sélection par un onglet ou par le geste (`onPageSelected`).
    private func select(_ item: SwipeLeaderboardSections.Section) {
        guard item != section else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            section = item
        }
    }

    /// Sélection indexée du pager (geste horizontal déjà décidé par le pager).
    private func selectSection(_ index: Int) {
        guard sections.indices.contains(index) else { return }
        select(sections[index])
    }
}
