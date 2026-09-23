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
//  Les variantes purement visuelles de la source (`balanced`, `evenEdgeSpacing`,
//  décalages, `targetStatRef`) ne sont pas reprises : la position par défaut
//  suffit. Les encarts `leading`/`centered`/`trailing` sont acceptés en
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
    var embedded: Bool = false
    var hideSeparator: Bool = false
    var hideStatDividers: Bool = false

    /// `ÉNERGIE IA` est un compteur interne, jamais montré dans le bandeau.
    private var visibleStats: [ChartPerformanceOverviewStat] {
        stats.filter { $0.label != "ÉNERGIE IA" }
    }
    private var showsSeparator: Bool { !hideSeparator && !embedded }

    var body: some View {
        HStack(spacing: refined ? 2 : 0) {
            if let leading { leading }
            statsGroup
            if let trailing { trailing }
        }
        .frame(maxWidth: .infinity, minHeight: ChartPerformanceOverview.barHeight)
        .padding(.horizontal, embedded ? 0 : 16)
        .padding(.vertical, embedded ? 0 : 8)
        .background(embedded ? Color.clear : Theme.background)
        .overlay { if let centered { centered } }
        .overlay(alignment: .bottom) {
            if showsSeparator { Rectangle().fill(Theme.border).frame(height: 1) }
        }
    }

    private var statsGroup: some View {
        HStack(spacing: 0) {
            ForEach(Array(visibleStats.enumerated()), id: \.element.id) { index, stat in
                statView(stat)
                if !hideStatDividers && index < visibleStats.count - 1 {
                    Rectangle().fill(Theme.border).frame(width: 0.5, height: 32)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statView(_ stat: ChartPerformanceOverviewStat) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                ChartPerformanceMetricIcon(name: stat.icon, color: stat.color)
                Text(stat.value)
                    .font(.system(size: 13, weight: .heavy))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.accessibilityLabel)
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
            Image(systemName: name)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}
