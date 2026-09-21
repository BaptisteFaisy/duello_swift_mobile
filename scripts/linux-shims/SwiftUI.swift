// Shim SwiftUI — NE FAIT PAS PARTIE DE L'APP. Jamais livré (hors cible Xcode).
//
// SwiftUI n'existe pas sous Linux. Ce module factice laisse `swiftc -typecheck`
// voir les vues de Duello : on garde les types et les signatures, on perd le
// rendu. Il est permissif (aucune exigence de rendu, modificateurs renvoyant
// `some View`) mais jamais faux : les signatures recopiées sont celles du vrai
// framework (iOS 16 / Swift 5).
//
// Découpé en trois fichiers du même module `SwiftUI` :
//   SwiftUI.swift           cœur : protocoles, builders, wrappers, types
//   SwiftUI+Views.swift     types de vue concrets (Text, VStack, Button…)
//   SwiftUI+Modifiers.swift surface `extension View`

@_exported import Foundation
// Sous Linux, `URLSession`/`URLSessionWebSocketTask` vivent dans
// `FoundationNetworking`, que `Foundation` ne réexporte pas — contrairement à
// ce qui se passe sur Apple. Les fichiers de Duello n'important que SwiftUI,
// c'est ici que le réexport doit avoir lieu.
@_exported import FoundationNetworking
@_exported import Combine
// `@_exported` : en iOS, `import SwiftUI` rend les types UIKit visibles
// (`UIPasteboard`, `UIImage`…). Sans le réexport, le shim refusait à tort du
// code qui n'importe que SwiftUI.
@_exported import UIKit

// MARK: - CoreGraphics (absents de Foundation sous Linux)

public enum CGLineCap: Int, Sendable { case butt, round, square }
public enum CGLineJoin: Int, Sendable { case miter, round, bevel }

// MARK: - Cœur

/// Vue factice : ce que renvoient tous les modificateurs du shim.
public struct _ShimView: View {
    /// `nonisolated` : ce type sert de valeur par défaut dans les signatures du
    /// shim (`message: () -> M = { EmptyView() }`), expressions évaluées hors
    /// contexte isolé.
    public nonisolated init() {}
    public var body: _ShimView { self }
}

/// Protocole `View`, isolé au fil principal : c'est le cas du SDK employé pour
/// construire l'app (`@MainActor` sur `View` depuis Xcode 15, y compris pour
/// une cible iOS 16). Conséquence modélisée : un type qui conforme devient
/// isolé, donc son `init` peut appeler un initialiseur `@MainActor` — c'est ce
/// que fait `DictControlView`.
///
/// Les initialiseurs des types du shim sont marqués `nonisolated` : ils
/// apparaissent en valeur par défaut des signatures (`message: () -> M = {
/// EmptyView() }`), expressions évaluées hors contexte isolé.
@MainActor @preconcurrency
public protocol View {
    associatedtype Body: View
    @ViewBuilder @MainActor var body: Self.Body { get }
}

/// Conformité triviale des types du shim : `body` renvoie `_ShimView`.
public protocol _ShimLeaf: View where Body == _ShimView {}
extension _ShimLeaf { public var body: _ShimView { _ShimView() } }

extension Never: _ShimLeaf {}

extension Optional: View where Wrapped: View {
    public var body: _ShimView { _ShimView() }
}

public struct _ShimConditional<A: View, B: View>: _ShimLeaf { public nonisolated init() {} }

/// Toute expression d'un corps de vue est déjà une vue.
public protocol DynamicProperty {}

@resultBuilder
public struct ViewBuilder {
    public static func buildExpression<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock() -> _ShimView { _ShimView() }
    public static func buildBlock<C: View>(_ content: C) -> C { content }
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> _ShimView { _ShimView() }
    public static func buildBlock<C0: View, C1: View, C2: View>(
        _ c0: C0, _ c1: C1, _ c2: C2
    ) -> _ShimView { _ShimView() }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3
    ) -> _ShimView { _ShimView() }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4
    ) -> _ShimView { _ShimView() }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5
    ) -> _ShimView { _ShimView() }
    public static func buildBlock<
        C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View
    >(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> _ShimView {
        _ShimView()
    }
    public static func buildBlock<
        C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View
    >(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7)
        -> _ShimView
    { _ShimView() }
    public static func buildBlock<
        C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View
    >(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8)
        -> _ShimView
    { _ShimView() }
    public static func buildBlock<
        C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View,
        C9: View
    >(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8,
        _ c9: C9
    ) -> _ShimView { _ShimView() }

    public static func buildOptional<C: View>(_ component: C?) -> C? { component }
    public static func buildEither<T: View>(first component: T) -> _ShimView { _ShimView() }
    public static func buildEither<T: View>(second component: T) -> _ShimView { _ShimView() }
    public static func buildArray<C: View>(_ components: [C]) -> _ShimView { _ShimView() }
    public static func buildLimitedAvailability<C: View>(_ component: C) -> _ShimView { _ShimView() }
}

// MARK: - Localisation

public struct LocalizedStringKey:
    Equatable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation
{
    public nonisolated init(stringLiteral value: String) {}
    public nonisolated init(_ value: String) {}
    public nonisolated init(verbatim: String) {}
    public nonisolated init(stringInterpolation: StringInterpolation) {}

    /// Interpolation propre à SwiftUI : `Text("… \(date, style: .time)")`.
    /// Le `DefaultStringInterpolation` de la stdlib ne connaît pas la variante
    /// `style:` — c'est un `appendInterpolation` de SwiftUI.
    public struct StringInterpolation: StringInterpolationProtocol {
        public nonisolated init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {}
        public mutating func appendInterpolation(_ date: Date, style: Text.DateStyle) {}
        public mutating func appendInterpolation(_ value: String) {}
        /// Attrape-tout : toute autre valeur interpolée.
        public mutating func appendInterpolation<T>(_ value: T) {}
    }
}

// MARK: - Géométrie / alignements / unités

public struct EdgeInsets: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat
    public nonisolated init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
    public nonisolated init() { self.init(top: 0, leading: 0, bottom: 0, trailing: 0) }
}

public enum Edge: Hashable, Sendable {
    case top, leading, bottom, trailing

    public struct Set: OptionSet, Sendable {
        public let rawValue: Int
        public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1 << 0)
        public static let leading = Set(rawValue: 1 << 1)
        public static let bottom = Set(rawValue: 1 << 2)
        public static let trailing = Set(rawValue: 1 << 3)
        public static let horizontal: Set = [.leading, .trailing]
        public static let vertical: Set = [.top, .bottom]
        public static let all: Set = [.top, .leading, .bottom, .trailing]
    }
}

public enum HorizontalAlignment: Hashable, Sendable { case leading, center, trailing }

public enum VerticalAlignment: Hashable, Sendable {
    case top, center, bottom, firstTextBaseline, lastTextBaseline
}

public struct Alignment: Hashable, Sendable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment
    public nonisolated init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
    public static let center = Alignment(horizontal: .center, vertical: .center)
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    public static let top = Alignment(horizontal: .center, vertical: .top)
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

public struct UnitPoint: Hashable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public nonisolated init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
    public nonisolated init() { self.init(x: 0.5, y: 0.5) }
    public static let zero = UnitPoint(x: 0, y: 0)
    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let leading = UnitPoint(x: 0, y: 0.5)
    public static let trailing = UnitPoint(x: 1, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0)
    public static let bottom = UnitPoint(x: 0.5, y: 1)
    public static let topLeading = UnitPoint(x: 0, y: 0)
    public static let topTrailing = UnitPoint(x: 1, y: 0)
    public static let bottomLeading = UnitPoint(x: 0, y: 1)
    public static let bottomTrailing = UnitPoint(x: 1, y: 1)
}

public struct Angle: Hashable, Sendable {
    public var degrees: Double
    public nonisolated init(degrees: Double) { self.degrees = degrees }
    public nonisolated init(radians: Double) { self.degrees = radians * 180 / .pi }
    public static let zero = Angle(degrees: 0)
    public static func degrees(_ degrees: Double) -> Angle { Angle(degrees: degrees) }
    public static func radians(_ radians: Double) -> Angle { Angle(radians: radians) }
}

public enum ContentMode: Hashable, Sendable { case fit, fill }

public enum TextAlignment: Hashable, Sendable { case leading, center, trailing }

public enum Axis: Hashable, Sendable {
    case horizontal, vertical
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int
        public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1 << 0)
        public static let vertical = Set(rawValue: 1 << 1)
        public static let all: Set = [.horizontal, .vertical]
    }
}

public enum ColorScheme: Hashable, Sendable { case light, dark }

public enum LayoutDirection: Hashable, Sendable { case leftToRight, rightToLeft }

public enum Visibility: Hashable, Sendable { case automatic, visible, hidden }

public struct SafeAreaRegions: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let container = SafeAreaRegions(rawValue: 1 << 0)
    public static let keyboard = SafeAreaRegions(rawValue: 1 << 1)
    public static let all: SafeAreaRegions = [.container, .keyboard]
}

public struct CoordinateSpace: Hashable, Sendable {
    public enum Kind: Hashable, Sendable { case global, local, named(AnyHashable) }
    public let kind: Kind
    private init(_ kind: Kind) { self.kind = kind }
    public static let global = CoordinateSpace(.global)
    public static let local = CoordinateSpace(.local)
    public static func named(_ name: AnyHashable) -> CoordinateSpace { CoordinateSpace(.named(name)) }
}

public struct NamedCoordinateSpace: Hashable, Sendable {
    public static let global = NamedCoordinateSpace()
    public static let local = NamedCoordinateSpace()
    public static func named(_ name: AnyHashable) -> NamedCoordinateSpace { NamedCoordinateSpace() }
}

public struct Transaction {
    public nonisolated init() {}
    public nonisolated init(animation: Animation?) {}
    public var animation: Animation?
}

// MARK: - Styles

public protocol ShapeStyle {}

public protocol Shape: View {
    func path(in rect: CGRect) -> Path
}
extension Shape {
    public var body: _ShimView { _ShimView() }
}

public protocol InsettableShape: Shape {}
extension InsettableShape {
    public func inset(by amount: CGFloat) -> some InsettableShape { self }
}

public struct FillStyle: Equatable, Sendable {
    public var isEOFilled: Bool
    public var isAntialiased: Bool
    public nonisolated init(eoFill: Bool = false, antialiased: Bool = true) {
        self.isEOFilled = eoFill
        self.isAntialiased = antialiased
    }
}

public struct StrokeStyle: Equatable, Sendable {
    public var lineWidth: CGFloat
    public var lineCap: CGLineCap
    public var lineJoin: CGLineJoin
    public var miterLimit: CGFloat
    public var dash: [CGFloat]
    public var dashPhase: CGFloat
    public nonisolated init(
        lineWidth: CGFloat = 1,
        lineCap: CGLineCap = .butt,
        lineJoin: CGLineJoin = .miter,
        miterLimit: CGFloat = 10,
        dash: [CGFloat] = [CGFloat](),
        dashPhase: CGFloat = 0
    ) {
        self.lineWidth = lineWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.dash = dash
        self.dashPhase = dashPhase
    }
}

public struct Material: ShapeStyle, Sendable {
    public static let ultraThinMaterial = Material()
    public static let thinMaterial = Material()
    public static let regularMaterial = Material()
    public static let thickMaterial = Material()
    public static let ultraThickMaterial = Material()
    public static let bar = Material()
}

public struct HierarchicalShapeStyle: ShapeStyle, Sendable {
    public nonisolated init() {}
}
extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: HierarchicalShapeStyle { .init() }
    public static var secondary: HierarchicalShapeStyle { .init() }
    public static var tertiary: HierarchicalShapeStyle { .init() }
    public static var quaternary: HierarchicalShapeStyle { .init() }
}

// MARK: - Couleurs / polices / animations

public struct Color: View, ShapeStyle, Hashable, Sendable {
    public enum RGBColorSpace: Hashable, Sendable { case sRGB, sRGBLinear, displayP3 }

    public nonisolated init(red: Double, green: Double, blue: Double, opacity: Double = 1) {}
    public nonisolated init(white: Double, opacity: Double = 1) {}
    public nonisolated init(_ colorSpace: RGBColorSpace, white: Double, opacity: Double = 1) {}
    public nonisolated init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {}
    public nonisolated init(_ colorSpace: RGBColorSpace, red: Double, green: Double, blue: Double, opacity: Double = 1) {}
    public nonisolated init(_ name: String, bundle: Bundle? = nil) {}

    public static let clear = Color(white: 0, opacity: 0)
    public static let black = Color(white: 0)
    public static let white = Color(white: 1)
    public static let gray = Color(white: 0.5)
    public static let red = Color(red: 1, green: 0, blue: 0)
    public static let green = Color(red: 0, green: 1, blue: 0)
    public static let blue = Color(red: 0, green: 0, blue: 1)
    public static let orange = Color(red: 1, green: 0.5, blue: 0)
    public static let yellow = Color(red: 1, green: 1, blue: 0)
    public static let purple = Color(red: 0.5, green: 0, blue: 0.5)
    public static let pink = Color(red: 1, green: 0.5, blue: 0.7)
    public static let brown = Color(red: 0.5, green: 0.3, blue: 0.1)
    public static let teal = Color(red: 0, green: 0.5, blue: 0.5)
    public static let indigo = Color(red: 0.3, green: 0, blue: 0.6)
    public static let mint = Color(red: 0, green: 0.8, blue: 0.6)
    public static let cyan = Color(red: 0, green: 0.8, blue: 0.9)
    public static let primary = Color(white: 0)
    public static let secondary = Color(white: 0.4)
    public static let accentColor = Color(red: 0, green: 0.5, blue: 1)

    public var body: _ShimView { _ShimView() }

    public func opacity(_ opacity: Double) -> Color { self }
}

extension ShapeStyle where Self == Color {
    public static var clear: Color { .clear }
    public static var black: Color { .black }
    public static var white: Color { .white }
    public static var gray: Color { .gray }
    public static var red: Color { .red }
    public static var green: Color { .green }
    public static var blue: Color { .blue }
    public static var orange: Color { .orange }
    public static var yellow: Color { .yellow }
    public static var purple: Color { .purple }
    public static var pink: Color { .pink }
    public static var brown: Color { .brown }
    public static var teal: Color { .teal }
    public static var indigo: Color { .indigo }
    public static var mint: Color { .mint }
    public static var cyan: Color { .cyan }
    public static var accentColor: Color { .accentColor }
}

public struct Gradient: Hashable, Sendable {
    public struct Stop: Hashable, Sendable {
        public var color: Color
        public var location: CGFloat
        public nonisolated init(color: Color, location: CGFloat) {
            self.color = color
            self.location = location
        }
    }
    public var stops: [Stop]
    public nonisolated init(stops: [Stop]) { self.stops = stops }
    public nonisolated init(colors: [Color]) { self.stops = [] }
}

public struct LinearGradient: View, ShapeStyle, Sendable {
    public nonisolated init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {}
    public nonisolated init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {}
    public nonisolated init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) {}
    public var body: _ShimView { _ShimView() }
}

public struct RadialGradient: View, ShapeStyle, Sendable {
    public nonisolated init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    public nonisolated init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    public var body: _ShimView { _ShimView() }
}

public struct AngularGradient: View, ShapeStyle, Sendable {
    public nonisolated init(colors: [Color], center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {}
    public nonisolated init(gradient: Gradient, center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {}
    public var body: _ShimView { _ShimView() }
}

public struct Font: Hashable, Sendable {
    public struct Weight: Hashable, Sendable {
        public let rawValue: Double
        public nonisolated init(_ rawValue: Double) { self.rawValue = rawValue }
        public static let ultraLight = Weight(100)
        public static let thin = Weight(200)
        public static let light = Weight(300)
        public static let regular = Weight(400)
        public static let medium = Weight(500)
        public static let semibold = Weight(600)
        public static let bold = Weight(700)
        public static let heavy = Weight(800)
        public static let black = Weight(900)
    }

    public struct Design: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case `default`, serif, rounded, monospaced }
        public let kind: Kind
        public static let `default` = Design(kind: .default)
        public static let serif = Design(kind: .serif)
        public static let rounded = Design(kind: .rounded)
        public static let monospaced = Design(kind: .monospaced)
    }

    public enum TextStyle: Hashable, Sendable {
        case largeTitle, title, title2, title3, headline, subheadline
        case body, callout, footnote, caption, caption2
    }

    public static let largeTitle = Font()
    public static let title = Font()
    public static let title2 = Font()
    public static let title3 = Font()
    public static let headline = Font()
    public static let subheadline = Font()
    public static let body = Font()
    public static let callout = Font()
    public static let footnote = Font()
    public static let caption = Font()
    public static let caption2 = Font()

    public struct Width: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case standard, compressed, condensed, expanded }
        public let kind: Kind
        public static let standard = Width(kind: .standard)
        public static let compressed = Width(kind: .compressed)
        public static let condensed = Width(kind: .condensed)
        public static let expanded = Width(kind: .expanded)
    }

    public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font { Font() }
    public static func system(_ style: TextStyle, design: Design = .default) -> Font { Font() }
    public static func custom(_ name: String, size: CGFloat) -> Font { Font() }
    public static func custom(_ name: String, fixedSize: CGFloat) -> Font { Font() }

    // Dérivées de police (iOS 13+ pour les deux premières, 16 pour `width`).
    public func monospacedDigit() -> Font { self }
    public func monospaced() -> Font { self }
    public func italic() -> Font { self }
    public func bold() -> Font { self }
    public func weight(_ weight: Weight) -> Font { self }
    public func width(_ width: Width) -> Font { self }
    public func leading(_ leading: Leading) -> Font { self }

    public struct Leading: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case standard, tight, loose }
        public let kind: Kind
        public static let standard = Leading(kind: .standard)
        public static let tight = Leading(kind: .tight)
        public static let loose = Leading(kind: .loose)
    }
}

public typealias FontWeight = Font.Weight

public struct Animation: Equatable, Sendable {
    public static let `default` = Animation()
    public static let linear = Animation()
    public static let easeIn = Animation()
    public static let easeOut = Animation()
    public static let easeInOut = Animation()
    public static func linear(duration: Double) -> Animation { Animation() }
    public static func easeIn(duration: Double) -> Animation { Animation() }
    public static func easeOut(duration: Double) -> Animation { Animation() }
    public static func easeInOut(duration: Double) -> Animation { Animation() }
    public static func spring(response: Double = 0.55, dampingFraction: Double = 0.825, blendDuration: Double = 0) -> Animation { Animation() }
    public static func spring(duration: Double, bounce: Double, blendDuration: Double = 0) -> Animation { Animation() }
    public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: Double = 0.25) -> Animation { Animation() }
    public static func interpolatingSpring(stiffness: Double, damping: Double, initialVelocity: Double = 0) -> Animation { Animation() }
    public static func interpolatingSpring(mass: Double, stiffness: Double, damping: Double, initialVelocity: Double = 0) -> Animation { Animation() }
    public static func timingCurve(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double, duration: Double) -> Animation { Animation() }
    public func speed(_ speed: Double) -> Animation { self }
    public func delay(_ delay: Double) -> Animation { self }
    public func repeatCount(_ count: Int, autoreverses: Bool = true) -> Animation { self }
    public func repeatForever(autoreverses: Bool = true) -> Animation { self }
}

public struct AnyTransition: Sendable {
    public static let identity = AnyTransition()
    public static let opacity = AnyTransition()
    public static let scale = AnyTransition()
    public static let slide = AnyTransition()
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition { AnyTransition() }
    public static func move(edge: Edge) -> AnyTransition { AnyTransition() }
    public static func offset(_ offset: CGSize) -> AnyTransition { AnyTransition() }
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition { AnyTransition() }
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition { AnyTransition() }
    public func combined(with other: AnyTransition) -> AnyTransition { self }
    public func animation(_ animation: Animation?) -> AnyTransition { self }
}

public struct EmptyAnimation: Equatable, Sendable {}

// MARK: - Espace de noms

public struct Namespace: DynamicProperty {
    public struct ID: Hashable, Sendable {
        public nonisolated init() {}
    }
    public nonisolated init() {}
    public var wrappedValue: ID { ID() }
}

// MARK: - Environnement

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
}

public struct EnvironmentValues {
    public nonisolated init() {}
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { fatalError("shim SwiftUI : EnvironmentValues n'a pas de stockage") }
        set { _ = newValue }
    }

    public var colorScheme: ColorScheme { .light }
    public var dismiss: DismissAction { DismissAction() }
    public var accessibilityReduceMotion: Bool { false }
    public var accessibilityReduceTransparency: Bool { false }
    public var scenePhase: ScenePhase { .active }
    public var locale: Locale { Locale.current }
    public var calendar: Calendar { Calendar.current }
    public var timeZone: TimeZone { TimeZone.current }
    // `nonmutating set` comme dans le SDK : sans écriture, `\.openURL` est un
    // `KeyPath` et `.environment(\.openURL, …)` — qui exige un
    // `WritableKeyPath` — ne compile pas.
    public var openURL: OpenURLAction {
        get { OpenURLAction() }
        nonmutating set {}
    }
    public var refresh: RefreshAction { RefreshAction() }
    public var isEnabled: Bool { true }
    public var editMode: Binding<EditMode>? { nil }
    public var horizontalSizeClass: UserInterfaceSizeClass? { .compact }
    public var verticalSizeClass: UserInterfaceSizeClass? { .regular }
    public var displayScale: CGFloat { 2 }
    public var pixelLength: CGFloat { 0.5 }
    public var layoutDirection: LayoutDirection { .leftToRight }
    public var legibilityWeight: LegibilityWeight? { .regular }
    public var colorSchemeContrast: ColorSchemeContrast { .standard }
    public var dynamicTypeSize: DynamicTypeSize { .large }
    public var sizeCategory: ContentSizeCategory { .large }
}

public struct DismissAction {
    public func callAsFunction() {}
}

public struct OpenURLAction {
    /// Résultat d'un gestionnaire d'ouverture d'URL.
    public struct Result {
        public static let handled = Result()
        public static let discarded = Result()
        public static let systemAction = Result()
    }

    public nonisolated init() {}
    public nonisolated init(handler: @escaping (URL) -> OpenURLAction.Result) {}
    public func callAsFunction(_ url: URL) {}
    public func callAsFunction(_ url: URL, completion: @escaping (Bool) -> Void) {}
}

public struct RefreshAction {
    public func callAsFunction() async {}
}

public enum ScenePhase: Hashable, Sendable { case active, inactive, background }

public enum UserInterfaceSizeClass: Hashable, Sendable { case compact, regular }

public enum LegibilityWeight: Hashable, Sendable { case regular, bold }

public enum ColorSchemeContrast: Hashable, Sendable { case standard, increased }

public enum EditMode: Hashable, Sendable { case inactive, active, transient }

public enum DynamicTypeSize: Hashable, Comparable, Sendable {
    case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge
    case accessibility1, accessibility2, accessibility3, accessibility4, accessibility5
}

public enum ContentSizeCategory: Hashable, Sendable {
    case extraSmall, small, medium, large, extraLarge, extraExtraLarge, extraExtraExtraLarge
    case accessibilityMedium, accessibilityLarge, accessibilityExtraLarge
    case accessibilityExtraExtraLarge, accessibilityExtraExtraExtraLarge
}

@propertyWrapper
public struct Environment<Value>: DynamicProperty {
    public nonisolated init(_ keyPath: KeyPath<EnvironmentValues, Value>) {}
    public var wrappedValue: Value { fatalError("shim SwiftUI : @Environment n'a pas de valeur") }
}

// MARK: - Préférences

public protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
    static func reduce(value: inout Self.Value, nextValue: () -> Self.Value)
}
extension PreferenceKey {
    public static func reduce(value: inout Self.Value, nextValue: () -> Self.Value) {}
}

// MARK: - Property wrappers d'état

@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value>: DynamicProperty {
    private let getter: () -> Value
    private let setter: (Value) -> Void

    public nonisolated init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }
    public nonisolated init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) {
        self.getter = get
        self.setter = { _ = $0 }
    }
    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }
    public var projectedValue: Binding<Value> { self }
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
    public var transaction: Transaction { Transaction() }
    public func animation(_ animation: Animation? = .default) -> Binding<Value> { self }
}

extension Binding: @unchecked Sendable where Value: Sendable {}
extension Binding: Sequence where Value: MutableCollection {
    public func makeIterator() -> Value.Iterator { wrappedValue.makeIterator() }
}
extension Binding: Collection where Value: MutableCollection {
    public typealias Index = Value.Index
    public var startIndex: Index { wrappedValue.startIndex }
    public var endIndex: Index { wrappedValue.endIndex }
    public subscript(position: Index) -> Value.Element { wrappedValue[position] }
    public func index(after i: Index) -> Index { wrappedValue.index(after: i) }
}
extension Binding: BidirectionalCollection where Value: MutableCollection, Value: BidirectionalCollection {
    public func index(before i: Index) -> Index { wrappedValue.index(before: i) }
}
extension Binding: RandomAccessCollection where Value: MutableCollection, Value: RandomAccessCollection {}
extension Binding where Value: MutableCollection, Value.Index == Int {
    public var count: Int { wrappedValue.count }
}
extension Binding {
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        Binding<Subject>(get: { self.wrappedValue[keyPath: keyPath] }, set: { self.wrappedValue[keyPath: keyPath] = $0 })
    }
}

@propertyWrapper
public struct State<Value>: DynamicProperty {
    public nonisolated init(wrappedValue value: Value) {}
    /// Forme utilisée dans un `init` de vue : `_x = State(initialValue: v)`.
    public nonisolated init(initialValue value: Value) {}
    public nonisolated init() {}
    public var wrappedValue: Value {
        get { fatalError("shim SwiftUI : @State n'a pas de valeur") }
        nonmutating set {}
    }
    public var projectedValue: Binding<Value> { Binding.constant(wrappedValue) }
}

@propertyWrapper
public struct StateObject<ObjectType: ObservableObject>: DynamicProperty {
    public nonisolated init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) {}
    public var wrappedValue: ObjectType { fatalError("shim SwiftUI : @StateObject n'a pas de valeur") }
    public var projectedValue: ObservedObject<ObjectType>.Wrapper { ObservedObject<ObjectType>.Wrapper() }
}

@propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject>: DynamicProperty {
    @dynamicMemberLookup
    public struct Wrapper {
        public nonisolated init() {}
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            Binding.constant(unsafeBitCast(0, to: Subject.self))
        }
    }
    public nonisolated init(wrappedValue: ObjectType) {}
    // Settable, comme dans le SDK : `self.monitor = monitor` dans un `init`
    // passe par ce setter.
    public var wrappedValue: ObjectType {
        get { fatalError("shim SwiftUI : @ObservedObject n'a pas de valeur") }
        set {}
    }
    public var projectedValue: Wrapper { Wrapper() }
}

@propertyWrapper
public struct EnvironmentObject<ObjectType: ObservableObject>: DynamicProperty {
    @dynamicMemberLookup
    public struct Wrapper {
        public nonisolated init() {}
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            Binding.constant(unsafeBitCast(0, to: Subject.self))
        }
    }
    public nonisolated init() {}
    public var wrappedValue: ObjectType { fatalError("shim SwiftUI : @EnvironmentObject n'a pas de valeur") }
    public var projectedValue: Wrapper { Wrapper() }
}

@propertyWrapper
public struct FocusState<Value: Hashable>: DynamicProperty {
    public typealias Binding = SwiftUI.Binding<Value>
    public nonisolated init() {}
    public nonisolated init(wrappedValue: Value) {}
    public var wrappedValue: Value {
        get { fatalError("shim SwiftUI : @FocusState n'a pas de valeur") }
        nonmutating set {}
    }
    public var projectedValue: FocusState<Value>.Binding { .constant(wrappedValue) }
}

@propertyWrapper
public struct GestureState<Value>: DynamicProperty {
    public nonisolated init(wrappedValue: Value) {}
    public nonisolated init() {}
    public var wrappedValue: Value {
        get { fatalError("shim SwiftUI : @GestureState n'a pas de valeur") }
        nonmutating set {}
    }
    public var projectedValue: Binding<Value> { .constant(wrappedValue) }
}

@propertyWrapper
public struct AppStorage<Value>: DynamicProperty {
    public nonisolated init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) {}
    public nonisolated init(_ key: String, store: UserDefaults? = nil) where Value: ExpressibleByNilLiteral {}
    public var wrappedValue: Value {
        get { fatalError("shim SwiftUI : @AppStorage n'a pas de valeur") }
        nonmutating set {}
    }
    public var projectedValue: Binding<Value> { .constant(wrappedValue) }
}

@propertyWrapper
public struct SceneStorage<Value>: DynamicProperty {
    public nonisolated init(wrappedValue: Value, _ key: String) {}
    public nonisolated init(_ key: String) where Value: ExpressibleByNilLiteral {}
    public var wrappedValue: Value {
        get { fatalError("shim SwiftUI : @SceneStorage n'a pas de valeur") }
        nonmutating set {}
    }
    public var projectedValue: Binding<Value> { .constant(wrappedValue) }
}

// MARK: - Géométrie de lecture

public struct GeometryProxy {
    public var size: CGSize { .zero }
    public var safeAreaInsets: EdgeInsets { EdgeInsets() }
    public func frame(in coordinateSpace: CoordinateSpace) -> CGRect { .zero }
}

public struct GeometryReader<Content: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {}
}

public struct ScrollViewProxy {
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {}
}

// MARK: - Layout personnalisé

public struct ProposedViewSize: Equatable, Sendable {
    public var width: CGFloat?
    public var height: CGFloat?
    public nonisolated init(width: CGFloat? = nil, height: CGFloat? = nil) {
        self.width = width
        self.height = height
    }
    /// iOS 16 : depuis une taille concrète.
    public nonisolated init(_ size: CGSize) {
        width = size.width
        height = size.height
    }
    public static let unspecified = ProposedViewSize()
    public static let zero = ProposedViewSize(width: 0, height: 0)
    public static let infinity = ProposedViewSize(width: .infinity, height: .infinity)
    public func replacingUnspecifiedDimensions(by size: CGSize = CGSize(width: 10, height: 10)) -> CGSize { size }
}

public struct LayoutSubview {
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { .zero }
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions { ViewDimensions() }
    public func place(at position: CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {}
    public func place(in bounds: CGRect, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {}
    public var priority: Double { 0 }
}

public struct LayoutSubviews: RandomAccessCollection {
    public typealias Element = LayoutSubview
    public typealias Index = Int
    public var startIndex: Int { 0 }
    public var endIndex: Int { 0 }
    public subscript(position: Int) -> LayoutSubview { LayoutSubview() }
    public func index(after i: Int) -> Int { i + 1 }
}

public struct ViewDimensions {
    public var width: CGFloat { 0 }
    public var height: CGFloat { 0 }
    public subscript(guide: HorizontalAlignment) -> CGFloat { 0 }
    public subscript(guide: VerticalAlignment) -> CGFloat { 0 }
}

public protocol Layout: Animatable {
    associatedtype Cache = Void
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Self.Cache) -> CGSize
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Self.Cache)
    typealias Subviews = LayoutSubviews
}
extension Layout {
    public var animatableData: EmptyAnimatableData {
        get { EmptyAnimatableData() }
        set {}
    }

    /// `MonLayout(spacing: 4) { contenu }` : la syntaxe d'appel d'une mise en
    /// page, qui produit une vue.
    public func callAsFunction<V: View>(@ViewBuilder _ content: () -> V) -> some View { _ShimView() }
}

// MARK: - Animation (protocole)

public protocol VectorArithmetic: AdditiveArithmetic {
    mutating func scale(by rhs: Double)
    var magnitudeSquared: Double { get }
}
extension Double: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= rhs }
    public var magnitudeSquared: Double { self * self }
}
extension CGFloat: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= CGFloat(rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}
extension Float: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= Float(rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}
extension Int: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self = Int(Double(self) * rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}

public struct EmptyAnimatableData: VectorArithmetic {
    public nonisolated init() {}
    public static var zero: EmptyAnimatableData { EmptyAnimatableData() }
    public static func + (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { lhs }
    public static func - (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { lhs }
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { 0 }
}

public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic
    var animatableData: Self.AnimatableData { get set }
}
extension Animatable where Self: VectorArithmetic {
    public var animatableData: Self {
        get { self }
        set { self = newValue }
    }
}

// MARK: - Modificateurs de vue

public struct _ViewModifierContent<Modifier>: View {
    public var body: _ShimView { _ShimView() }
}

public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ViewModifierContent<Self>
    @ViewBuilder func body(content: Self.Content) -> Self.Body
}

// MARK: - Gestes

public protocol Gesture {}

public struct DragGesture: Gesture {
    public struct Value: Equatable {
        public var location: CGPoint
        public var startLocation: CGPoint
        public var translation: CGSize
        public var predictedEndLocation: CGPoint
        public var predictedEndTranslation: CGSize
        public var time: Date
        public var velocity: CGSize
    }
    public nonisolated init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local) {}
}

public struct TapGesture: Gesture {
    public nonisolated init(count: Int = 1) {}
}

public struct LongPressGesture: Gesture {
    public nonisolated init(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10) {}
}

public struct SpatialTapGesture: Gesture {
    public struct Value { public var location: CGPoint }
    public nonisolated init(count: Int = 1, coordinateSpace: CoordinateSpace = .local) {}
}

public struct MagnificationGesture: Gesture {
    public typealias Value = CGFloat
    public nonisolated init(minimumScaleDelta: CGFloat = 0.01) {}
}

public struct RotationGesture: Gesture {
    public typealias Value = Angle
    public nonisolated init(minimumAngleDelta: Angle = .zero) {}
}

public struct _ShimGesture<Value>: Gesture {
    public nonisolated init() {}
}

// MARK: - Scène / App

public protocol Scene {
    associatedtype Body: Scene
    @SceneBuilder var body: Self.Body { get }
}

public struct _ShimScene: Scene {
    public nonisolated init() {}
    public var body: _ShimScene { self }
}

@resultBuilder
public struct SceneBuilder {
    public static func buildBlock<C: Scene>(_ content: C) -> C { content }
    public static func buildBlock<C0: Scene, C1: Scene>(_ c0: C0, _ c1: C1) -> _ShimScene { _ShimScene() }
    public static func buildOptional<C: Scene>(_ component: C?) -> C? { component }
    public static func buildEither<T: Scene>(first component: T) -> _ShimScene { _ShimScene() }
    public static func buildEither<T: Scene>(second component: T) -> _ShimScene { _ShimScene() }
}

public protocol App {
    associatedtype Body: Scene
    @SceneBuilder var body: Self.Body { get }
    init()
}
extension App {
    public static func main() {}
}

// MARK: - Barres d'outils

public protocol ToolbarContent {}

public struct _ShimToolbarContent: ToolbarContent { public nonisolated init() {} }

extension Optional: ToolbarContent where Wrapped: ToolbarContent {}

@resultBuilder
public struct ToolbarContentBuilder {
    public static func buildExpression<Content: ToolbarContent>(_ content: Content) -> Content { content }
    public static func buildBlock() -> _ShimToolbarContent { _ShimToolbarContent() }
    public static func buildBlock<C: ToolbarContent>(_ content: C) -> C { content }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent>(_ c0: C0, _ c1: C1) -> _ShimToolbarContent { _ShimToolbarContent() }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent>(
        _ c0: C0, _ c1: C1, _ c2: C2
    ) -> _ShimToolbarContent { _ShimToolbarContent() }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent>(
        _ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3
    ) -> _ShimToolbarContent { _ShimToolbarContent() }
    // `-> C?` + conformité d'`Optional` : même montage que `ViewBuilder`, où
    // le `if` sans `else` fonctionne. Une version renvoyant un type concret
    // faisait échouer l'inférence de `C` (« generic parameter 'C' could not be
    // inferred ») dès qu'un `if` apparaissait dans un `toolbar`.
    public static func buildOptional<C: ToolbarContent>(_ component: C?) -> C? { component }
    public static func buildEither<T: ToolbarContent>(first component: T) -> _ShimToolbarContent { _ShimToolbarContent() }
    public static func buildEither<T: ToolbarContent>(second component: T) -> _ShimToolbarContent { _ShimToolbarContent() }
}

public struct ToolbarItemPlacement: Sendable {
    public static let automatic = ToolbarItemPlacement()
    public static let principal = ToolbarItemPlacement()
    public static let navigation = ToolbarItemPlacement()
    public static let navigationBarLeading = ToolbarItemPlacement()
    public static let navigationBarTrailing = ToolbarItemPlacement()
    public static let topBarLeading = ToolbarItemPlacement()
    public static let topBarTrailing = ToolbarItemPlacement()
    public static let bottomBar = ToolbarItemPlacement()
    public static let cancellationAction = ToolbarItemPlacement()
    public static let confirmationAction = ToolbarItemPlacement()
    public static let destructiveAction = ToolbarItemPlacement()
    public static let primaryAction = ToolbarItemPlacement()
    public static let secondaryAction = ToolbarItemPlacement()
    public static let keyboard = ToolbarItemPlacement()
}

public struct ToolbarItem<Content: View>: ToolbarContent {
    public nonisolated init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
}

public struct ToolbarItemGroup<Content: View>: ToolbarContent {
    public nonisolated init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
}

// MARK: - Représentables UIKit

public protocol UIViewControllerRepresentable: View {
    associatedtype UIViewControllerType: UIViewController
    associatedtype Coordinator = Void
    typealias Context = UIViewControllerRepresentableContext<Self>
    func makeUIViewController(context: Self.Context) -> Self.UIViewControllerType
    func updateUIViewController(_ uiViewController: Self.UIViewControllerType, context: Self.Context)
    func makeCoordinator() -> Self.Coordinator
}
extension UIViewControllerRepresentable {
    public var body: _ShimView { _ShimView() }
}
extension UIViewControllerRepresentable where Coordinator == Void {
    public func makeCoordinator() -> Void {}
}
extension UIViewControllerRepresentable {
    public static func dismantleUIViewController(_ uiViewController: Self.UIViewControllerType, coordinator: Self.Coordinator) {}
}

public struct UIViewControllerRepresentableContext<Representable: UIViewControllerRepresentable> {
    public var coordinator: Representable.Coordinator { fatalError("shim SwiftUI") }
    public var environment: EnvironmentValues { EnvironmentValues() }
    public var transaction: Transaction { Transaction() }
}

public protocol UIViewRepresentable: View {
    associatedtype UIViewType: UIView
    associatedtype Coordinator = Void
    typealias Context = UIViewRepresentableContext<Self>
    func makeUIView(context: Self.Context) -> Self.UIViewType
    func updateUIView(_ uiView: Self.UIViewType, context: Self.Context)
    func makeCoordinator() -> Self.Coordinator
}
extension UIViewRepresentable {
    public var body: _ShimView { _ShimView() }
}
extension UIViewRepresentable where Coordinator == Void {
    public func makeCoordinator() -> Void {}
}
extension UIViewRepresentable {
    public static func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator) {}
}

public struct UIViewRepresentableContext<Representable: UIViewRepresentable> {
    public var coordinator: Representable.Coordinator { fatalError("shim SwiftUI") }
    public var environment: EnvironmentValues { EnvironmentValues() }
    public var transaction: Transaction { Transaction() }
}
