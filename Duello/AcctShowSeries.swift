//
//  AcctShowSeries.swift
//  Duello
//
//  Vitrine du profil — séries XP, Elo, notes, temps et exos (lot 10-E, préfixe
//  `AcctShow` ; mode affiné « Trade Republic » ajouté à la vague I7).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, l. 3332-3645 : sections « XP gagnée »,
//      « Elo », « Heures travaillées », « Exos réalisés » et « Moyenne des
//      notes » (onglets de période, grande valeur, pastille d'évolution,
//      filtres de catégorie et courbes) en mode `USE_REFINED_OVERVIEW`, et
//      leurs équivalents de production (« Évolution de … »).
//
//  Réutilise `TrendCurve`, `ChartXpChart`, `ChartEloChart`,
//  `ChartCorrectionGradeChart`, `ChartSubjectTimeTrendChart`,
//  `ChartXpSeriesPoint`, `ChartEloSeriesPoint`, `ChartTimeGranularity`,
//  `AcctEvoPerformanceEvolutionPill`, `AcctEvoPerformanceChartLoading`,
//  `ChartGoogleGColors`, `DuelloChip` et l'habillage `AcctShow*`.
//
//  Cible : iOS 16, aucune API iOS 17 ; aucune dépendance externe.
//
import SwiftUI

private func acctShowLatestEvolution(_ values: [Double]) -> (percentage: Double, absolute: Double) {
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

// MARK: - Sections de la vitrine

/// Section « XP gagnée » / « Évolution de l’XP » de la vitrine
/// (`AccountScreen.tsx`, l. 3332-3420).
struct AcctShowXpSeriesSection: View {
    /// Courbe cumulée, de la première à la dernière période.
    let points: [ChartXpSeriesPoint]
    /// Période affichée, liée à l'état de l'écran.
    @Binding var granularity: ChartTimeGranularity
    /// Variation relative entre les deux dernières périodes (`xpEvolutionPercentage`).
    let evolutionPercentage: Double
    /// Variation absolue entre les deux dernières périodes (`xpEvolutionAbsolute`).
    let evolutionAbsolute: Double
    /// Vrai quand la série est chargée ; sinon, indicateur de chargement.
    var isReady: Bool = true
    /// Vrai lorsque la vitrine affiche le profil d'un autre membre.
    var isMember: Bool = false
    /// Nom du profil consulté, pour le sous-titre et les états vides.
    var name: String = ""
    /// `USE_REFINED_OVERVIEW` : tracé unique « Trade Republic ».
    var refined: Bool = false

    var body: some View {
        if refined {
            refinedSection
        } else {
            AcctShowSectionCard(
                icon: "sparkles-outline",
                iconColor: ChartGoogleGColors.blue,
                title: "Évolution de l’XP",
                subtitle: subtitle,
                trailing: pill,
                topPadding: 12
            ) {
                content
            }
        }
    }

    /// Carte affinée : « XP gagnée », grande valeur, onglets puis courbe.
    private var refinedSection: some View {
        AcctShowRefinedCard(
            title: "XP gagnée",
            value: isReady
                ? AnyView(AcctShowRefinedValueRow(
                    value: ExGFormat.xp(points.last?.xp ?? 0),
                    suffix: "XP",
                    percentage: evolutionPercentage,
                    absolute: evolutionAbsolute,
                    unit: .xp
                ))
                : nil
        ) {
            if isReady {
                VStack(alignment: .leading, spacing: 0) {
                    AcctShowRefinedPeriodTabs(value: granularity) { granularity = $0 }
                    refinedCurve
                }
            } else {
                AcctEvoPerformanceChartLoading()
            }
        }
    }

    /// `XpChart` en mode affiné : point à zéro plutôt qu'un vide sans mesure.
    private var refinedCurve: some View {
        let visible = ChartTimeSeries.windowGroupedPoints(points, granularity)
        let curvePoints: [TrendCurvePoint] = visible.isEmpty
            ? [TrendCurvePoint(at: ChartTimeSeries.milliseconds(Date()), value: 0)]
            : visible.map { TrendCurvePoint(at: $0.at, value: $0.xp) }
        let first = visible.first?.xp ?? 0
        let last = visible.last?.xp ?? 0
        return TrendCurve(
            points: curvePoints,
            formatValue: { "\(ExGFormat.xp($0)) XP" },
            formatDate: { ChartDateFormat.pointDate($0, granularity) },
            accessibilityLabel: "Évolution de l’XP, de \(ExGFormat.xp(first)) à \(ExGFormat.xp(last)) XP"
        )
    }

    /// Pastille d'évolution, affichée dès que la série est prête.
    private var pill: AnyView? {
        isReady
            ? AnyView(AcctEvoPerformanceEvolutionPill(
                percentage: evolutionPercentage,
                absolute: evolutionAbsolute,
                unit: .xp
            ))
            : nil
    }

    /// Sous-titre : rappel du propos quand la courbe est encore vide.
    private var subtitle: String? {
        guard isReady && points.isEmpty else { return nil }
        return isMember
            ? "Les gains d’expérience de \(name) au fil du temps"
            : "Tes gains d’expérience au fil de tes entraînements"
    }

    @ViewBuilder
    private var content: some View {
        if !isReady {
            AcctEvoPerformanceChartLoading()
        } else if !points.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                AcctShowGranularityTabs(value: granularity) { granularity = $0 }
                ChartXpChart(points: points, granularity: granularity)
            }
        } else {
            AcctShowChartEmpty(icon: "sparkles-outline", message: emptyMessage)
        }
    }

    /// Explique ce qui déclenchera la courbe (`chartEmptyText`).
    private var emptyMessage: String {
        isMember
            ? "Cette courbe démarrera dès le premier gain d’XP publié."
            : "Ta courbe démarrera dès ton premier exercice, défi ou flashcard."
    }
}

/// Section « Elo » / « Évolution de l’Elo » de la vitrine
/// (`AccountScreen.tsx`, l. 3422-3534).
struct AcctShowEloSeriesSection: View {
    /// Courbe de clôture par période, matière choisie.
    let points: [ChartEloSeriesPoint]
    /// Période affichée, liée à l'état de l'écran.
    @Binding var granularity: ChartTimeGranularity
    /// Matières disponibles (`eloSubjects`) : une puce chacune, plus « Toutes ».
    let subjects: [String]
    /// Matière suivie ; `nil` = synthèse générale (« Moyenne des matières »).
    @Binding var subject: String?
    /// Variation relative entre les deux dernières périodes (`eloEvolutionPercentage`).
    let evolutionPercentage: Double
    /// Variation absolue entre les deux dernières périodes (`eloEvolutionAbsolute`).
    let evolutionAbsolute: Double
    /// Vrai quand la série est chargée ; sinon, indicateur de chargement.
    var isReady: Bool = true
    /// Vrai lorsque la vitrine affiche le profil d'un autre membre.
    var isMember: Bool = false
    /// `USE_REFINED_OVERVIEW` : tracé unique « Trade Republic ».
    var refined: Bool = false

    var body: some View {
        if refined {
            refinedSection
        } else {
            AcctShowSectionCard(
                icon: "trophy-outline",
                iconColor: ChartGoogleGColors.green,
                title: "Évolution de l’Elo",
                subtitle: subtitle,
                trailing: pill
            ) {
                content
            }
        }
    }

    /// Carte affinée : « Elo », grande valeur, onglets puis courbe affinée.
    /// Les filtres de matière disparaissent en affiné (`!USE_REFINED_OVERVIEW`).
    private var refinedSection: some View {
        AcctShowRefinedCard(
            title: "Elo",
            value: isReady
                ? AnyView(AcctShowRefinedValueRow(
                    value: ExGFormat.xp(points.last?.elo ?? 0),
                    percentage: evolutionPercentage,
                    absolute: evolutionAbsolute,
                    unit: .elo
                ))
                : nil
        ) {
            if isReady {
                VStack(alignment: .leading, spacing: 0) {
                    AcctShowRefinedPeriodTabs(value: granularity) { granularity = $0 }
                    ChartEloChart(points: points, granularity: granularity, refined: true)
                }
            } else {
                AcctEvoPerformanceChartLoading()
            }
        }
    }

    /// Pastille d'évolution, affichée dès que la série est prête.
    private var pill: AnyView? {
        isReady
            ? AnyView(AcctEvoPerformanceEvolutionPill(
                percentage: evolutionPercentage,
                absolute: evolutionAbsolute,
                unit: .elo
            ))
            : nil
    }

    /// Sous-titre : rappel du propos quand la courbe est encore vide.
    private var subtitle: String? {
        guard isReady && points.isEmpty else { return nil }
        return isMember
            ? "Aucun défi classé pour le moment"
            : "Ton classement matière par matière, gagné en défi"
    }

    @ViewBuilder
    private var content: some View {
        if !isReady {
            AcctEvoPerformanceChartLoading()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if !points.isEmpty {
                    AcctShowGranularityTabs(value: granularity) { granularity = $0 }
                }
                if subjects.count > 1 { subjectFilters }
                if !points.isEmpty {
                    ChartEloChart(points: points, granularity: granularity)
                } else {
                    AcctShowChartEmpty(
                        icon: "trending-up-outline",
                        message: emptyMessage
                    )
                }
            }
        }
    }

    /// Filtres de matière (`chartFilters`) : « Toutes » puis une puce par
    /// matière publiée ; retour à la ligne quand la largeur manque.
    private var subjectFilters: some View {
        AcctShowWrapLayout(spacing: 7) {
            chip(nil)
            ForEach(subjects, id: \.self) { subject in
                chip(subject)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    /// Une puce de matière ; `nil` = « Toutes ».
    private func chip(_ subject: String?) -> some View {
        DuelloChip(title: subject ?? "Toutes", selected: self.subject == subject) {
            self.subject = subject
        }
    }

    /// Explique ce qui déclenchera la courbe (`chartEmptyText`).
    private var emptyMessage: String {
        isMember
            ? "La courbe démarrera après son premier défi classé."
            : "Ta courbe démarre à ton premier défi. Chaque duel gagné ou perdu déplace ton Elo dans la matière jouée."
    }
}


/// Section « Moyenne des notes » / « Évolution des notes » de la vitrine
/// (`AccountScreen.tsx`, l. 3648-3768) : onglets de période, courbe
/// `ChartCorrectionGradeChart` et, en affiné, filtres de catégorie.
struct AcctShowGradeSeriesSection: View {
    /// Moyennes de notes par période (`gradeSeries`).
    let points: [ChartCorrectionPeriodPoint]
    /// Période affichée, liée à l'état de l'écran.
    @Binding var granularity: ChartTimeGranularity
    /// Variation relative entre les deux dernières périodes.
    var evolutionPercentage: Double = 0
    /// Variation absolue entre les deux dernières périodes.
    var evolutionAbsolute: Double = 0
    /// Vrai lorsque la vitrine affiche le profil d'un autre membre.
    var isMember: Bool = false
    /// `USE_REFINED_OVERVIEW` : tracé unique + filtres de catégorie.
    var refined: Bool = false

    /// `gradeCategory` : catégorie retenue ; `nil` = « Tout ».
    @State private var gradeCategory: String?

    var body: some View {
        if refined {
            refinedSection
        } else {
            AcctShowSectionCard(
                icon: "analytics-outline",
                iconColor: ChartGoogleGColors.yellow,
                title: "Évolution des notes",
                subtitle: nil,
                trailing: pill
            ) {
                content
            }
        }
    }

    /// Carte affinée : « Moyenne des notes », grande valeur puis courbe et
    /// filtres de catégorie (`refinedGradeFilters`).
    private var refinedSection: some View {
        AcctShowRefinedCard(
            title: "Moyenne des notes",
            value: AnyView(AcctShowRefinedValueRow(
                value: ExGFormat.score(filteredPoints.last?.score ?? 0),
                percentage: filteredEvolution.percentage,
                absolute: filteredEvolution.absolute,
                unit: .grade
            ))
        ) {
            VStack(alignment: .leading, spacing: 0) {
                AcctShowRefinedPeriodTabs(value: granularity) { granularity = $0 }
                ChartCorrectionGradeChart(
                    points: filteredPoints,
                    granularity: granularity,
                    refined: true
                )
                categoryFilters
            }
        }
    }

    /// `GRADE_CATEGORY_OPTIONS` : toutes les catégories d'abord.
    private static let categoryOptions: [(value: String?, label: String)] = [
        (nil, "Tout"),
        ("exercice", "Exercices"),
        ("colle", "Colles"),
        ("annale", "Annales"),
        ("defi", "Défi"),
        ("evenement", "Événements"),
    ]

    /// `refinedGradeFilters` : puces de catégorie sous la courbe.
    private var categoryFilters: some View {
        AcctShowWrapLayout(spacing: 7) {
            ForEach(Self.categoryOptions.indices, id: \.self) { index in
                let option = Self.categoryOptions[index]
                DuelloChip(title: option.label, selected: gradeCategory == option.value) {
                    gradeCategory = option.value
                }
            }
        }
        .padding(.top, 14)
    }

    /// `gradedCorrectionGrades` : les anciens bilans d'entraînement comptent
    /// comme des exercices (`AccountScreen.tsx:2035-2043`).
    private var filteredPoints: [ChartCorrectionPeriodPoint] {
        guard let category = gradeCategory else { return points }
        return points.compactMap { point in
            let entries = point.entries.filter { entry in
                category == "exercice"
                    ? (entry.activity == .exercice || entry.activity == .entrainement)
                    : entry.activity.rawValue == category
            }
            guard !entries.isEmpty else { return nil }
            let total = entries.reduce(0) { $0 + $1.score }
            let average = total / Double(entries.count)
            return ChartCorrectionPeriodPoint(
                at: point.at,
                score: (average * 10).rounded() / 10,
                entries: entries
            )
        }
    }

    /// Variation de la série filtrée (`gradeEvolutionPercentage`/`Absolute`).
    private var filteredEvolution: (percentage: Double, absolute: Double) {
        acctShowLatestEvolution(filteredPoints.map(\.score))
    }

    /// Pastille d'évolution, en points de note (`unit: .grade`).
    private var pill: AnyView {
        AnyView(AcctEvoPerformanceEvolutionPill(
            percentage: evolutionPercentage,
            absolute: evolutionAbsolute,
            unit: .grade
        ))
    }

    @ViewBuilder
    private var content: some View {
        if !points.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                AcctShowGranularityTabs(value: granularity) { granularity = $0 }
                ChartCorrectionGradeChart(points: points, granularity: granularity)
            }
        } else {
            AcctShowChartEmpty(icon: "analytics-outline", message: emptyMessage)
        }
    }

    /// Explique ce qui déclenchera la courbe (`chartEmptyText`).
    private var emptyMessage: String {
        isMember
            ? "Sa courbe démarrera dès sa première note publiée."
            : "Ta courbe démarrera dès ton premier exercice ou défi, ou ta première colle ou annale."
    }
}
