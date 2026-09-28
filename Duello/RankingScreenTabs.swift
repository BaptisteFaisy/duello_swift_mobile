import Foundation
import SwiftUI

/// Écran de classements Duello : ligues Elo d'une matière et XP de la semaine.
///
/// Portage SwiftUI de `src/screens/LeaderboardScreen.tsx`,
/// `src/screens/RankingsScreen.tsx` et `src/screens/WeeklyXpRankingScreen.tsx`
/// (ainsi que de la fenêtre `src/components/LeaderboardModal.tsx`). Les
/// libellés, les seuils de ligue et la mise en avant du joueur connecté
/// reprennent les mêmes règles que l'application Expo : `utils/subjectElo.ts`,
/// `utils/subjectLeaderboard.ts` et `utils/weeklyXpLeaderboard.ts`.
///
/// Le kit partagé (`DuelloUI.swift`) fournit les cartes, pastilles, avatars et
/// barres de progression ; ce fichier n'ajoute que la logique de classement et
/// ses lignes. Les données viennent de `DuelloAPI` (voir `socialApi.ts`) avec
/// la session ouverte dans l'environnement.
///
/// Matière classée : « Mathématiques », seule matière ouverte aux défis, comme
/// `MATH_SUBJECT` côté Expo.
///
/// Découpage de l'ancien `RankingsView.swift` (855 lignes, hors limites
/// Duello) en modules à responsabilité claire :
/// - `RankingScreenTabs` — cet écran à onglets « Ligues Elo » / « XP » ;
/// - `RankingSubjectLeaderboard` — classement d'une matière (ligues Elo) ;
/// - `RankingWeeklyXp` — classement XP de la semaine ;
/// - `RankingModalSheet` — version feuille du classement ;
/// - `RankingLoadStateViews` — état de chargement et carte d'état ;
/// - `RankingRowViews` — lignes de classement et séparateur ;
/// - `RankingEloLeagues` / `RankingWeeklyXpLeagues` — ligues et seuils ;
/// - `RankingRowBuilder` — fusion, tri et formatage des lignes.
///
/// Aucun type, membre ni signature n'a été renommé. Seuls les membres
/// autrefois `private` et désormais partagés entre fichiers sont passés
/// `internal`, nom, type et corps inchangés.

// MARK: - Écran à onglets

/// Écran à onglets « Ligues Elo » / « XP », équivalent de
/// `LeaderboardScreen.tsx` : les deux classements d'une même matière dans une
/// seule vue, **balayables** (`OrderedTabPager`), sans barre de portée (le
/// classement reste sur « Moi »).
///
/// `eloOnly` (coupe de Défis) masque l'accès aux XP, `xpOnly` (coupe
/// d'Entraînement) masque l'accès aux ligues Elo : dans les deux cas la puce
/// d'onglet disparaît et le geste de balayage est désactivé, comme
/// `singleSection` de la source.
struct RankingsView: View {
    /// Onglets de l'écran, dans l'ordre de `SECTIONS` de `LeaderboardScreen.tsx`.
    enum RankingsTab: String, CaseIterable, Identifiable {
        case subject
        case weeklyXp

        var id: String { rawValue }

        /// Libellé affiché dans la barre d'onglets (« Ligues Elo » / « XP »).
        var label: String { section.label }

        /// Section du ruban balayable (`LEADERBOARD_SECTIONS`).
        var section: SwipeLeaderboardSections.Section {
            switch self {
            case .subject: return .elo
            case .weeklyXp: return .xp
            }
        }
    }

    /// Matière classée (« Mathématiques »).
    var subject: String = "Mathématiques"
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

    /// Onglet ouvert au premier affichage.
    private let initialTab: RankingsTab

    /// - Parameters:
    ///   - initialTab: onglet ouvert au premier affichage.
    ///   - subject: matière classée.
    ///   - scope: portée du classement (« Moi », « Classe » ou « Prépas »).
    ///   - eloOnly: masque l'accès au classement XP.
    ///   - xpOnly: masque l'accès aux ligues Elo.
    init(
        initialTab: RankingsTab = .subject,
        subject: String = "Mathématiques",
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
        self.initialTab = initialTab
    }

    var body: some View {
        SwipeLeaderboardRibbon(
            subject: subject,
            initialSection: initialTab.section,
            scope: scope,
            eloOnly: eloOnly,
            xpOnly: xpOnly,
            onOpenProfile: onOpenProfile,
            onBack: onBack
        )
    }
}
