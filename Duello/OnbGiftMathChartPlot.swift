//
//  OnbGiftMathChartPlot.swift
//  Duello
//
//  LOT K — extras d’onboarding : le tracé animé du graphique de progression.
//
//  Fichier source Expo porté : `src/components/OnboardingMathProgressChart.tsx`
//  (`ChartPlot`, `ChartCurves`, `useChartAnimation`).
//
//  ⚠️ `react-native-reanimated` n’existe pas côté Swift : la source anime un
//  `strokeDashoffset` sur une longueur approchée (`plotWidth * 2 + hauteur`)
//  pendant 2,4 s en `inOut(cubic)`. Ici, le tracé se révèle par un `trim`
//  animé sur la même durée et la même courbe — même dessin progressif, sans
//  dépendance externe.
//
//  Cible : iOS 16.
//
import SwiftUI

/// `ChartPlot` : la grille de graduations, puis les deux courbes.
struct OnbGiftMathChartPlot: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(OnbGiftChartData.gradeTicks, id: \.self) { grade in
                    Rectangle()
                        .fill(Color(hex: 0x292929))
                        .frame(height: 1)
                        .offset(y: OnbGiftChartData.gradeY(grade))
                }
                OnbGiftChartCurves(width: proxy.size.width)
            }
        }
        .frame(height: OnbGiftChartData.plotHeight)
        .accessibilityElement()
        .accessibilityLabel(
            "Comparaison des notes en mathématiques sur un an, à partir de 8 sur 20, "
                + "avec Duello et sans l’application ; la trajectoire avec Duello atteint 16 sur 20")
    }
}

/// `ChartCurves` : les deux tracés, révélés ensemble au premier affichage.
private struct OnbGiftChartCurves: View {
    /// Largeur mesurée du tracé : relance l’animation quand elle est connue.
    let width: CGFloat

    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            ForEach(OnbGiftChartData.drawingSeries) { series in
                OnbGiftChartPath(series: series)
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        series.color,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        .opacity(progress > 0 ? 1 : 0)
        .onAppear { draw() }
        .onChange(of: width) { _ in draw() }
    }

    /// `useChartAnimation` : `withTiming(1, 2400 ms, inOut(cubic))`.
    private func draw() {
        guard width > 0 else { return }
        progress = 0
        withAnimation(.easeInOut(duration: 2.4)) { progress = 1 }
    }
}

/// Le chemin d’une trajectoire, aux coordonnées de la zone de tracé.
private struct OnbGiftChartPath: Shape {
    let series: OnbGiftChartSeries

    func path(in rect: CGRect) -> Path {
        OnbGiftChartData.curvePath(series.grades, plotWidth: rect.width)
    }
}
