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
//  rendue (la source la masque : `AccountScreen.tsx`, l. 3418-3456). Les
//  courbes des notes et du temps restent vides, faute de store horodaté local.
//  L'abonnement Premium se lit sur le drapeau local (`ConsentPremiumGate`, la
//  même entrée que `PremCodeSync` écrit). La présence en ligne est lue sur
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
                evolutionPercentage: xpEvolution.percentage,
                evolutionAbsolute: xpEvolution.absolute,
                name: name
            )
            AcctShowEloSeriesSection(
                points: eloSeriesPoints,
                granularity: $granularity,
                subjects: AcctIntData.eloSubjects(progress),
                subject: $eloSubject,
                evolutionPercentage: eloEvolution.percentage,
                evolutionAbsolute: eloEvolution.absolute
            )
            AcctShowGradeSeriesSection(
                points: [],
                granularity: $granularity
            )
            AcctShowTimeSeriesSection(
                buckets: [],
                granularity: $granularity,
                // `hasTrainingTime` = `viewedActivity.exerciseMinutes > 0`
                // (`AccountScreen.tsx:1902`) : gate de la courbe « temps ».
                hasTrainingTime: progress.exerciseMinutes > 0
            )
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
        // `AccountScreen.tsx:1865-1869` : perdre la matière suivie (changement
        // de personne ou de filière) remet la courbe sur la synthèse générale.
        .onChange(of: AcctIntData.eloSubjects(progress)) { subjects in
            if let current = eloSubject, !subjects.contains(current) {
                eloSubject = nil
            }
        }
    }

    /// Carte d'identité et blason de ligue (`showcaseIdentityRow`).
    private var identityCard: some View {
        AcctShowLeagueCard(
            name: name,
            pathLines: AcctIntData.pathLines(session.profile),
            isPremium: isPremium,
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

    /// Nom affiché, replié sur « Préparationnaire » quand le profil est vide
    /// (`resolveViewedProfile` : `own.displayName || 'Préparationnaire'`).
    private var name: String {
        let display = session.profile.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return display.isEmpty ? "Préparationnaire" : display
    }

    /// Elo global reconstruit, puis ligue atteinte pour la filière du profil.
    private var elo: Int { AcctIntData.overallElo(progress) }

    /// Ligue de la vitrine (`viewedLeague` = `eloLeagueFor(elo, track)`).
    private var league: EloLeague { eloLeague(for: elo, track: session.profile.track) }

    /// Abonnement Premium du compte connecté (`isViewedPremium`) : la même
    /// entrée locale que `PremCodeSync` écrit, lue sans la modifier.
    private var isPremium: Bool {
        ConsentPremiumGate.isSubscribed(
            accountId: ConsentPremiumGate.accountId(email: session.profile.email),
            now: ConsentPremiumGate.currentMilliseconds()
        )
    }

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
    /// un point par défi joué, puis une valeur de clôture par période.
    private var eloSeriesPoints: [ChartEloSeriesPoint] {
        AcctIntData.eloSeries(progress.eloHistory, subject: eloSubject, granularity: granularity)
    }

    /// Pastille d'évolution de l'XP (`xpEvolutionPercentage`/`Absolute`).
    private var xpEvolution: (percentage: Double, absolute: Double) {
        latestEvolution(xpSeriesPoints.map(\.xp))
    }

    /// Pastille d'évolution de l'Elo (`eloEvolutionPercentage`/`Absolute`).
    private var eloEvolution: (percentage: Double, absolute: Double) {
        latestEvolution(eloSeriesPoints.map(\.elo))
    }

    /// `latestRelativeEvolutionPercentage` + `latestAbsoluteEvolution`
    /// (`utils/accountMetricEvolution.ts`) : variation entre les deux derniers
    /// points affichés, repliée sur 0 en deçà de deux points.
    private func latestEvolution(_ values: [Double]) -> (percentage: Double, absolute: Double) {
        guard values.count >= 2 else { return (0, 0) }
        let current = values[values.count - 1]
        let previous = values[values.count - 2]
        let percentage: Double
        if previous == 0 {
            percentage = current == 0 ? 0 : 100
        } else {
            percentage = ((current - previous) / previous * 100).rounded()
        }
        return (percentage, current - previous)
    }
}
