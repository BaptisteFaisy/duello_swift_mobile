//
//  AcctShowChrome.swift
//  Duello
//
//  Vitrine du profil — habillage des séries (lot 10-E, préfixe `AcctShow`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, l. 2918-3451 : styles `chartPeriodTabs`
//      (`chartPeriodTab`, `chartPeriodTabActive`, `chartPeriodTabText`,
//       `chartPeriodTabTextActive`), `accountPerformanceSection`,
//       `accountPerformanceHeader`, `accountPerformanceTitleRow`,
//       `accountPerformanceTitle`, `accountPerformanceSubtitle`,
//       `accountPerformanceBody` et `chartEmpty`.
//
//  Réutilise `Theme`, `ChartTimeGranularity`, `AcctEvoPerformanceChartLoading`.
//
//  Cible : iOS 16, aucune API iOS 17 ; aucune dépendance externe.
//
import SwiftUI

/// Onglets de période d'une courbe de la vitrine (`chartPeriodTabs`) : un
/// contrôle segmenté Jours / Semaines / Mois.
struct AcctShowGranularityTabs: View {
    /// Période retenue.
    let value: ChartTimeGranularity
    /// Applique la période choisie.
    let onChange: (ChartTimeGranularity) -> Void

    /// Libellé français d'une période
    /// (`[['day','Jours'], ['week','Semaines'], ['month','Mois']]`).
    static func label(for period: ChartTimeGranularity) -> String {
        switch period {
        case .day: return "Jours"
        case .week: return "Semaines"
        case .month: return "Mois"
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ChartTimeGranularity.allCases, id: \.self) { period in
                tab(period)
            }
        }
        .padding(2)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 6)
        .padding(.bottom, 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Période du graphique")
    }

    /// Un onglet : fond d'encre quand il est actif (`chartPeriodTabActive`).
    private func tab(_ period: ChartTimeGranularity) -> some View {
        let selected = period == value
        return Button {
            onChange(period)
        } label: {
            Text(Self.label(for: period))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(selected ? Theme.ink : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Carte de section de la vitrine (`accountPerformanceSection`) : en-tête
/// (pictogramme, titre, sous-titre, action) séparé du corps par un filet.
struct AcctShowSectionCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    let content: Content

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Theme.border).frame(height: 1)
            content
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
        }
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 20)
    }

    /// Pictogramme, titre et sous-titre à gauche, action à droite.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconColor)
                    Text(title)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing { trailing }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
    }
}

/// État vide d'une courbe de la vitrine (`chartEmpty`) : cadre fin, pictogramme
/// et explication, sur fond blanc pour ne pas paraître désactivé.
struct AcctShowChartEmpty: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
            Text(message)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 8)
    }
}
