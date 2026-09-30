//
//  AcctShowRefined.swift
//  Duello
//
//  Vitrine du profil — habillage affiné « Trade Republic » et sections
//  « Heures travaillées » / « Exos réalisés » (vague I7, préfixe `AcctShow`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, l. 3536-3646 : onglets de période
//      affinés, grande valeur + pastille inline, disposition enroulée des
//      filtres, sections « Heures travaillées » et « Exos réalisés ».
//
//  Réutilise `TrendCurve`, `ChartExerciseBucket`,
//  `AcctEvoPerformanceChartLoading`, `IonIcon`, `DuelloChip` et `Theme`.
//
//  Cible : iOS 16, aucune API iOS 17 ; aucune dépendance externe.
//
import SwiftUI

/// Disposition enroulée (`chartFilters`, `flexWrap: 'wrap'`, `gap: 7`) : les
/// puces de matière passent à la ligne suivante quand la largeur manque, au
/// lieu de déborder du cadre.
struct AcctShowWrapLayout: Layout {
    /// Espacement horizontal et vertical entre les puces.
    var spacing: CGFloat = 7

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : max(0, x - spacing), height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Habillage affiné (« Trade Republic »)

/// `colors.tradeGrey` (`theme.ts`) : gris des libellés atténués de l'affichage
/// affiné. Absent de `Theme` (qui ne l'expose pas encore) : redéclaré localement.
private let acctShowTradeGrey = Color(hex: 0xB7BEC6)

/// `PerformanceEvolutionUnit` de `AccountScreen.tsx` : unité d'une variation
/// affichée dans la pastille d'évolution (`xp`/`elo`/`grade`/`hours`/`exos`).
enum AcctShowEvolutionUnit {
    case xp
    case elo
    case grade
    case hours
    case exos
}

/// `PerformanceEvolutionPill` en mode affiné (`refinedDeltaPill`) : la pastille
/// perd sa capsule et se lit en 16 points, la flèche à 13.
struct AcctShowRefinedDeltaPill: View {
    let percentage: Double
    let absolute: Double
    let unit: AcctShowEvolutionUnit

    @State private var showingAbsolute = false

    private var value: Double { showingAbsolute ? absolute : percentage }

    var body: some View {
        Button {
            showingAbsolute.toggle()
        } label: {
            HStack(spacing: 2) {
                if value != 0 {
                    IonIcon(name: value > 0 ? "arrow-up" : "arrow-down", size: 13, color: Theme.ink)
                }
                Text(Self.sign(value) + valueText)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Afficher l’évolution \(showingAbsolute ? "relative" : "absolue")")
        .accessibilityLabel(
            "Évolution \(showingAbsolute ? "absolue" : "relative") : "
                + Self.spokenSign(value) + spokenValue
        )
    }

    private var valueText: String {
        showingAbsolute
            ? Self.absoluteText(value, unit)
            : "\(ExGFormat.xp(abs(value))) %"
    }

    private var spokenValue: String {
        showingAbsolute
            ? Self.absoluteSpokenText(value, unit)
            : "\(ExGFormat.xp(abs(value))) pour cent"
    }

    /// `evolutionSign` — le moins est U+2212.
    private static func sign(_ value: Double) -> String {
        value > 0 ? "+" : (value < 0 ? "\u{2212}" : "")
    }

    private static func spokenSign(_ value: Double) -> String {
        value > 0 ? "plus " : (value < 0 ? "moins " : "")
    }

    /// `absoluteEvolutionText` — magnitude dans l'unité.
    private static func absoluteText(_ value: Double, _ unit: AcctShowEvolutionUnit) -> String {
        let magnitude = abs(value)
        switch unit {
        case .xp: return "\(ExGFormat.xp(magnitude)) XP"
        case .elo: return "\(ExGFormat.xp(magnitude)) Elo"
        case .grade: return "\(ExGFormat.xp(magnitude)) pt"
        case .hours: return AcctIntData.formatTrainingHours(minutes: magnitude)
        case .exos: return "\(ExGFormat.xp(magnitude)) exos"
        }
    }

    /// `absoluteEvolutionSpokenText` — variante parlée.
    private static func absoluteSpokenText(_ value: Double, _ unit: AcctShowEvolutionUnit) -> String {
        let magnitude = abs(value)
        switch unit {
        case .xp: return "\(ExGFormat.xp(magnitude)) XP"
        case .elo: return "\(ExGFormat.xp(magnitude)) Elo"
        case .grade: return "\(ExGFormat.xp(magnitude)) point\(magnitude > 1 ? "s" : "")"
        case .hours: return "\(AcctIntData.formatTrainingHours(minutes: magnitude)) d’entraînement"
        case .exos: return "\(ExGFormat.xp(magnitude)) exercice\(magnitude > 1 ? "s" : "")"
        }
    }
}

/// `ChartPeriodTabs` en mode affiné (`refinedChartPeriodTabs`) : lettres seules
/// espacées, sans fond segmenté ; actif en encre, inactif en `tradeGrey`.
///
/// ⚠️ Les niveaux `year` (« A ») et `max` (« MAX ») de la source ne sont pas
/// portés : `ChartTimeGranularity` ne les expose pas et trois fichiers hors
/// périmètre commutent dessus (cf. rapport I7-06, « Hors périmètre »).
struct AcctShowRefinedPeriodTabs: View {
    let value: ChartTimeGranularity
    let onChange: (ChartTimeGranularity) -> Void

    var body: some View {
        HStack(spacing: 0) {
            tab(.day, "J")
            Spacer(minLength: 0)
            tab(.week, "S")
            Spacer(minLength: 0)
            tab(.month, "M")
        }
        .padding(.horizontal, 2)
        .padding(.top, 16)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Période du graphique")
    }

    private func tab(_ period: ChartTimeGranularity, _ label: String) -> some View {
        let selected = period == value
        return Button {
            onChange(period)
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(selected ? Theme.ink : acctShowTradeGrey)
                .frame(minHeight: 32)
                .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// `accountPerformanceSection` + `refinedChartSection` : carte sans contour ni
/// fond (l'affiné flotte sur la page), titre capitales noir, grande valeur
/// éventuelle, puis le corps en 14 points de marge verticale.
struct AcctShowRefinedCard<Content: View>: View {
    let title: String
    var value: AnyView?
    let content: Content

    init(title: String, value: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 4)
                if let value {
                    value.padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            content
                .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 32)
    }
}

/// `refinedValueRow` : grande valeur (24/`heavy`) + pastille inline.
struct AcctShowRefinedValueRow: View {
    let value: String
    var suffix: String? = nil
    let percentage: Double
    let absolute: Double
    let unit: AcctShowEvolutionUnit

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            valueText
            AcctShowRefinedDeltaPill(percentage: percentage, absolute: absolute, unit: unit)
        }
    }

    private var valueText: Text {
        Text(value)
            .font(.system(size: 24, weight: .heavy))
            .tracking(-0.5)
            .monospacedDigit()
            .foregroundColor(Theme.ink)
        + (suffix.map {
            Text(" " + $0)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(acctShowTradeGrey)
        } ?? Text(""))
    }
}

/// `latestRelativeEvolutionPercentage` + `latestAbsoluteEvolution` : variation
/// entre les deux derniers points, repliée sur 0 en deçà de deux points.
/// Section « Heures travaillées » / « Évolution du temps » de la vitrine
/// (`AccountScreen.tsx`, l. 3536-3604).
struct AcctShowTimeSeriesSection: View {
    /// Temps d'entraînement par période (`timeBuckets`).
    let buckets: [ChartTimeBucket]
    /// Période affichée, liée à l'état de l'écran.
    @Binding var granularity: ChartTimeGranularity
    /// Vrai quand le profil a du temps d'entraînement (`hasTrainingTime`) :
    /// pilote l'affichage de la courbe en production.
    var hasTrainingTime: Bool = false
    /// Vrai lorsque la vitrine affiche un autre membre.
    var isMember: Bool = false
    /// Variation relative entre les deux dernières périodes (`timeEvolutionPercentage`).
    var evolutionPercentage: Double = 0
    /// Variation absolue entre les deux dernières périodes (`timeEvolutionAbsolute`).
    var evolutionAbsolute: Double = 0
    /// `USE_REFINED_OVERVIEW` : tracé unique « Trade Republic ».
    var refined: Bool = false

    var body: some View {
        if refined {
            refinedSection
        } else {
            AcctShowSectionCard(
                icon: "timer-outline",
                iconColor: ChartGoogleGColors.red,
                title: "Évolution du temps",
                subtitle: nil,
                trailing: nil
            ) {
                content
            }
        }
    }

    /// Carte affinée : « Heures travaillées », grande valeur en heures, onglets
    /// puis courbe (elle s'affiche même sans mesure, à zéro).
    private var refinedSection: some View {
        AcctShowRefinedCard(
            title: "Heures travaillées",
            value: AnyView(AcctShowRefinedValueRow(
                value: AcctIntData.formatTrainingHours(minutes: buckets.last?.minutes ?? 0),
                percentage: evolutionPercentage,
                absolute: evolutionAbsolute,
                unit: .hours
            ))
        ) {
            VStack(alignment: .leading, spacing: 0) {
                AcctShowRefinedPeriodTabs(value: granularity) { granularity = $0 }
                refinedCurve
            }
        }
    }

    /// `SubjectTimeTrendChart` en mode affiné : `TrendCurve` sur les minutes.
    private var refinedCurve: some View {
        let curvePoints: [TrendCurvePoint] = buckets.isEmpty
            ? [TrendCurvePoint(at: ChartTimeSeries.milliseconds(Date()), value: 0)]
            : buckets.map { TrendCurvePoint(at: $0.start, value: $0.minutes) }
        return TrendCurve(
            points: curvePoints,
            formatValue: { AcctIntData.formatTrainingHours(minutes: $0) },
            formatDate: { ChartTimeSeries.title($0, granularity) },
            accessibilityLabel: refinedAccessibility
        )
    }

    /// `chartAccessibilityLabel` de `SubjectTimeTrendChart.tsx`.
    private var refinedAccessibility: String {
        let values = buckets.map {
            "\(ChartTimeSeries.title($0.start, granularity)) : \(Int($0.minutes.rounded())) minutes"
        }
        return "Durée d’entraînement \(granularity.name). \(values.joined(separator: ", "))"
    }

    @ViewBuilder
    private var content: some View {
        if hasTrainingTime {
            VStack(alignment: .leading, spacing: 0) {
                AcctShowGranularityTabs(value: granularity) { granularity = $0 }
                ChartSubjectTimeTrendChart(buckets: buckets, granularity: granularity)
            }
        } else {
            AcctShowChartEmpty(icon: "timer-outline", message: emptyMessage)
        }
    }

    /// Explique ce qui déclenchera la courbe (`chartEmptyText`).
    private var emptyMessage: String {
        isMember
            ? "Aucun temps d’entraînement publié pour le moment."
            : "Ta courbe démarrera dès ton premier exercice, défi ou flashcard."
    }
}
/// Section « Exos réalisés » de la vitrine (`AccountScreen.tsx`, l. 3606-3646) :
/// uniquement en affiné, sur son propre onglet de période.
struct AcctShowExosSeriesSection: View {
    /// Exercices terminés par période (`exosBuckets`).
    let buckets: [ChartExerciseBucket]
    /// Période affichée, liée à l'état de l'écran.
    @Binding var granularity: ChartTimeGranularity
    /// Variation relative entre les deux dernières périodes.
    var evolutionPercentage: Double = 0
    /// Variation absolue entre les deux dernières périodes.
    var evolutionAbsolute: Double = 0
    /// Vrai quand l'activité est chargée ; sinon, indicateur de chargement.
    var isReady: Bool = true

    var body: some View {
        AcctShowRefinedCard(
            title: "Exos réalisés",
            value: isReady
                ? AnyView(AcctShowRefinedValueRow(
                    value: ExGFormat.xp(buckets.last?.exercises ?? 0),
                    percentage: evolutionPercentage,
                    absolute: evolutionAbsolute,
                    unit: .exos
                ))
                : nil
        ) {
            if isReady {
                VStack(alignment: .leading, spacing: 0) {
                    AcctShowRefinedPeriodTabs(value: granularity) { granularity = $0 }
                    curve
                }
            } else {
                AcctEvoPerformanceChartLoading()
            }
        }
    }

    /// `TrendCurve` sur le nombre d'exercices (`buildExerciseCountSeries`).
    private var curve: some View {
        let curvePoints: [TrendCurvePoint] = buckets.isEmpty
            ? [TrendCurvePoint(at: ChartTimeSeries.milliseconds(Date()), value: 0)]
            : buckets.map { TrendCurvePoint(at: $0.start, value: $0.exercises) }
        return TrendCurve(
            points: curvePoints,
            formatValue: { "\(ExGFormat.xp($0)) exos" },
            formatDate: { ChartTimeSeries.title($0, granularity) },
            accessibilityLabel: "Exos réalisés, \(buckets.count) périodes"
        )
    }
}

/// `formatTrainingHours` (`utils/activity.ts`) : heures d'entraînement toujours
/// exprimées en heures (« 12 h », « 12,5 h »), même sous une heure. Déporté ici
/// (`AcctIntData` plafonne à dix fonctions par fichier).
extension AcctIntData {
    static func formatTrainingHours(minutes: Double) -> String {
        let safe = minutes.isFinite && minutes > 0 ? minutes.rounded(.down) : 0
        let rounded = (safe / 60 * 10).rounded() / 10
        let text: String
        if rounded == rounded.rounded() {
            text = String(Int(rounded))
        } else {
            text = String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
        }
        return text + " h"
    }
}
