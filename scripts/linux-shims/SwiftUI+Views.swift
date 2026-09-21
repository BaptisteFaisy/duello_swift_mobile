// Shim SwiftUI — types de vue concrets. NE FAIT PAS PARTIE DE L'APP.

import Foundation
import UIKit

// MARK: - Texte

extension Text {
    /// Styles d'interpolation de date de SwiftUI (`Text.DateStyle`).
    public struct DateStyle: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case time, date, relative, offset, timer }
        public let kind: Kind
        public static let time = DateStyle(kind: .time)
        public static let date = DateStyle(kind: .date)
        public static let relative = DateStyle(kind: .relative)
        public static let offset = DateStyle(kind: .offset)
        public static let timer = DateStyle(kind: .timer)
    }
}

public struct Text: _ShimLeaf {
    public enum Case: Hashable, Sendable { case uppercase, lowercase }
    public enum LineStyle: Hashable, Sendable { case single, thick, double }

    public nonisolated init(_ key: LocalizedStringKey) {}
    public init<S: StringProtocol>(_ content: S) {}
    public nonisolated init(verbatim: String) {}
    /// `Text` d'un texte enrichi (liens, gras) — iOS 15+.
    public nonisolated init(_ attributedString: AttributedString) {}
    /// `Text(date, style: .time)` — iOS 14+.
    public nonisolated init(_ date: Date, style: Text.DateStyle) {}
    /// Décompte natif `Text(timerInterval:)` — iOS 16+.
    public nonisolated init(
        timerInterval: ClosedRange<Date>,
        pauseTime: Date? = nil,
        countsDown: Bool = true,
        showsHours: Bool = true
    ) {}

    public static func + (lhs: Text, rhs: Text) -> Text { Text(verbatim: "") }

    public func bold() -> Text { self }
    public func italic() -> Text { self }
    public func monospaced() -> Text { self }
    public func monospacedDigit() -> Text { self }
    public func fontWeight(_ weight: Font.Weight?) -> Text { self }
    public func fontDesign(_ design: Font.Design?) -> Text { self }
    public func font(_ font: Font?) -> Text { self }
    public func kerning(_ kerning: CGFloat) -> Text { self }
    public func tracking(_ tracking: CGFloat) -> Text { self }
    public func baselineOffset(_ baselineOffset: CGFloat) -> Text { self }
    public func underline(_ isActive: Bool = true, color: Color? = nil) -> Text { self }
    public func strikethrough(_ isActive: Bool = true, color: Color? = nil) -> Text { self }
    public func textCase(_ textCase: Text.Case?) -> Text { self }
    public func foregroundColor(_ color: Color?) -> Text { self }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> Text { self }
    public func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> Text { self }

    public enum Scale: Hashable, Sendable { case `default`, secondary }
}

// MARK: - Images

public struct Image: _ShimLeaf {
    public enum ResizingMode: Hashable, Sendable { case tile, stretch }
    public enum TemplateRenderingMode: Hashable, Sendable { case template, original }
    public enum Interpolation: Hashable, Sendable { case none, low, medium, high }
    public enum Orientation: Hashable, Sendable { case up, down, left, right }

    public nonisolated init(_ name: String, bundle: Bundle? = nil) {}
    public nonisolated init(_ name: String, bundle: Bundle? = nil, label: Text) {}
    public nonisolated init(systemName: String) {}
    public nonisolated init(decorative name: String, bundle: Bundle? = nil) {}
    public nonisolated init(uiImage: UIImage) {}

    public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: Image.ResizingMode = .stretch) -> Image { self }
    public func renderingMode(_ renderingMode: Image.TemplateRenderingMode?) -> Image { self }
    public func interpolation(_ interpolation: Image.Interpolation) -> Image { self }
    public func antialiased(_ isAntialiased: Bool) -> Image { self }
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> Image { self }
    public func symbolVariant(_ variant: SymbolVariants) -> Image { self }
    public func orientation(_ orientation: Image.Orientation) -> Image { self }
}

public struct SymbolRenderingMode: Hashable, Sendable {
    public static let monochrome = SymbolRenderingMode()
    public static let hierarchical = SymbolRenderingMode()
    public static let palette = SymbolRenderingMode()
    public static let multicolor = SymbolRenderingMode()
}

public struct SymbolVariants: Hashable, Sendable {
    public static let none = SymbolVariants()
    public static let circle = SymbolVariants()
    public static let square = SymbolVariants()
    public static let fill = SymbolVariants()
    public static let slash = SymbolVariants()
    public func contains(_ variant: SymbolVariants) -> Bool { true }
}

// MARK: - Formes

public struct Path: Shape, Equatable {
    public nonisolated init() {}
    public nonisolated init(_ rect: CGRect) {}
    public nonisolated init(roundedRect rect: CGRect, cornerRadius: CGFloat) {}
    public nonisolated init(ellipseIn rect: CGRect) {}
    /// `Path { path in … }` : construction par accumulation (iOS 13+).
    public nonisolated init(_ callback: (inout Path) -> ()) {}

    public func path(in rect: CGRect) -> Path { self }
    public var isEmpty: Bool { true }
    public var boundingRect: CGRect { .zero }
    public var cgPath: CGPath { CGPath() }

    public mutating func move(to point: CGPoint) {}
    public mutating func addLine(to point: CGPoint) {}
    public mutating func addQuadCurve(to end: CGPoint, control: CGPoint) {}
    public mutating func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {}
    public mutating func addArc(center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool) {}
    public mutating func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat) {}
    public mutating func addRect(_ rect: CGRect) {}
    public mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize) {}
    public mutating func addEllipse(in rect: CGRect) {}
    public mutating func addPath(_ path: Path) {}
    public mutating func closeSubpath() {}
    public func strokedPath(_ style: StrokeStyle) -> Path { self }
    public func trimmedPath(from: CGFloat, to: CGFloat) -> Path { self }
    public func applying(_ transform: CGAffineTransform) -> Path { self }
}

public struct CGPath {
    public nonisolated init() {}
    public nonisolated init(rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) {}
}

public struct CGAffineTransform: Equatable {
    public static let identity = CGAffineTransform()
    public nonisolated init() {}
}

public struct Rectangle: InsettableShape {
    public nonisolated init() {}
    public func path(in rect: CGRect) -> Path { Path() }
    public func inset(by amount: CGFloat) -> some InsettableShape { self }
}

public struct RoundedRectangle: InsettableShape {
    public struct CornerSize: Hashable, Sendable {
        public var width: CGFloat
        public var height: CGFloat
        public nonisolated init(width: CGFloat, height: CGFloat) { self.width = width; self.height = height }
        public nonisolated init(radius: CGFloat) { self.init(width: radius, height: radius) }
    }
    public enum Style: Hashable, Sendable { case circular, continuous }
    public var cornerSize: CornerSize
    public var style: Style
    public nonisolated init(cornerSize: CornerSize, style: Style = .circular) { self.cornerSize = cornerSize; self.style = style }
    public nonisolated init(cornerRadius: CGFloat, style: Style = .circular) {
        self.cornerSize = CornerSize(radius: cornerRadius)
        self.style = style
    }
    public func path(in rect: CGRect) -> Path { Path() }
    public func inset(by amount: CGFloat) -> some InsettableShape { self }
}

public struct Circle: InsettableShape {
    public nonisolated init() {}
    public func path(in rect: CGRect) -> Path { Path() }
    public func inset(by amount: CGFloat) -> some InsettableShape { self }
}

public struct Capsule: InsettableShape {
    public enum Style: Hashable, Sendable { case circular, continuous }
    public nonisolated init(style: Style = .circular) {}
    public func path(in rect: CGRect) -> Path { Path() }
    public func inset(by amount: CGFloat) -> some InsettableShape { self }
}

public struct Ellipse: InsettableShape {
    public nonisolated init() {}
    public func path(in rect: CGRect) -> Path { Path() }
    public func inset(by amount: CGFloat) -> some InsettableShape { self }
}

public struct UnevenRoundedRectangle: InsettableShape {
    public struct CornerRadii: Hashable, Sendable {
        public nonisolated init(topLeading: CGFloat = 0, bottomLeading: CGFloat = 0, bottomTrailing: CGFloat = 0, topTrailing: CGFloat = 0) {}
    }
    public nonisolated init(cornerRadii: CornerRadii, style: RoundedRectangle.Style = .circular) {}
    public func path(in rect: CGRect) -> Path { Path() }
    public func inset(by amount: CGFloat) -> some InsettableShape { self }
}

// MARK: - Conteneurs

public struct VStack<Content: View>: _ShimLeaf {
    public nonisolated init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}

public struct HStack<Content: View>: _ShimLeaf {
    public nonisolated init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}

public struct ZStack<Content: View>: _ShimLeaf {
    public nonisolated init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {}
}

public struct LazyVStack<Content: View>: _ShimLeaf {
    public nonisolated init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
}

public struct LazyHStack<Content: View>: _ShimLeaf {
    public nonisolated init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
}

public struct PinnedScrollableViews: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1 << 0)
    public static let sectionFooters = PinnedScrollableViews(rawValue: 1 << 1)
}

public struct Group<Content: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder content: () -> Content) {}
}

public struct Divider: _ShimLeaf {
    public nonisolated init() {}
}

public struct Spacer: _ShimLeaf {
    public nonisolated init(minLength: CGFloat? = nil) {}
}

public struct EmptyView: _ShimLeaf {
    public nonisolated init() {}
}

public struct AnyView: View {
    public init<V: View>(_ view: V) {}
    public init<V: View>(_ view: V?) {}
    public init<V: View>(erasing view: V) {}
    public var body: _ShimView { _ShimView() }
}

public struct TupleView<T>: View {
    public var value: T
    public var body: _ShimView { _ShimView() }
}

public struct ConditionalContent<TrueContent: View, FalseContent: View>: View {
    public var body: _ShimView { _ShimView() }
}

public struct ModifiedContent<Content, Modifier>: View {
    public var content: Content
    public var modifier: Modifier
    public var body: _ShimView { _ShimView() }
}

// MARK: - Défilement

public struct ScrollView<Content: View>: _ShimLeaf {
    public nonisolated init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {}
}

public struct ScrollViewReader<Content: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {}
}

public enum ScrollDismissesKeyboardMode: Hashable, Sendable {
    case automatic, immediately, interactively, never
}

public enum ScrollIndicatorVisibility: Hashable, Sendable {
    case automatic, visible, hidden, never
}

// MARK: - Grilles

public struct GridItem: Hashable, Sendable {
    public enum Size: Hashable, Sendable {
        case fixed(CGFloat)
        case flexible(minimum: CGFloat, maximum: CGFloat)
        case adaptive(minimum: CGFloat, maximum: CGFloat)
        public static func flexible() -> GridItem.Size { .flexible(minimum: 10, maximum: .infinity) }
        public static func adaptive(minimum: CGFloat) -> GridItem.Size { .adaptive(minimum: minimum, maximum: .infinity) }
    }
    public var size: Size
    public var spacing: CGFloat?
    public var alignment: Alignment?
    public nonisolated init(_ size: Size, spacing: CGFloat? = nil, alignment: Alignment? = nil) {
        self.size = size
        self.spacing = spacing
        self.alignment = alignment
    }
}

public struct LazyVGrid<Content: View>: _ShimLeaf {
    public nonisolated init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
}

public struct LazyHGrid<Content: View>: _ShimLeaf {
    public nonisolated init(rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
}

public struct Grid<Content: View>: _ShimLeaf {
    public nonisolated init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}

public struct GridRow<Content: View>: _ShimLeaf {
    public nonisolated init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) {}
}

// MARK: - Listes et formulaires

public struct List<SelectionValue: Hashable, Content: View>: _ShimLeaf {
    public nonisolated init(selection: Binding<SelectionValue?>? = nil, @ViewBuilder content: () -> Content) {}
    public nonisolated init(selection: Binding<Set<SelectionValue>>? = nil, @ViewBuilder content: () -> Content) {}
}

public extension List where SelectionValue == Never {
    init(@ViewBuilder content: () -> Content) {}
    init<Data: RandomAccessCollection, RowContent: View>(
        _ data: Data,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {}
    init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, ID, RowContent> {}
    init<Data: RandomAccessCollection, RowContent: View>(
        _ data: Data,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) where Content == ForEach<Data, Int, RowContent>, Data.Element: Hashable {}
}

public struct Section<Parent: View, Content: View, Footer: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent, @ViewBuilder footer: () -> Footer) {}
}

public extension Section where Parent == EmptyView, Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {}
}

public extension Section where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {}
}

public extension Section where Parent == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {}
}

// Titre passé directement : `Section("Nom") { … }`, forme la plus courante.
public extension Section where Parent == Text, Footer == EmptyView {
    init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
}

public extension Section where Parent == Text, Footer == Text {
    init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Text) {}
}

public struct Form<Content: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder content: () -> Content) {}
}

public struct DisclosureGroup<Label: View, Content: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    public nonisolated init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
}

public struct OutlineGroup<Data: RandomAccessCollection, ID: Hashable, Parent: View, Leaf: View>: _ShimLeaf {
    public nonisolated init(_ data: Data, id: KeyPath<Data.Element, ID>, children: KeyPath<Data.Element, Data?>, @ViewBuilder content: @escaping (Data.Element) -> Leaf) {}
}

public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    public nonisolated init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) where Data.Element: Identifiable, ID == Data.Element.ID {}
    public nonisolated init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
    public var body: _ShimView { _ShimView() }
}

public extension ForEach where Data == Range<Int>, ID == Int {
    init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {}
}

// MARK: - Navigation

public struct NavigationStack<Data, Root: View>: _ShimLeaf {
    public nonisolated init(path: Binding<Data>, @ViewBuilder root: () -> Root) {}
}

public extension NavigationStack where Data == AnyHashable {
    init(@ViewBuilder root: () -> Root) {}
}

public struct NavigationLink<Label: View, Destination: View>: _ShimLeaf {
    public nonisolated init(destination: Destination, @ViewBuilder label: () -> Label) {}
    public nonisolated init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {}
}

public extension NavigationLink where Label == Text {
    init(_ titleKey: LocalizedStringKey, destination: Destination) {}
    init<S: StringProtocol>(_ title: S, destination: Destination) {}
}

public struct NavigationView<Content: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder content: () -> Content) {}
}

public enum NavigationBarItemTitleDisplayMode: Hashable, Sendable {
    case automatic, inline, large
}

public enum NavigationBarItem: Sendable {
    public enum TitleDisplayMode: Hashable, Sendable { case automatic, inline, large }
}

// MARK: - Contrôles

public struct Button<Label: View>: _ShimLeaf {
    public nonisolated init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {}
    public nonisolated init(role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {}
}

public extension Button where Label == Text {
    init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {}
    init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {}
    init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping () -> Void) {}
    init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping () -> Void) {}
}

public struct ButtonRole: Hashable, Sendable {
    public static let destructive = ButtonRole()
    public static let cancel = ButtonRole()
}

public struct Link<Label: View>: _ShimLeaf {
    public nonisolated init(destination: URL, @ViewBuilder label: () -> Label) {}
}

public extension Link where Label == Text {
    init(_ titleKey: LocalizedStringKey, destination: URL) {}
    init<S: StringProtocol>(_ title: S, destination: URL) {}
}

public struct Label<LabelIcon: View, LabelTitle: View>: _ShimLeaf {
    public typealias Icon = LabelIcon
    public typealias Title = LabelTitle
    public nonisolated init(@ViewBuilder title: () -> LabelTitle, @ViewBuilder icon: () -> LabelIcon) {}
    public nonisolated init(@ViewBuilder label: () -> LabelTitle, @ViewBuilder icon: () -> LabelIcon) {}
}

public extension Label where LabelTitle == Text, LabelIcon == Image {
    init(_ titleKey: LocalizedStringKey, systemImage name: String) {}
    init<S: StringProtocol>(_ title: S, systemImage name: String) {}
    init(_ titleKey: LocalizedStringKey, image name: String) {}
    init<S: StringProtocol>(_ title: S, image name: String) {}
}

public struct Menu<Label: View, Content: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    public nonisolated init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, primaryAction: @escaping () -> Void) {}
}

public extension Menu where Label == EmptyView {
    init(@ViewBuilder content: () -> Content) {}
}

public extension Menu where Label == Text {
    init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
}

public struct Toggle<Label: View>: _ShimLeaf {
    public nonisolated init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {}
}

public extension Toggle where Label == Text {
    init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) {}
    init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {}
}

public struct Slider<Label: View, ValueLabel: View>: _ShimLeaf {
    public init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        in bounds: ClosedRange<V>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        minimumValueLabel: ValueLabel,
        maximumValueLabel: ValueLabel,
        @ViewBuilder label: () -> Label
    ) {}
}

public extension Slider where Label == EmptyView, ValueLabel == EmptyView {
    init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        in bounds: ClosedRange<V> = 0 ... 1,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {}
    init<V: BinaryFloatingPoint>(
        value: Binding<V>,
        in bounds: ClosedRange<V> = 0 ... 1,
        step: V.Stride = 1,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {}
}

public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: _ShimLeaf {
    public nonisolated init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    public nonisolated init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, onHover: ((Bool) -> Void)?) {}
}

public extension Picker where Label == Text {
    init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
    init<S: StringProtocol>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
}

public struct DatePicker<Label: View>: _ShimLeaf {
    public nonisolated init(selection: Binding<Date>, displayedComponents: DatePickerComponents = [.date, .hourAndMinute], @ViewBuilder label: () -> Label) {}
    public nonisolated init(selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents = [.date, .hourAndMinute], @ViewBuilder label: () -> Label) {}
}

public extension DatePicker where Label == Text {
    init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: DatePickerComponents = [.date, .hourAndMinute]) {}
    init<S: StringProtocol>(_ title: S, selection: Binding<Date>, displayedComponents: DatePickerComponents = [.date, .hourAndMinute]) {}
}

public struct DatePickerComponents: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let date = DatePickerComponents(rawValue: 1 << 0)
    public static let hourAndMinute = DatePickerComponents(rawValue: 1 << 1)
}

public struct TextField<Label: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder label: () -> Label, text: Binding<String>) {}
    public nonisolated init(@ViewBuilder label: () -> Label, text: Binding<String>, prompt: Text?) {}
}

public extension TextField where Label == Text {
    init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
    init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
    init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
    init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text?) {}
    // Variantes `axis:` — iOS 16, utilisées pour les champs multilignes.
    init(_ titleKey: LocalizedStringKey, text: Binding<String>, axis: Axis) {}
    init<S: StringProtocol>(_ title: S, text: Binding<String>, axis: Axis) {}
    init(_ titleKey: LocalizedStringKey, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void, onCommit: @escaping () -> Void) {}
    init<S: StringProtocol>(_ title: S, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void, onCommit: @escaping () -> Void) {}
    init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter) {}
    init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter, onEditingChanged: @escaping (Bool) -> Void, onCommit: @escaping () -> Void) {}
}

public struct SecureField<Label: View>: _ShimLeaf {
    public nonisolated init(@ViewBuilder label: () -> Label, text: Binding<String>) {}
}

public extension SecureField where Label == Text {
    init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
    init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
    init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
}

public struct TextEditor: _ShimLeaf {
    public nonisolated init(text: Binding<String>) {}
}

public struct ProgressView<Label: View, CurrentValueLabel: View>: _ShimLeaf {
    public nonisolated init(value: Double?, total: Double = 1) {}
    public nonisolated init(value: Double?, total: Double = 1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {}
}

public extension ProgressView where Label == EmptyView, CurrentValueLabel == EmptyView {
    init() {}
}

public extension ProgressView where Label == Text, CurrentValueLabel == EmptyView {
    init(_ titleKey: LocalizedStringKey) {}
    init<S: StringProtocol>(_ title: S) {}
    init(_ titleKey: LocalizedStringKey, value: Double?, total: Double = 1) {}
    init<S: StringProtocol>(_ title: S, value: Double?, total: Double = 1) {}
}

public struct Stepper<Label: View>: _ShimLeaf {
    public nonisolated init(onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }, @ViewBuilder label: () -> Label) {}
}

public struct ColorPicker<Label: View>: _ShimLeaf {
    public nonisolated init(selection: Binding<Color>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {}
}

public struct Gauge<Label: View, CurrentValueLabel: View>: _ShimLeaf {
    public nonisolated init(value: Binding<Double>, in bounds: ClosedRange<Double>, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {}
}

public struct ShareLink<Data: RandomAccessCollection, Preview: View, Label: View>: _ShimLeaf {
    public nonisolated init(items: Data, @ViewBuilder label: () -> Label) {}
}

public struct Canvas<Symbols, Renderer>: _ShimLeaf {
    public nonisolated init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false, renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {}
}

public struct GraphicsContext {
    public struct Shading { public static let color = Shading() }
    public var fillStyle: FillStyle
    public var strokeStyle: StrokeStyle
    public func fill(_ path: Path, with shading: Shading, style: FillStyle = FillStyle()) {}
    public func stroke(_ path: Path, with shading: Shading, lineWidth: CGFloat = 1) {}
    public func stroke(_ path: Path, with shading: Shading, style: StrokeStyle) {}
    public func clip(to path: Path) {}
}

public enum ColorRenderingMode: Hashable, Sendable { case nonLinear, linear, extendedLinear }

// MARK: - TabView

public struct TabView<SelectionValue: Hashable, Content: View>: _ShimLeaf {
    public nonisolated init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {}
}

public extension TabView where SelectionValue == Int {
    init(@ViewBuilder content: () -> Content) {}
}

// MARK: - Images asynchrones

public enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
    public var image: Image? {
        if case .success(let image) = self { return image }
        return nil
    }
    public var error: Error? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

public struct AsyncImage<Content: View>: _ShimLeaf {
    public nonisolated init(url: URL?, scale: CGFloat = 1) where Content == Image {}
    public init<I: View, P: View>(url: URL?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P) where Content == _ShimConditional<I, P> {}
    public nonisolated init(url: URL?, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {}
}

// MARK: - Scènes

public struct WindowGroup<Content: View>: Scene {
    public nonisolated init(@ViewBuilder content: () -> Content) {}
    public var body: _ShimScene { _ShimScene() }
}

public struct Settings<Content: View>: Scene {
    public nonisolated init(@ViewBuilder content: () -> Content) {}
    public var body: _ShimScene { _ShimScene() }
}

public struct CommandMenu<Content: View>: Scene {
    public nonisolated init(_ nameKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ name: S, @ViewBuilder content: () -> Content) {}
    public var body: _ShimScene { _ShimScene() }
}

public struct CommandGroup<Content: View>: Scene {
    public nonisolated init(after: CommandGroupPlacement = .standard, @ViewBuilder content: () -> Content) {}
    public nonisolated init(before: CommandGroupPlacement = .standard, @ViewBuilder content: () -> Content) {}
    public nonisolated init(replacing: CommandGroupPlacement, @ViewBuilder content: () -> Content) {}
    public var body: _ShimScene { _ShimScene() }
}

public struct CommandGroupPlacement: Hashable, Sendable {
    public static let standard = CommandGroupPlacement()
    public static let appInfo = CommandGroupPlacement()
    public static let appSettings = CommandGroupPlacement()
    public static let newItem = CommandGroupPlacement()
    public static let saveItem = CommandGroupPlacement()
    public static let importExport = CommandGroupPlacement()
    public static let printItem = CommandGroupPlacement()
    public static let undoRedo = CommandGroupPlacement()
    public static let pasteboard = CommandGroupPlacement()
    public static let textEditing = CommandGroupPlacement()
    public static let textFormatting = CommandGroupPlacement()
    public static let toolbar = CommandGroupPlacement()
    public static let sidebar = CommandGroupPlacement()
    public static let windowSize = CommandGroupPlacement()
    public static let windowArrangement = CommandGroupPlacement()
    public static let help = CommandGroupPlacement()
}

public struct Commands: Scene {
    public var body: _ShimScene { _ShimScene() }
}

// MARK: - Horloge de vue

/// Ordonnanceur de `TimelineView` (`TimelineSchedule`).
public protocol TimelineSchedule {}

public struct PeriodicTimelineSchedule: TimelineSchedule {
    public nonisolated init() {}
}

public struct AnimationTimelineSchedule: TimelineSchedule {
    public nonisolated init() {}
}

public extension TimelineSchedule where Self == PeriodicTimelineSchedule {
    static func periodic(from startDate: Date, by interval: TimeInterval) -> PeriodicTimelineSchedule {
        PeriodicTimelineSchedule()
    }
}

public extension TimelineSchedule where Self == AnimationTimelineSchedule {
    static var animation: AnimationTimelineSchedule { AnimationTimelineSchedule() }
    static func animation(minimumInterval: Double? = nil, paused: Bool = false) -> AnimationTimelineSchedule {
        AnimationTimelineSchedule()
    }
}

/// Vue redessinée selon un ordonnanceur — utilisée pour les animations.
///
/// `Schedule` est un paramètre générique du TYPE, comme dans le SDK : c'est ce
/// qui permet à `.periodic(…)` de se résoudre (l'ordonnanceur est déduit de
/// l'argument). Placé sur l'`init`, il laissait `Content` non inférable.
/// Contexte passé à la fermeture de `TimelineView`.
///
/// Déclaré à part et non imbriqué : imbriqué dans `TimelineView<Schedule,
/// Content>`, son type dépendrait de `Content`, lui-même déduit de la fermeture
/// dont il est le paramètre — inférence circulaire, `Content` non inférable.
public struct _ShimTimelineContext {
    public enum Cadence: Hashable, Sendable { case live, seconds, minutes }
    public var date: Date
    public var cadence: Cadence
    public var isPaused: Bool
}

public struct TimelineView<Schedule: TimelineSchedule, Content: View>: _ShimLeaf {
    public nonisolated init(
        _ schedule: Schedule,
        @ViewBuilder content: @escaping (_ShimTimelineContext) -> Content
    ) {}
}

// MARK: - Attributs SwiftUI d'AttributedString

/// Attributs SwiftUI d'un `AttributedString` (`run.foregroundColor = …`,
/// `run.underlineStyle = …`) : ils vivent dans `AttributeScopes.SwiftUIAttributes`.
extension AttributeScopes {
    public struct SwiftUIAttributes: AttributeScope {
        public struct ForegroundColorAttribute: AttributedStringKey {
            public typealias Value = Color
            public static let name = "foregroundColor"
        }

        public struct BackgroundColorAttribute: AttributedStringKey {
            public typealias Value = Color
            public static let name = "backgroundColor"
        }

        public struct UnderlineStyleAttribute: AttributedStringKey {
            public typealias Value = Text.LineStyle
            public static let name = "underlineStyle"
        }

        public struct StrikethroughStyleAttribute: AttributedStringKey {
            public typealias Value = Text.LineStyle
            public static let name = "strikethroughStyle"
        }

        public struct FontAttribute: AttributedStringKey {
            public typealias Value = Font
            public static let name = "font"
        }

        public let foregroundColor = ForegroundColorAttribute()
        public let backgroundColor = BackgroundColorAttribute()
        public let underlineStyle = UnderlineStyleAttribute()
        public let strikethroughStyle = StrikethroughStyleAttribute()
        public let font = FontAttribute()
    }

    public var swiftUI: SwiftUIAttributes { SwiftUIAttributes() }
}
