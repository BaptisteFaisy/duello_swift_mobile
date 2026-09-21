//
//  AcctIntShowcase.swift
//  Duello
//
//  LOT 17 — vitrine du profil de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Assemble les composants du lot 10-E (`AcctShow*`, `AcctEvo*`) dans l'ordre
//  de `src/screens/AccountScreen.tsx` : vitrine de ligue (l. 2738-2810),
//  bandeau de repères (l. 2905), « Évolution de l’XP » (l. 2918), « Évolution
//  de l’Elo » (l. 3027), « Exos réussis par matière » (l. 3355) et pied de
//  période (l. 3444).
//
//  Composants branchés indirectement : `AcctShowLeagueBadge` (dessiné par
//  `AcctShowLeagueCard`), `AcctShowGranularityTabs` (dans les deux sections de
//  série) et `AcctShowLevelProgress` (dans `AcctShowStatsPanel`).
//
//  Replis documentés (voir `AcctIntData`) : XP, complétion de programme, succès
//  par matière et séries horodatées ne sont pas exposés localement ; les
//  sections concernées reçoivent des listes vides et affichent leur état vide.
//  L'abonnement Premium n'ayant pas de drapeau local, la coche est masquée
//  (`isPremium: false`). La présence en ligne n'étant pas publiée non plus, la
//  pastille de présence reste éteinte (`online: false`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Vitrine de profil de l'onglet « Mon compte » (le compte connecté lui-même).
struct AcctIntShowcase: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    /// Période commune aux deux courbes (`xpGranularity`/`eloGranularity`).
    @State private var granularity: ChartTimeGranularity = .day
    /// Matière suivie par la courbe d'Elo ; `nil` = « Toutes ».
    @State private var eloSubject: String?
    /// Explication du blason retournable, écartée au premier « compris ».
    @State private var photoHintVisible = true

    var body: some View {
        VStack(spacing: 0) {
            photoHint
            identityCard
            AcctShowStatsPanel(
                overview: AcctIntData.overviewStats(
                    totalXp: AcctIntData.unavailableXp,
                    elo: elo,
                    streakDays: progress.activeDayCount(),
                    programPercent: AcctIntData.unavailableProgramPercent
                ),
                details: AcctIntData.detailStats(level: xpSummary.level, progress: progress),
                xpSummary: xpSummary
            )
            AcctShowXpSeriesSection(
                points: [],
                granularity: $granularity,
                evolutionPercentage: 0,
                evolutionAbsolute: 0,
                name: name
            )
            AcctShowEloSeriesSection(
                points: [],
                granularity: $granularity,
                subjects: AcctIntData.eloSubjects(progress),
                subject: $eloSubject,
                evolutionPercentage: 0,
                evolutionAbsolute: 0
            )
            AcctShowSubjectSuccessSection(entries: [])
            AcctShowPeriodFooter(value: granularity) { granularity = $0 }
        }
    }

    /// Carte d'identité et blason de ligue (`showcaseIdentityRow`).
    private var identityCard: some View {
        AcctShowLeagueCard(
            name: name,
            pathLines: AcctIntData.pathLines(session.profile),
            league: league,
            photoUri: session.profile.photoUri
        )
    }

    /// Démonstration du blason retournable, tant qu'elle n'est pas écartée.
    @ViewBuilder
    private var photoHint: some View {
        if photoHintVisible, let badgeURL = LeagueBadges.badgeURL(forLeague: league.id) {
            AcctShowLeagueFlipHint(
                badgeURL: badgeURL,
                name: name,
                photoUri: session.profile.photoUri
            ) {
                photoHintVisible = false
            }
            .padding(.bottom, 12)
        }
    }

    /// Nom affiché, replié sur « Élève » quand le profil est vide.
    private var name: String {
        let display = session.profile.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return display.isEmpty ? "Élève" : display
    }

    /// Elo global reconstruit, puis ligue atteinte pour la filière du profil.
    private var elo: Int { AcctIntData.overallElo(progress) }

    /// Ligue de la vitrine (`viewedLeague` = `eloLeagueFor(elo, track)`).
    private var league: EloLeague { eloLeague(for: elo, track: session.profile.track) }

    /// Résumé de niveau d'XP (`viewedXpSummary`).
    private var xpSummary: ChartXpSummary {
        AcctIntData.xpSummary(totalXp: AcctIntData.unavailableXp)
    }
}
