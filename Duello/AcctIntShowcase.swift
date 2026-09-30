//
//  AcctIntShowcase.swift
//  Duello
//
//  LOT 17 — vitrine du profil de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Assemble les composants du lot 10-E (`AcctShow*`, `AcctEvo*`) dans l'ordre
//  de `src/screens/AccountScreen.tsx` : vitrine de ligue (l. 2738-2810),
//  bandeau de repères (l. 2905), « Évolution de l’XP » (l. 2918), « Évolution
//  de l’Elo » (l. 3027), « Évolution des notes » (l. 3222), « Évolution du
//  temps » (l. 3332) et « Historique des notes » (l. 3653-3698).
//
//  Port de src/screens/AccountScreen.tsx (vitrine du profil, l. 2738-3698).
//
//  Composants branchés indirectement : `AcctShowLeagueBadge` (dessiné par
//  `AcctShowLeagueCard`), `AcctShowGranularityTabs` (dans les sections de
//  série) et `AcctShowLevelProgress` (dans `AcctShowStatsPanel`).
//
//  Vague 6 (lot S04, 2026-09-30) — raccords posés :
//    - Courbe « Évolution des notes » : `points:` vient du journal local
//      (`CorrectionGradeStore`, clé `prepapp-correction-grade-history:v1`) via
//      `AcctIntData.gradePoints`, comme `correctionGradePeriods` de la source.
//    - Section « Historique des notes » : `RankingGradeHistory.buildGradeHistory`
//      + `AcctGradeHistoryCard`, réservée au profil propre (l. 3653-3698).
//    - Courbe « Évolution du temps » : `buckets:` vient des sessions
//      d'entraînement locales (`ChartActivitySessionStore`) via
//      `AcctIntData.timeBuckets`, comme `timeBuckets` de la source (l. 1905).
//    - Tuiles « RANG XP »/« RANG ELO » : rangs « Moi » chargés par
//      `AcctProfileRanksController` et rendus par `RankingProfileRanks.profileRankTile`.
//
//  Écart assumé (donnée absente du portage local, jamais inventée) :
//    - Succès par matière : le regroupement item → matière dépend du catalogue
//      d'exercices, non relié ici ; la section n'est plus rendue (la source la
//      masque : `AccountScreen.tsx`, l. 3418-3456).
//
//  L'abonnement Premium se lit sur le drapeau local (`ConsentPremiumGate`, la
//  même entrée que `PremCodeSync` écrit). La présence en ligne est lue sur
//  `SocPresenceStore` (PR #426).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Vitrine de profil de l'onglet « Mon compte » (le compte connecté lui-même).
///
/// `@MainActor` : la vue possède `AcctProfileRanksController`, isolé au fil
/// principal, et l'initialise dans un initialiseur de propriété (non isolé par
/// défaut) — même motif que `AcctIntDirectorySheet`.
@MainActor
struct AcctIntShowcase: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    /// Période commune aux deux courbes (`xpGranularity`/`eloGranularity`).
    @State private var granularity: ChartTimeGranularity = .day
    /// Matière suivie par la courbe d'Elo ; `nil` = « Toutes ».
    @State private var eloSubject: String?
    /// Explication du blason retournable, écartée au premier « compris ».
    @State private var photoHintVisible = true
    /// Rangs « Moi » du profil consulté (`useProfileLeaderboardRanks`).
    @StateObject private var ranks = AcctProfileRanksController()
    /// XP de la semaine dans la matière classée, relus du journal d'activité.
    @State private var weeklyXp: Double?
    /// Page dédiée « Tout voir » de l'historique des notes (`setPage('history')`).
    @State private var historyOpen = false

    var body: some View {
        VStack(spacing: 0) {
            photoHint
            identityCard
            AcctShowStatsPanel(
                overview: AcctIntData.overviewStats(
                    totalXp: progress.totalXp,
                    elo: elo,
                    streakDays: progress.currentStreak(),
                    programPercent: progress.competitionProgramPercent,
                    exercisesCompleted: progress.exercisesCompleted
                ),
                details: AcctIntData.detailStats(
                    level: xpSummary.level,
                    progress: progress,
                    rankTiles: rankTiles,
                    programPercent: progress.competitionProgramPercent
                ),
                xpSummary: xpSummary
            )
            // Ordre refondu (`AccountScreen.tsx:3272-3648`) : l'historique passe
            // en tête, puis XP, Elo, Temps, Exos et Moyenne des notes.
            gradeHistorySection
            AcctShowXpSeriesSection(
                points: xpSeriesPoints,
                granularity: $granularity,
                evolutionPercentage: xpEvolution.percentage,
                evolutionAbsolute: xpEvolution.absolute,
                name: name,
                refined: refined
            )
            AcctShowEloSeriesSection(
                points: eloSeriesPoints,
                granularity: $granularity,
                subjects: AcctIntData.eloSubjects(progress),
                subject: $eloSubject,
                evolutionPercentage: eloEvolution.percentage,
                evolutionAbsolute: eloEvolution.absolute,
                refined: refined
            )
            AcctShowTimeSeriesSection(
                buckets: timeBuckets,
                granularity: $granularity,
                // `hasTrainingTime` = `viewedActivity.exerciseMinutes > 0`
                // (`AccountScreen.tsx:1902`) : gate de la courbe « temps ».
                hasTrainingTime: progress.exerciseMinutes > 0,
                evolutionPercentage: timeEvolution.percentage,
                evolutionAbsolute: timeEvolution.absolute,
                refined: refined
            )
            if refined {
                AcctShowExosSeriesSection(
                    buckets: exosBuckets,
                    granularity: $granularity,
                    evolutionPercentage: exosEvolution.percentage,
                    evolutionAbsolute: exosEvolution.absolute
                )
            }
            AcctShowGradeSeriesSection(
                points: gradePoints,
                granularity: $granularity,
                evolutionPercentage: gradeEvolution.percentage,
                evolutionAbsolute: gradeEvolution.absolute,
                refined: refined
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
        // Rangs « Moi » : les scores locaux d'abord, puis le réseau (`enabled`
        // n'est vrai qu'en développement, comme `USE_REFINED_OVERVIEW`).
        .task {
            await loadWeeklyXp()
            await ranks.update(rankInput)
        }
        .onChange(of: rankInput) { input in
            ranks.update(input)
        }
        .fullScreenCover(isPresented: $historyOpen) {
            GradeHistoryScreen(rows: fullGradeHistoryRows) {
                historyOpen = false
            }
        }
    }

    /// `USE_REFINED_OVERVIEW` : variante de développement, qui porte le mode
    /// affiné « Trade Republic » de la vitrine.
    private var refined: Bool { AcctEvoConstants.useRefinedOverview }

    /// Section « Historique des notes » (`AccountScreen.tsx:3272-3325`),
    /// réservée au profil propre. En affiné, l'en-tête disparaît : seule la
    /// carte flotte sur la page (`historySection`), avec son lien « Tout voir ».
    @ViewBuilder
    private var gradeHistorySection: some View {
        if refined {
            historyBody
                .padding(.vertical, 14)
                .padding(.top, 28)
                .padding(.horizontal, 12)
        } else {
            AcctShowSectionCard(
                icon: "albums-outline",
                iconColor: ChartGoogleGColors.blue,
                title: "Historique des notes"
            ) {
                historyBody
            }
        }
    }

    /// Le contenu de l'historique : état vide, ou carte d'aperçu avec « Tout voir ».
    @ViewBuilder
    private var historyBody: some View {
        if gradeHistoryRows.isEmpty {
            AcctShowChartEmpty(
                icon: "albums-outline",
                message: "Ton historique démarrera dès ta première correction d’exercice, de colle, d’annale ou de défi."
            )
        } else {
            AcctGradeHistoryCard(
                rows: gradeHistoryRows,
                onSeeAll: refined ? { historyOpen = true } : nil,
                hasMore: refined && fullGradeHistoryRows.count > gradeHistoryRows.count,
                refined: refined
            )
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

    /// Notes de correction du compte, relues du journal local.
    private var correctionGrades: [CorrectionGradeEntry] {
        AcctIntData.correctionGrades()
    }

    /// Courbe des notes, moyennée par période (`correctionGradePeriods`).
    private var gradePoints: [ChartCorrectionPeriodPoint] {
        AcctIntData.gradePoints(correctionGrades, granularity: granularity)
    }

    /// Pastille d'évolution des notes (`gradeEvolutionPercentage`/`Absolute`).
    private var gradeEvolution: (percentage: Double, absolute: Double) {
        latestEvolution(gradePoints.map(\.score))
    }

    /// Lignes de l'historique des notes (`gradeHistoryRows`).
    private var gradeHistoryRows: [GradeHistoryRow] {
        AcctIntData.gradeHistoryRows(correctionGrades)
    }

    /// `gradeHistoryFullRows` : toutes les notes, pour la page « Tout voir ».
    private var fullGradeHistoryRows: [GradeHistoryRow] {
        RankingGradeHistory.buildGradeHistory(correctionGrades, limit: correctionGrades.count)
    }

    /// Colonnes de la courbe du temps (`timeBuckets`).
    private var timeBuckets: [ChartTimeBucket] {
        AcctIntData.timeBuckets(progress, granularity: granularity)
    }

    /// `timeEvolutionPercentage`/`Absolute` : variation des minutes par période.
    private var timeEvolution: (percentage: Double, absolute: Double) {
        latestEvolution(timeBuckets.map(\.minutes))
    }

    /// `exosBuckets` : exercices terminés par période (`buildExerciseCountSeries`).
    private var exosBuckets: [ChartExerciseBucket] {
        let sessions = ChartActivitySessionStore.load()
        let dates = sessions.map(\.at)
            + progress.eloHistory.map(\.at)
            + progress.xpHistory.map(\.at)
        let start = dates.filter { $0.isFinite && $0 > 0 }.min()
        return ChartTimeSeries.buildExerciseCountSeries(
            sessions: sessions,
            granularity: granularity,
            registeredAt: start
        )
    }

    /// `exosEvolutionPercentage`/`Absolute` : variation des exos par période.
    private var exosEvolution: (percentage: Double, absolute: Double) {
        latestEvolution(exosBuckets.map(\.exercises))
    }

    /// Entrée des rangs « Moi » (`useProfileLeaderboardRanks`).
    private var rankInput: AcctProfileRanksController.Input {
        AcctProfileRanksController.Input(
            enabled: AcctEvoConstants.useRefinedOverview,
            cohort: eloLeaderboardCohortForProfile(EloLeaderboardAcademicProfile(
                track: session.profile.track,
                year: session.profile.year,
                specialty: session.profile.specialty,
                currentTrack: session.profile.academicPath?.currentTrack
            )),
            week: WeeklyXP.weekKey(),
            viewed: RankingProfileRanks.Viewed(
                id: DuelloAPI.publicProfileId(email: session.profile.email),
                displayName: name,
                prepName: session.profile.prepName
            ),
            hideIdentity: !session.profile.isPublic,
            mathElo: progress.subjectElos[RankingProfileRanks.subject].map { Double($0) },
            weeklyXp: weeklyXp,
            scoresReady: true,
            token: session.token
        )
    }

    /// Tuiles « RANG XP » / « RANG ELO » (`profileRankTile`).
    private var rankTiles: (xp: ChartPerformanceOverviewStat, elo: ChartPerformanceOverviewStat) {
        (
            RankingProfileRanks.profileRankTile(
                rank: ranks.xpRank,
                loading: ranks.xpLoading,
                label: "RANG XP",
                icon: "medal-outline",
                color: ChartGoogleGColors.blue,
                leaderboardName: "classement XP de la semaine"
            ),
            RankingProfileRanks.profileRankTile(
                rank: ranks.eloRank,
                loading: ranks.eloLoading,
                label: "RANG ELO",
                icon: "podium-outline",
                color: ChartGoogleGColors.green,
                leaderboardName: "classement Elo"
            )
        )
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

    /// `weeklyActivityXp` : XP réellement gagnés cette semaine dans la matière
    /// classée, relus dans le journal d'activité du compte
    /// (`prepapp-xp-activity`), comme `LeaderboardScreen.tsx:106-142`.
    private func loadWeeklyXp() async {
        let email = session.profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountId = email.isEmpty
            ? RewStorageScope.onboardingAccountStorageId
            : RewStorageScope.userStorageId(email)
        let activity = await EvEventRewardsStore.loadActivity(
            EvEventRewardsDefaultsStorage(accountId: accountId)
        )
        weeklyXp = Double(
            weeklyActivityXp(activity, subject: RankingProfileRanks.subject, week: WeeklyXP.weekKey())
        )
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
