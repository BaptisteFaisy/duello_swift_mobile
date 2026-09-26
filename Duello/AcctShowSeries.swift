//
//  AcctShowSeries.swift
//  Duello
//
//  Vitrine du profil — séries XP et Elo (lot 10-E, préfixe `AcctShow`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, l. 2918-3157 : sections « Évolution de
//      l’XP » et « Évolution de l’Elo » (onglets de période, filtres de
//      matière, courbes et états vides).
//
//  Réutilise `ChartXpChart`, `ChartEloChart`, `ChartXpSeriesPoint`,
//  `ChartEloSeriesPoint`, `ChartTimeGranularity`,
//  `AcctEvoPerformanceEvolutionPill`, `AcctEvoPerformanceChartLoading`,
//  `ChartGoogleGColors`, `DuelloChip` et l'habillage `AcctShow*`.
//
//  Cible : iOS 16, aucune API iOS 17 ; aucune dépendance externe.
//
import SwiftUI

/// Section « Évolution de l’XP » de la vitrine (`AccountScreen.tsx`,
/// l. 2918-3025).
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

    var body: some View {
        AcctShowSectionCard(
            icon: "sparkles",
            iconColor: ChartGoogleGColors.blue,
            title: "Évolution de l’XP",
            subtitle: subtitle,
            trailing: pill
        ) {
            content
        }
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
            AcctShowChartEmpty(icon: "sparkles", message: emptyMessage)
        }
    }

    /// Explique ce qui déclenchera la courbe (`chartEmptyText`).
    private var emptyMessage: String {
        isMember
            ? "Cette courbe démarrera dès le premier gain d’XP publié."
            : "Ta courbe démarrera dès ton premier exercice, défi ou flashcard."
    }
}

/// Section « Évolution de l’Elo » de la vitrine (`AccountScreen.tsx`,
/// l. 3027-3157).
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

    var body: some View {
        AcctShowSectionCard(
            icon: "trophy",
            iconColor: ChartGoogleGColors.green,
            title: "Évolution de l’Elo",
            subtitle: subtitle,
            trailing: pill
        ) {
            content
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
                        icon: "chart.line.uptrend.xyaxis",
                        message: emptyMessage
                    )
                }
            }
        }
    }

    /// Filtres de matière (`chartFilters`) : « Toutes » puis une puce par
    /// matière publiée.
    private var subjectFilters: some View {
        HStack(spacing: 7) {
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

/// Section « Évolution des notes » de la vitrine (`AccountScreen.tsx`,
/// l. 3222-3330) : onglets de période, courbe `ChartCorrectionGradeChart` ou
/// état vide.
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

    var body: some View {
        AcctShowSectionCard(
            icon: "chart.bar.xaxis",
            iconColor: ChartGoogleGColors.yellow,
            title: "Évolution des notes",
            subtitle: nil,
            trailing: pill
        ) {
            content
        }
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
        VStack(alignment: .leading, spacing: 0) {
            AcctShowGranularityTabs(value: granularity) { granularity = $0 }
            if !points.isEmpty {
                ChartCorrectionGradeChart(points: points, granularity: granularity)
            } else {
                AcctShowChartEmpty(icon: "chart.bar.xaxis", message: emptyMessage)
            }
        }
    }

    /// Explique ce qui déclenchera la courbe (`chartEmptyText`).
    private var emptyMessage: String {
        isMember
            ? "Sa courbe démarrera dès sa première note publiée."
            : "Ta courbe démarrera dès ton premier exercice ou défi, ou ta première colle ou annale."
    }
}

/// Section « Évolution du temps » de la vitrine (`AccountScreen.tsx`,
/// l. 3332-3416) : onglets de période, `ChartSubjectTimeTrendChart` ou état vide.
struct AcctShowTimeSeriesSection: View {
    /// Temps d'entraînement par période (`timeBuckets`).
    let buckets: [ChartTimeBucket]
    /// Période affichée, liée à l'état de l'écran.
    @Binding var granularity: ChartTimeGranularity
    /// Vrai lorsque la vitrine affiche le profil d'un autre membre.
    var isMember: Bool = false

    var body: some View {
        AcctShowSectionCard(
            icon: "timer",
            iconColor: ChartGoogleGColors.red,
            title: "Évolution du temps",
            subtitle: nil,
            trailing: nil
        ) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            AcctShowGranularityTabs(value: granularity) { granularity = $0 }
            if !buckets.isEmpty {
                ChartSubjectTimeTrendChart(buckets: buckets, granularity: granularity)
            } else {
                AcctShowChartEmpty(icon: "timer", message: emptyMessage)
            }
        }
    }

    /// Explique ce qui déclenchera la courbe (`chartEmptyText`).
    private var emptyMessage: String {
        isMember
            ? "Sa courbe démarrera dès son premier exercice, défi ou flashcard."
            : "Ta courbe démarrera dès ton premier exercice, défi ou flashcard."
    }
}
