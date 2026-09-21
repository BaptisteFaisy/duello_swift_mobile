// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `Charts` (Swift Charts, iOS 16+) n'existe pas sous Linux. Ce shim déclare le
// strict nécessaire utilisé par `DuelloUI.swift` et
// `ChartSubjectTimeTrendChart.swift`, afin de satisfaire le vérificateur de
// types. Aucun de ces types n'est instancié à l'exécution.
//
// Compromis assumés (voir SHIM_SPEC.md) :
//   * `foregroundStyle` n'est pas contraint à `ShapeStyle` : le shim ne dépend
//     pas de la déclaration de `ShapeStyle` par le shim SwiftUI ;
//   * `chartXAxis(_:)`/`chartYAxis(_:)` prennent `AxisVisibility` — le vrai
//     type du paramètre est `SwiftUI.Visibility`, absent des shims ;
//   * seuls les inits réellement appelés sont déclarés.
import Foundation
import SwiftUI

// MARK: - Valeurs traçables

public protocol Plottable {}
extension String: Plottable {}
extension Double: Plottable {}
extension Int: Plottable {}
extension Date: Plottable {}

public struct PlottableValue<Value> {
    init() {}

    public static func value(_ label: String, _ value: Value) -> PlottableValue<Value> {
        PlottableValue()
    }
}

// MARK: - Contenu de graphique

public protocol ChartContent {}

public struct _ShimChartContent: ChartContent {}

extension ChartContent {
    public func foregroundStyle<S>(_ style: S) -> some ChartContent { _ShimChartContent() }
    public func cornerRadius(_ radius: CGFloat) -> some ChartContent { _ShimChartContent() }
    public func interpolationMethod(_ method: InterpolationMethod) -> some ChartContent { _ShimChartContent() }
}

@resultBuilder
public enum ChartContentBuilder {
    public static func buildBlock<Content: ChartContent>(_ content: Content) -> Content { content }
    public static func buildBlock<C0: ChartContent, C1: ChartContent>(_ c0: C0, _ c1: C1) -> _ShimChartContent {
        _ShimChartContent()
    }
    public static func buildExpression<Content: ChartContent>(_ expression: Content) -> Content { expression }
}

public struct InterpolationMethod {
    public static let linear = InterpolationMethod()
    public static let cardinal = InterpolationMethod()
    public static let catmullRom = InterpolationMethod()
    public static let monotone = InterpolationMethod()
    public static let stepStart = InterpolationMethod()
    public static let stepCenter = InterpolationMethod()
    public static let stepEnd = InterpolationMethod()
}

// MARK: - Marques

public struct BarMark: ChartContent {
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) {}
}

public struct LineMark: ChartContent {
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) {}
}

public struct PointMark: ChartContent {
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) {}
}

// MARK: - Axes

public enum AxisMarkPosition { case automatic, leading, trailing, top, bottom }
public enum AxisMarkValues { case automatic }
public enum AxisMarkPreset { case automatic }

public protocol AxisContent {}

@resultBuilder
public enum AxisContentBuilder {
    public static func buildBlock<Content: AxisContent>(_ content: Content) -> Content { content }
}

public struct AxisMarks: AxisContent {
    public init(
        preset: AxisMarkPreset = .automatic,
        position: AxisMarkPosition = .automatic,
        values: AxisMarkValues = .automatic
    ) {}
}

/// Remplace `SwiftUI.Visibility` (absent des shims) pour `.chartXAxis(.hidden)`.
public enum AxisVisibility { case automatic, visible, hidden }

// MARK: - Graphique

public struct _ShimChartView: View {
    public init() {}
    public var body: some View { self }
}

public struct Chart<Content: ChartContent>: View {
    public init(@ChartContentBuilder content: () -> Content) {}

    public init<Data: RandomAccessCollection>(
        _ data: Data,
        @ChartContentBuilder content: @escaping (Data.Element) -> Content
    ) where Data.Element: Identifiable {}

    public init<Data: RandomAccessCollection, ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ChartContentBuilder content: @escaping (Data.Element) -> Content
    ) {}

    public var body: some View { _ShimChartView() }
}

extension View {
    public func chartXAxis(_ visibility: AxisVisibility) -> some View { _ShimChartView() }
    public func chartXAxis<Content: AxisContent>(@AxisContentBuilder content: () -> Content) -> some View {
        _ShimChartView()
    }
    public func chartYAxis(_ visibility: AxisVisibility) -> some View { _ShimChartView() }
    public func chartYAxis<Content: AxisContent>(@AxisContentBuilder content: () -> Content) -> some View {
        _ShimChartView()
    }
}
