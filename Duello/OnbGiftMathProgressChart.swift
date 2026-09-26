//
//  OnbGiftMathProgressChart.swift
//  Duello
//
//  LOT K — extras d’onboarding : le graphique de progression en maths.
//
//  Fichier source Expo porté : `src/components/OnboardingMathProgressChart.tsx`
//  (`OnboardingMathProgressChart`, `ChartCard`, `ChartLegend`, `ChartYAxis`,
//  `ChartXAxis`, `MONTHS`, `GRADE_TICKS`, les deux séries de notes et le
//  commentaire de patience).
//
//  Le graphique de la source vit sur le fond noir de l’onboarding
//  (`usesDarkOnboardingAppearance = true`) : sa carte sombre (`#0B0B0B`, bord
//  `#303030`) et sa note de patience (`#171717`) gardent donc leur palette
//  propre — le thème clair de `Theme` ne s’y applique pas. Le tracé animé des
//  deux courbes est dans `OnbGiftMathChartPlot.swift`.
//
//  ⚠️ La source choisit sa hauteur de tracé selon la plateforme
//  (`WEB_PROGRESS_PLOT_HEIGHT` 320, `DESKTOP_PROGRESS_PLOT_HEIGHT` 160) : c’est
//  la variante native (`NATIVE_PROGRESS_PLOT_HEIGHT`, 176) qui est portée.
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

/// Graphique de progression : deux trajectoires sur un an, avec et sans Duello.
struct OnbGiftMathProgressChart: View {
    var body: some View {
        VStack(spacing: 18) {
            OnbGiftChartCard()
            OnbGiftPatienceNote()
        }
    }
}

// MARK: - Données du graphique

/// Une trajectoire du graphique (`WITH_DUELLO_SERIES` / `WITHOUT_APP_SERIES`).
struct OnbGiftChartSeries: Identifiable {
    let id: String
    let label: String
    let grades: [Double]
    let color: Color
    let emphasized: Bool
}

/// Un segment de Bézier cubique du tracé. Les abscisses sont **normalisées**
/// (dans `[0, 1]` de la largeur du tracé) ; les ordonnées sont en points.
struct OnbGiftChartSegment {
    var to: CGPoint
    var control1: CGPoint
    var control2: CGPoint
}

/// Les constantes du graphique, reprises mot pour mot de la source.
enum OnbGiftChartData {
    /// `NATIVE_PROGRESS_PLOT_HEIGHT` : hauteur de la zone de tracé.
    static let plotHeight: CGFloat = 176
    /// Abscisses : `Départ`, puis tous les deux mois jusqu’à un an.
    static let months = ["Départ", "2 mois", "4 mois", "6 mois", "9 mois", "1 an"]
    /// Graduations affichées en ordonnée (`GRADE_TICKS`).
    static let gradeTicks: [Double] = [16, 12, 8]
    /// Les deux trajectoires restent proches au départ : le bénéfice vient de la
    /// régularité, pas d’une promesse de résultat immédiat.
    static let withDuelloGrades: [Double] = [8, 8.32, 9.12, 10.56, 13.12, 16]
    static let withoutAppGrades: [Double] = [8, 8.64, 9.2, 9.68, 10.16, 10.56]
    static let withDuello = OnbGiftChartSeries(
        id: "with-duello", label: "Avec Duello", grades: OnbGiftChartData.withDuelloGrades,
        color: .white, emphasized: true)
    static let withoutApp = OnbGiftChartSeries(
        id: "without-app", label: "Sans l’app", grades: OnbGiftChartData.withoutAppGrades,
        color: Color(hex: 0x6C6C6C), emphasized: false)
    /// Ordre de la légende, puis ordre de tracé (la trajectoire sans Duello
    /// dessous, celle avec Duello au-dessus).
    static let legendSeries = [
        OnbGiftChartData.withDuello, OnbGiftChartData.withoutApp,
    ]
    static let drawingSeries = [
        OnbGiftChartData.withoutApp, OnbGiftChartData.withDuello,
    ]

    /// Ordonnée d’une note : 8/20 en bas du tracé, 16/20 en haut.
    static func gradeY(_ grade: Double) -> CGFloat {
        plotHeight * CGFloat(1 - (grade - 8) / 8)
    }

    /// Segments pré-calculés des deux séries statiques : les points de contrôle
    /// ne dépendent que des notes et sont donc calculés une fois, pas à chaque
    /// image du tracé animé.
    static let withDuelloSegments = makeSegments(withDuelloGrades)
    static let withoutAppSegments = makeSegments(withoutAppGrades)

    /// Chemin lissé du tracé (`curvePath`) : une courbe de Bézier cubique par
    /// segment. Le rendu ne fait plus que mettre les segments pré-calculés à
    /// l'échelle de la largeur mesurée, sans reparcourir les points.
    static func curvePath(_ grades: [Double], plotWidth: CGFloat) -> Path {
        guard let first = grades.first else { return Path() }
        let segments: [OnbGiftChartSegment]
        if grades == withDuelloGrades {
            segments = withDuelloSegments
        } else if grades == withoutAppGrades {
            segments = withoutAppSegments
        } else {
            segments = makeSegments(grades)
        }
        guard !segments.isEmpty else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: 0, y: gradeY(first)))
        for segment in segments {
            path.addCurve(
                to: CGPoint(x: segment.to.x * plotWidth, y: segment.to.y),
                control1: CGPoint(x: segment.control1.x * plotWidth, y: segment.control1.y),
                control2: CGPoint(x: segment.control2.x * plotWidth, y: segment.control2.y))
        }
        return path
    }

    /// Décompose une série en segments normalisés (pré-calcul) : abscisses dans
    /// `[0, 1]` (mises à l'échelle au rendu), ordonnées en points.
    private static func makeSegments(_ grades: [Double]) -> [OnbGiftChartSegment] {
        guard grades.count > 1, months.count > 1 else { return [] }
        let count = months.count
        let points = grades.enumerated().map { index, grade in
            CGPoint(x: CGFloat(index) / CGFloat(count - 1), y: gradeY(grade))
        }
        var segments: [OnbGiftChartSegment] = []
        for index in 1..<points.count {
            let previous = points[index - 1]
            let beforePrevious = points[max(0, index - 2)]
            let afterPoint = points[min(points.count - 1, index + 1)]
            let firstControl = CGPoint(
                x: previous.x + (points[index].x - beforePrevious.x) / 6,
                y: previous.y + (points[index].y - beforePrevious.y) / 6)
            let secondControl = CGPoint(
                x: points[index].x - (afterPoint.x - previous.x) / 6,
                y: points[index].y - (afterPoint.y - previous.y) / 6)
            segments.append(OnbGiftChartSegment(to: points[index], control1: firstControl, control2: secondControl))
        }
        return segments
    }
}

// MARK: - Carte

/// `ChartCard` : légende, intitulé de la métrique, puis axes et tracé.
private struct OnbGiftChartCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnbGiftChartLegend()
                .padding(.bottom, 18)
            metric
                .padding(.bottom, 8)
            HStack(spacing: 0) {
                OnbGiftChartYAxis()
                VStack(spacing: 0) {
                    OnbGiftMathChartPlot()
                    OnbGiftChartXAxis()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .fill(Color(hex: 0x0B0B0B))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusLarge)
                        .stroke(Color(hex: 0x303030), lineWidth: 1)
                )
        )
    }

    /// `styles.metric` : flèche montante et « Note en maths (/20) ».
    private var metric: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: 0x929292))
            Text("Note en maths (/20)")
                .font(.system(size: 9, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: 0x929292))
        }
    }
}

/// `ChartLegend` : les deux trajectoires, celle avec Duello en blanc.
private struct OnbGiftChartLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(OnbGiftChartData.legendSeries) { series in
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(series.color)
                        .frame(width: 20, height: 3)
                    Text(series.label)
                        .font(.system(size: 11, weight: series.emphasized ? .black : .bold))
                        .foregroundStyle(series.emphasized ? Color.white : Color(hex: 0x929292))
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// `ChartYAxis` : graduations 16 / 12 / 8, de haut en bas.
private struct OnbGiftChartYAxis: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(OnbGiftChartData.gradeTicks, id: \.self) { grade in
                Text("\(Int(grade))")
                    .font(.system(size: 8, weight: grade == 16 ? .black : .bold))
                    .foregroundStyle(grade == 16 ? Color.white : Color(hex: 0x777777))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: -4)
                if grade != OnbGiftChartData.gradeTicks.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(width: 25, height: OnbGiftChartData.plotHeight)
        .padding(.trailing, 6)
    }
}

/// `ChartXAxis` : les six repères de temps, le dernier (« 1 an ») en blanc.
private struct OnbGiftChartXAxis: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(OnbGiftChartData.months.indices, id: \.self) { index in
                let isLast = index == OnbGiftChartData.months.count - 1
                Text(OnbGiftChartData.months[index])
                    .font(.system(size: 8, weight: isLast ? .black : .bold))
                    .foregroundStyle(isLast ? Color.white : Color(hex: 0x777777))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
    }
}

/// Le rappel sous la carte : la régularité avant le résultat.
private struct OnbGiftPatienceNote: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color.white)
            Text("La régularité compte plus qu’un résultat immédiat.")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.white)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .fill(Color(hex: 0x171717))
        )
    }
}
