//
//  ChartPerformanceOverviewBar.swift
//  Duello
//
//  Bandeau de repères personnels (lot D « Graphiques », préfixe `Chart`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/PerformanceOverviewBar.tsx (`PerformanceOverviewBar`,
//      `PerformanceOverviewStat`, `PerformanceMetricIcon`,
//      `PERFORMANCE_OVERVIEW_BAR_HEIGHT`, `GOOGLE_G_COLORS`)
//
//  Variantes reprises de la source : `regularValues`, `balanced`, `tight`,
//  `tall`, `closeSeparator`, `alignStatsToStart`, `barVerticalOffset`,
//  `statsHorizontalOffset`, `leadingStatsHorizontalOffset`,
//  `trailingStatsHorizontalStep`, `statsMaxWidth`, `evenEdgeSpacing`,
//  `symmetricAccessoryWidth`. `targetStatRef` (référence de vue native pour une
//  animation) n'a pas d'équivalent SwiftUI direct : `targetStatLabel` reste
//  accepté. Les encarts `leading`/`centered`/`trailing` sont acceptés en
//  `AnyView`. Cible iOS 16.
//
import SwiftUI

/// `GOOGLE_G_COLORS` de `PerformanceOverviewBar.tsx` : teintes du « G » Google.
enum ChartGoogleGColors {
    static let blue = Color(hex: 0x4285F4)
    static let green = Color(hex: 0x34A853)
    static let yellow = Color(hex: 0xFBBC05)
    static let red = Color(hex: 0xEA4335)
}

/// Constantes du bandeau (`PERFORMANCE_OVERVIEW_BAR_HEIGHT`, offset de contenu).
enum ChartPerformanceOverview {
    /// Hauteur lisible commune aux métriques.
    static let barHeight: CGFloat = 60
    /// Les métriques et les actions restent centrées verticalement.
    static let contentOffset: CGFloat = 0
}

/// `PerformanceOverviewStat` de `PerformanceOverviewBar.tsx`.
struct ChartPerformanceOverviewStat: Identifiable, Hashable {
    var icon: String
    var value: String
    var label: String
    var accessibilityLabel: String
    var color: Color
    var id: String { label }
}

/// `PerformanceOverviewBar` : repères personnels communs aux onglets
/// Entraînement et Défis.
struct ChartPerformanceOverviewBar: View {
    let stats: [ChartPerformanceOverviewStat]
    var leading: AnyView? = nil
    var centered: AnyView? = nil
    var trailing: AnyView? = nil
    var refined: Bool = false
    var regularValues: Bool = false
    var embedded: Bool = false
    var balanced: Bool = false
    var tight: Bool = false
    var tall: Bool = false
    var closeSeparator: Bool = false
    var hideSeparator: Bool = false
    var hideStatDividers: Bool = false
    var alignStatsToStart: Bool = false
    var barVerticalOffset: CGFloat = 0
    var statsHorizontalOffset: CGFloat = 0
    var leadingStatsHorizontalOffset: CGFloat = 0
    var trailingStatsHorizontalStep: CGFloat = 0
    var statsMaxWidth: CGFloat? = nil
    var evenEdgeSpacing: Bool = false
    var symmetricAccessoryWidth: CGFloat? = nil
    var targetStatLabel: String? = nil

    /// `ÉNERGIE IA` est un compteur interne, jamais montré dans le bandeau.
    private var visibleStats: [ChartPerformanceOverviewStat] {
        stats.filter { $0.label != "ÉNERGIE IA" }
    }
    private var showsSeparator: Bool {
        !hideSeparator && !embedded && !visibleStats.isEmpty
    }

    var body: some View {
        HStack(spacing: refined ? 2 : 0) {
            leadingSlot
            statsRegion
            trailingSlot
        }
        .frame(maxWidth: .infinity, minHeight: ChartPerformanceOverview.barHeight)
        .padding(.top, verticalPadding.top)
        .padding(.bottom, verticalPadding.bottom)
        .padding(.horizontal, horizontalPadding)
        .background(embedded || visibleStats.isEmpty ? Color.clear : Theme.background)
        .overlay { if let centered { centered } }
        .overlay(alignment: .bottom) {
            if showsSeparator { Rectangle().fill(Theme.border).frame(height: 1) }
        }
        .offset(y: barVerticalOffset)
    }

    /// `paddingTop`/`paddingBottom` du bandeau : `refined` 4/4, `tight` 3/4,
    /// `tall` 10/11, `closeSeparator` 0/0, sinon 8/9 (asymétrique).
    private var verticalPadding: (top: CGFloat, bottom: CGFloat) {
        if embedded { return (0, 0) }
        if closeSeparator { return (0, 0) }
        if tall { return (10, 11) }
        if tight { return (3, 4) }
        if refined { return (4, 4) }
        return (8, 9)
    }

    private var horizontalPadding: CGFloat {
        if embedded || balanced { return 0 }
        if refined { return 8 }
        return 16
    }

    @ViewBuilder private var leadingSlot: some View {
        if let leading {
            leading.frame(
                maxWidth: balanced || evenEdgeSpacing ? .infinity : nil,
                alignment: balanced ? .leading : .center
            )
        } else if let width = symmetricAccessoryWidth {
            Color.clear.frame(width: width)
        }
    }

    @ViewBuilder private var trailingSlot: some View {
        if let trailing {
            trailing.frame(
                maxWidth: balanced ? .infinity : nil,
                alignment: balanced ? .trailing : .center
            )
        } else if let width = symmetricAccessoryWidth {
            Color.clear.frame(width: width)
        } else if evenEdgeSpacing {
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    private var statsRegion: some View {
        statsGroup
            .frame(maxWidth: .infinity, alignment: alignStatsToStart ? .leading : .center)
    }

    private var statsGroup: some View {
        HStack(spacing: refined && !evenEdgeSpacing ? 2 : 0) {
            ForEach(Array(visibleStats.enumerated()), id: \.element.id) { index, stat in
                statView(stat, index: index)
            }
        }
        .frame(maxWidth: statsMaxWidth ?? .infinity)
    }

    private func statView(_ stat: ChartPerformanceOverviewStat, index: Int) -> some View {
        let padded = refined || (tight && !embedded)
        return VStack(spacing: 1) {
            HStack(spacing: refined ? 3 : 4) {
                ChartPerformanceMetricIcon(name: stat.icon, color: stat.color)
                Text(stat.value)
                    .font(.system(size: 13, weight: regularValues ? .regular : .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            Text(stat.label)
                .font(.system(size: 8.5, weight: .heavy))
                .tracking(0.35)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                // `adjustsFontSizeToFit` de la source : le libellé se réduit
                // plutôt que d'être coupé (« ENTRAÎNEMENT » dépassait).
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: padded ? 48 : nil)
        .padding(.horizontal, refined ? 2 : 3)
        .padding(.vertical, padded ? 3 : 0)
        .overlay(alignment: .trailing) {
            // `statDivider` : trait hairline pleine hauteur, jamais en `refined`.
            if !refined && !hideStatDividers && index < visibleStats.count - 1 {
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)
            }
        }
        .offset(x: statOffset(index))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.accessibilityLabel)
    }

    /// Décalage horizontal réservé aux métriques (`statsHorizontalOffset`…).
    private func statOffset(_ index: Int) -> CGFloat {
        statsHorizontalOffset
            + (index < 2 ? leadingStatsHorizontalOffset : 0)
            + (index >= 2 ? CGFloat(index - 1) * trailingStatsHorizontalStep : 0)
    }
}

/// `PerformanceMetricIcon` : pastille pastel (option cerclée) portant un pictogramme.
struct ChartPerformanceMetricIcon: View {
    var name: String
    var color: Color
    /// Remplissage plein optionnel, indépendant du contour et du pictogramme.
    var fillColor: Color? = nil
    var iconSize: CGFloat = 14
    var size: CGFloat = 24
    /// Cercle pastel cerclé, utilisé pour les boutons associés à une métrique.
    var outlined: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill((fillColor ?? color).opacity(fillColor == nil ? 0.14 : 1))
                .frame(width: size, height: size)
            if outlined {
                Circle().stroke(color, lineWidth: 1.5).frame(width: size, height: size)
            }
            // La source superpose le pictogramme deux fois : le second, décalé de
            // 0,4 pt et à 45 %, épaissit le trait (`metricIconEmphasis`).
            Image(systemName: name)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
                .overlay {
                    Image(systemName: name)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(color)
                        .opacity(0.45)
                        .offset(x: 0.4)
                }
        }
        .frame(width: size, height: size)
    }
}
