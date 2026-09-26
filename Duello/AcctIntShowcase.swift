//
//  AcctIntShowcase.swift
//  Duello
//
//  LOT 17 — vitrine du profil de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Assemble les composants du lot 10-E (`AcctShow*`, `AcctEvo*`) dans l'ordre
//  de `src/screens/AccountScreen.tsx` : vitrine de ligue (l. 2738-2810),
//  bandeau de repères (l. 2905), « Évolution de l’XP » (l. 2918), « Évolution
//  de l’Elo » (l. 3027), « Évolution des notes » (l. 3222) et « Évolution du
//  temps » (l. 3332).
//
//  Composants branchés indirectement : `AcctShowLeagueBadge` (dessiné par
//  `AcctShowLeagueCard`), `AcctShowGranularityTabs` (dans les sections de
//  série) et `AcctShowLevelProgress` (dans `AcctShowStatsPanel`).
//
//  Repli documenté (voir `AcctIntData`) : les succès par matière dépendent du
//  catalogue d'exercices, non relié ici. La section correspondante n'est plus
//  rendue (la source la masque : `AccountScreen.tsx`, l. 3418-3456).
//  L'abonnement Premium n'ayant pas de drapeau local, la coche reste masquée
//  (`isPremium: false`). La présence en ligne est lue sur
//  `SocPresenceStore` (PR #426).
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
                    totalXp: progress.totalXp,
                    elo: elo,
                    streakDays: progress.currentStreak(),
                    programPercent: progress.competitionProgramPercent
                ),
                details: AcctIntData.detailStats(level: xpSummary.level, progress: progress),
                xpSummary: xpSummary
            )
            AcctShowXpSeriesSection(
                points: xpSeriesPoints,
                granularity: $granularity,
                evolutionPercentage: 0,
                evolutionAbsolute: 0,
                name: name
            )
            AcctShowEloSeriesSection(
                points: eloSeriesPoints,
                granularity: $granularity,
                subjects: AcctIntData.eloSubjects(progress),
                subject: $eloSubject,
                evolutionPercentage: 0,
                evolutionAbsolute: 0
            )
            AcctShowGradeSeriesSection(
                points: [],
                granularity: $granularity
            )
            AcctShowTimeSeriesSection(
                buckets: [],
                granularity: $granularity
            )
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
    }

    /// Carte d'identité et blason de ligue (`showcaseIdentityRow`).
    private var identityCard: some View {
        AcctShowLeagueCard(
            name: name,
            pathLines: AcctIntData.pathLines(session.profile),
            league: league,
            photoUri: session.profile.photoUri,
            online: SocPresenceStore.shared.isOnline(
                DuelloAPI.publicProfileId(email: session.profile.email)
            )
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
        AcctIntData.xpSummary(totalXp: progress.totalXp)
    }

    /// Courbe d'XP cumulée, regroupée par période (`xpSeries` de la source).
    private var xpSeriesPoints: [ChartXpSeriesPoint] {
        let raw = ChartXpSeries.build(
            history: progress.xpHistory.map { ChartXpEntry(xp: $0.xp, at: $0.at) },
            total: progress.totalXp
        )
        return ChartXpSeries.groupByPeriod(raw, granularity: granularity)
    }

    /// Courbe d'Elo par période, matière choisie (`eloSeries` de la source) :
    /// la valeur de clôture de chaque période est retenue.
    private var eloSeriesPoints: [ChartEloSeriesPoint] {
        let history = progress.eloHistory
            .filter { eloSubject == nil || $0.subject == eloSubject }
            .sorted { $0.at < $1.at }

        var closingByPeriod: [Double: ChartEloSeriesPoint] = [:]
        for entry in history where entry.at > 0 {
            let start = ChartTimeSeries.bucketStart(entry.at, granularity)
            closingByPeriod[start] = ChartEloSeriesPoint(elo: Double(entry.elo), at: start)
        }
        return closingByPeriod.values.sorted { $0.at < $1.at }
    }
}
