// Shim SwiftUI — surface `extension View`. NE FAIT PAS PARTIE DE L'APP.
//
// Tous les modificateurs renvoient `some View` : le chaînage fonctionne, mais
// aucun rendu n'est simulé. Les signatures recopiées sont celles du vrai
// SwiftUI (iOS 16).

import Foundation
import PhotosUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Publishers (réduit : Timer.publish → onReceive)

public protocol Publisher {
    associatedtype Output
    associatedtype Failure: Error
}

public struct _ShimTimerPublisher: Publisher {
    public typealias Output = Date
    public typealias Failure = Never
    public func autoconnect() -> _ShimTimerPublisher { self }
    public func connect() -> _ShimTimerPublisher { self }
}

extension Timer {
    public static func publish(
        every interval: TimeInterval,
        on runLoop: RunLoop,
        in mode: RunLoop.Mode,
        options: Int? = nil
    ) -> _ShimTimerPublisher {
        _ShimTimerPublisher()
    }
}

// MARK: - Types annexes

public enum TextInputAutocapitalization: Hashable, Sendable {
    case never, words, sentences, characters, automatic
}

public enum SubmitLabel: Hashable, Sendable {
    case done, go, send, join, route, search, `return`, next, `continue`
}

public struct SubmitTriggers: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let text = SubmitTriggers(rawValue: 1 << 0)
    public static let search = SubmitTriggers(rawValue: 1 << 1)
}

public enum TruncationMode: Hashable, Sendable { case head, middle, tail }

public enum ImageScale: Hashable, Sendable { case small, medium, large }

public struct RedactionReasons: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let placeholder = RedactionReasons(rawValue: 1 << 0)
    public static let privacy = RedactionReasons(rawValue: 1 << 1)
    public static let invalid = RedactionReasons(rawValue: 1 << 2)
}

public struct ContentShapeKinds: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let interaction = ContentShapeKinds(rawValue: 1 << 0)
    public static let dragPreview = ContentShapeKinds(rawValue: 1 << 1)
    public static let contextMenuPreview = ContentShapeKinds(rawValue: 1 << 2)
}

public struct AccessibilityChildBehavior: Hashable, Sendable {
    public static let ignore = AccessibilityChildBehavior()
    public static let contain = AccessibilityChildBehavior()
    public static let combine = AccessibilityChildBehavior()
}

public struct AccessibilityTraits: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let isButton = AccessibilityTraits(rawValue: 1 << 0)
    public static let isHeader = AccessibilityTraits(rawValue: 1 << 1)
    public static let isSelected = AccessibilityTraits(rawValue: 1 << 2)
    public static let isLink = AccessibilityTraits(rawValue: 1 << 3)
    public static let isSearchField = AccessibilityTraits(rawValue: 1 << 4)
    public static let isImage = AccessibilityTraits(rawValue: 1 << 5)
    public static let playsSound = AccessibilityTraits(rawValue: 1 << 6)
    public static let isKeyboardKey = AccessibilityTraits(rawValue: 1 << 7)
    public static let isStaticText = AccessibilityTraits(rawValue: 1 << 8)
    public static let isSummaryElement = AccessibilityTraits(rawValue: 1 << 9)
    public static let updatesFrequently = AccessibilityTraits(rawValue: 1 << 10)
    public static let startsMediaSession = AccessibilityTraits(rawValue: 1 << 11)
    public static let allowsDirectInteraction = AccessibilityTraits(rawValue: 1 << 12)
    public static let causesPageTurn = AccessibilityTraits(rawValue: 1 << 13)
    public static let isModal = AccessibilityTraits(rawValue: 1 << 14)
    public static let isToggle = AccessibilityTraits(rawValue: 1 << 15)
    public static let isTabBar = AccessibilityTraits(rawValue: 1 << 16)
}

public struct AccessibilityActionKind: Hashable, Sendable {
    public static let `default` = AccessibilityActionKind()
    public static let escape = AccessibilityActionKind()
    public static func named(_ name: Text) -> AccessibilityActionKind { AccessibilityActionKind() }
}

public enum BlendMode: Hashable, Sendable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn
    case softLight, hardLight, difference, exclusion, hue, saturation, color, luminosity
    case sourceAtop, destinationOver, plusDarker, plusLighter
    case clear, copy, sourceIn, sourceOut, destinationIn, destinationOut
}

public enum MenuOrder: Hashable, Sendable { case automatic, fixed, priority }

public enum ControlSize: Hashable, Sendable { case mini, small, regular, large, extraLarge }

public enum ButtonBorderShape: Hashable, Sendable {
    case automatic, capsule, roundedRectangle, circle
}

public enum DynamicRange: Hashable, Sendable { case standard, constrainedHigh, high }

public enum ColorMatrix: Hashable, Sendable { case identity, grayscale, luminosityToAlpha }

public struct PresentationDetent: Hashable, Sendable {
    public static let medium = PresentationDetent()
    public static let large = PresentationDetent()
    public static func fraction(_ fraction: CGFloat) -> PresentationDetent { PresentationDetent() }
    public static func height(_ height: CGFloat) -> PresentationDetent { PresentationDetent() }
}

public enum PresentationDragIndicatorVisibility: Hashable, Sendable {
    case automatic, visible, hidden
}

public enum Prominence: Hashable, Sendable { case standard, increased }

public enum ImageInterpolation: Hashable, Sendable { case none, low, medium, high }

public enum HoverEffect: Hashable, Sendable { case automatic, highlight, lift }

// MARK: - Styles (protocoles)

public struct ButtonStyleConfiguration {
    public struct Label: View {
        public var body: _ShimView { _ShimView() }
    }
    public let label: ButtonStyleConfiguration.Label
    public let isPressed: Bool
}

public protocol ButtonStyle {
    associatedtype Body: View
    typealias Configuration = ButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}

public struct PlainButtonStyle: ButtonStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ButtonStyleConfiguration) -> some View { _ShimView() }
}

public struct DefaultButtonStyle: ButtonStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ButtonStyleConfiguration) -> some View { _ShimView() }
}

public struct BorderlessButtonStyle: ButtonStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ButtonStyleConfiguration) -> some View { _ShimView() }
}

public struct BorderedButtonStyle: ButtonStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ButtonStyleConfiguration) -> some View { _ShimView() }
}

public struct BorderedProminentButtonStyle: ButtonStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ButtonStyleConfiguration) -> some View { _ShimView() }
}

public struct LinkButtonStyle: ButtonStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ButtonStyleConfiguration) -> some View { _ShimView() }
}

public extension ButtonStyle where Self == PlainButtonStyle {
    static var plain: PlainButtonStyle { PlainButtonStyle() }
}
public extension ButtonStyle where Self == DefaultButtonStyle {
    static var automatic: DefaultButtonStyle { DefaultButtonStyle() }
}
public extension ButtonStyle where Self == BorderlessButtonStyle {
    static var borderless: BorderlessButtonStyle { BorderlessButtonStyle() }
}
public extension ButtonStyle where Self == BorderedButtonStyle {
    static var bordered: BorderedButtonStyle { BorderedButtonStyle() }
}
public extension ButtonStyle where Self == BorderedProminentButtonStyle {
    static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() }
}
public extension ButtonStyle where Self == LinkButtonStyle {
    static var link: LinkButtonStyle { LinkButtonStyle() }
}

public struct PrimitiveButtonStyleConfiguration {
    public struct Label: View {
        public var body: _ShimView { _ShimView() }
    }
    public let label: PrimitiveButtonStyleConfiguration.Label
    public func trigger() {}
}

public protocol PrimitiveButtonStyle {
    associatedtype Body: View
    typealias Configuration = PrimitiveButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}


public protocol LabelStyle {
    associatedtype Body: View
    typealias Configuration = LabelStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}

public struct LabelStyleConfiguration {
    public struct Title: View {
        public var body: _ShimView { _ShimView() }
    }
    public struct Icon: View {
        public var body: _ShimView { _ShimView() }
    }
    public var title: LabelStyleConfiguration.Title { Title() }
    public var icon: LabelStyleConfiguration.Icon { Icon() }
}

public struct DefaultLabelStyle: LabelStyle {
    public nonisolated init() {}
    public func makeBody(configuration: LabelStyleConfiguration) -> some View { _ShimView() }
}
public struct IconOnlyLabelStyle: LabelStyle {
    public nonisolated init() {}
    public func makeBody(configuration: LabelStyleConfiguration) -> some View { _ShimView() }
}
public struct TitleOnlyLabelStyle: LabelStyle {
    public nonisolated init() {}
    public func makeBody(configuration: LabelStyleConfiguration) -> some View { _ShimView() }
}
public extension LabelStyle where Self == DefaultLabelStyle {
    static var automatic: DefaultLabelStyle { DefaultLabelStyle() }
}
public extension LabelStyle where Self == IconOnlyLabelStyle {
    static var iconOnly: IconOnlyLabelStyle { IconOnlyLabelStyle() }
}
public extension LabelStyle where Self == TitleOnlyLabelStyle {
    static var titleOnly: TitleOnlyLabelStyle { TitleOnlyLabelStyle() }
}

public struct ToggleStyleConfiguration {
    public var isOn: Binding<Bool>
    public struct Label: View {
        public var body: _ShimView { _ShimView() }
    }
    public var label: Label { Label() }
}

public protocol ToggleStyle {
    associatedtype Body: View
    typealias Configuration = ToggleStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}

public struct SwitchToggleStyle: ToggleStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ToggleStyleConfiguration) -> some View { _ShimView() }
}
public struct ButtonToggleStyle: ToggleStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ToggleStyleConfiguration) -> some View { _ShimView() }
}
public struct CheckboxToggleStyle: ToggleStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ToggleStyleConfiguration) -> some View { _ShimView() }
}
public extension ToggleStyle where Self == SwitchToggleStyle {
    static var automatic: SwitchToggleStyle { SwitchToggleStyle() }
    static var `switch`: SwitchToggleStyle { SwitchToggleStyle() }
}
public extension ToggleStyle where Self == ButtonToggleStyle {
    static var button: ButtonToggleStyle { ButtonToggleStyle() }
}
public extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}

public protocol TextFieldStyle {}

public struct DefaultTextFieldStyle: TextFieldStyle { public nonisolated init() {} }
public struct PlainTextFieldStyle: TextFieldStyle { public nonisolated init() {} }
public struct RoundedBorderTextFieldStyle: TextFieldStyle { public nonisolated init() {} }
public struct SquareBorderTextFieldStyle: TextFieldStyle { public nonisolated init() {} }
public extension TextFieldStyle where Self == DefaultTextFieldStyle {
    static var automatic: DefaultTextFieldStyle { DefaultTextFieldStyle() }
}
public extension TextFieldStyle where Self == PlainTextFieldStyle {
    static var plain: PlainTextFieldStyle { PlainTextFieldStyle() }
}
public extension TextFieldStyle where Self == RoundedBorderTextFieldStyle {
    static var roundedBorder: RoundedBorderTextFieldStyle { RoundedBorderTextFieldStyle() }
}
public extension TextFieldStyle where Self == SquareBorderTextFieldStyle {
    static var squareBorder: SquareBorderTextFieldStyle { SquareBorderTextFieldStyle() }
}

public protocol ProgressViewStyle {
    associatedtype Body: View
    typealias Configuration = ProgressViewStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}

public struct ProgressViewStyleConfiguration {
    public struct Label: View {
        public var body: _ShimView { _ShimView() }
    }
    public var label: Label? { nil }
    public var fractionCompleted: Double? { nil }
    public var currentValueLabel: Label? { nil }
}

public struct LinearProgressViewStyle: ProgressViewStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View { _ShimView() }
}
public struct CircularProgressViewStyle: ProgressViewStyle {
    public nonisolated init() {}
    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View { _ShimView() }
}
public extension ProgressViewStyle where Self == LinearProgressViewStyle {
    static var linear: LinearProgressViewStyle { LinearProgressViewStyle() }
    static var automatic: LinearProgressViewStyle { LinearProgressViewStyle() }
}
public extension ProgressViewStyle where Self == CircularProgressViewStyle {
    static var circular: CircularProgressViewStyle { CircularProgressViewStyle() }
}

public protocol PickerStyle {}

public struct DefaultPickerStyle: PickerStyle { public nonisolated init() {} }
public struct SegmentedPickerStyle: PickerStyle { public nonisolated init() {} }
public struct WheelPickerStyle: PickerStyle { public nonisolated init() {} }
public struct MenuPickerStyle: PickerStyle { public nonisolated init() {} }
public struct InlinePickerStyle: PickerStyle { public nonisolated init() {} }
public struct NavigationLinkPickerStyle: PickerStyle { public nonisolated init() {} }
public extension PickerStyle where Self == DefaultPickerStyle {
    static var automatic: DefaultPickerStyle { DefaultPickerStyle() }
}
public extension PickerStyle where Self == SegmentedPickerStyle {
    static var segmented: SegmentedPickerStyle { SegmentedPickerStyle() }
}
public extension PickerStyle where Self == WheelPickerStyle {
    static var wheel: WheelPickerStyle { WheelPickerStyle() }
}
public extension PickerStyle where Self == MenuPickerStyle {
    static var menu: MenuPickerStyle { MenuPickerStyle() }
}
public extension PickerStyle where Self == InlinePickerStyle {
    static var inline: InlinePickerStyle { InlinePickerStyle() }
}
public extension PickerStyle where Self == NavigationLinkPickerStyle {
    static var navigationLink: NavigationLinkPickerStyle { NavigationLinkPickerStyle() }
}

public protocol ListStyle {}

public struct DefaultListStyle: ListStyle { public nonisolated init() {} }
public struct PlainListStyle: ListStyle { public nonisolated init() {} }
public struct InsetListStyle: ListStyle { public nonisolated init() {} }
public struct InsetGroupedListStyle: ListStyle { public nonisolated init() {} }
public struct GroupedListStyle: ListStyle { public nonisolated init() {} }
public struct SidebarListStyle: ListStyle { public nonisolated init() {} }
public struct BorderedListStyle: ListStyle { public nonisolated init() {} }
public struct EllipticalListStyle: ListStyle { public nonisolated init() {} }
public extension ListStyle where Self == DefaultListStyle {
    static var automatic: DefaultListStyle { DefaultListStyle() }
}
public extension ListStyle where Self == PlainListStyle {
    static var plain: PlainListStyle { PlainListStyle() }
}
public extension ListStyle where Self == InsetListStyle {
    static var inset: InsetListStyle { InsetListStyle() }
}
public extension ListStyle where Self == InsetGroupedListStyle {
    static var insetGrouped: InsetGroupedListStyle { InsetGroupedListStyle() }
}
public extension ListStyle where Self == GroupedListStyle {
    static var grouped: GroupedListStyle { GroupedListStyle() }
}
public extension ListStyle where Self == SidebarListStyle {
    static var sidebar: SidebarListStyle { SidebarListStyle() }
}
public extension ListStyle where Self == BorderedListStyle {
    static var bordered: BorderedListStyle { BorderedListStyle() }
}

public protocol TabViewStyle {}

public struct DefaultTabViewStyle: TabViewStyle { public nonisolated init() {} }
public struct PageTabViewStyle: TabViewStyle { public nonisolated init() {} }
public struct AutomaticTabViewStyle: TabViewStyle { public nonisolated init() {} }
public extension TabViewStyle where Self == PageTabViewStyle {
    static var page: PageTabViewStyle { PageTabViewStyle() }
    static func page(indexDisplayMode: PageTabViewStyle.IndexDisplayMode) -> PageTabViewStyle { PageTabViewStyle() }
}
public extension PageTabViewStyle {
    enum IndexDisplayMode: Hashable, Sendable { case always, automatic, never }
}
public extension TabViewStyle where Self == DefaultTabViewStyle {
    static var automatic: DefaultTabViewStyle { DefaultTabViewStyle() }
}

public protocol DatePickerStyle {}

public struct DefaultDatePickerStyle: DatePickerStyle { public nonisolated init() {} }
public struct CompactDatePickerStyle: DatePickerStyle { public nonisolated init() {} }
public struct GraphicalDatePickerStyle: DatePickerStyle { public nonisolated init() {} }
public struct WheelDatePickerStyle: DatePickerStyle { public nonisolated init() {} }
public struct FieldDatePickerStyle: DatePickerStyle { public nonisolated init() {} }
public struct StepperFieldDatePickerStyle: DatePickerStyle { public nonisolated init() {} }
public extension DatePickerStyle where Self == DefaultDatePickerStyle {
    static var automatic: DefaultDatePickerStyle { DefaultDatePickerStyle() }
}
public extension DatePickerStyle where Self == CompactDatePickerStyle {
    static var compact: CompactDatePickerStyle { CompactDatePickerStyle() }
}
public extension DatePickerStyle where Self == GraphicalDatePickerStyle {
    static var graphical: GraphicalDatePickerStyle { GraphicalDatePickerStyle() }
}
public extension DatePickerStyle where Self == WheelDatePickerStyle {
    static var wheel: WheelDatePickerStyle { WheelDatePickerStyle() }
}

public protocol MenuStyle {}

public struct DefaultMenuStyle: MenuStyle { public nonisolated init() {} }
public struct BorderlessButtonMenuStyle: MenuStyle { public nonisolated init() {} }
public struct ButtonMenuStyle: MenuStyle { public nonisolated init() {} }
public extension MenuStyle where Self == DefaultMenuStyle {
    static var automatic: DefaultMenuStyle { DefaultMenuStyle() }
}
public extension MenuStyle where Self == BorderlessButtonMenuStyle {
    static var borderlessButton: BorderlessButtonMenuStyle { BorderlessButtonMenuStyle() }
}
public extension MenuStyle where Self == ButtonMenuStyle {
    static var button: ButtonMenuStyle { ButtonMenuStyle() }
}

public protocol GroupBoxStyle {
    associatedtype Body: View
    typealias Configuration = GroupBoxStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}

public struct GroupBoxStyleConfiguration {
    public struct Label: View {
        public var body: _ShimView { _ShimView() }
    }
    public struct Content: View {
        public var body: _ShimView { _ShimView() }
    }
    public var label: Label { Label() }
    public var content: Content { Content() }
}

public struct DefaultGroupBoxStyle: GroupBoxStyle {
    public nonisolated init() {}
    public func makeBody(configuration: GroupBoxStyleConfiguration) -> some View { _ShimView() }
}

public protocol GaugeStyle {
    associatedtype Body: View
    typealias Configuration = GaugeStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}

public struct GaugeStyleConfiguration {
    public var value: Double { 0 }
}

// MARK: - Modificateurs génériques

public extension View {
    func modifier<Modifier: ViewModifier>(_ modifier: Modifier) -> some View { _ShimView() }
}

// MARK: - Espacement / cadre / découpe

public extension View {
    func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { _ShimView() }
    func padding(_ length: CGFloat) -> some View { _ShimView() }
    func padding(_ insets: EdgeInsets) -> some View { _ShimView() }
    func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View { _ShimView() }
    func frame(
        minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View { _ShimView() }
    func frame(minWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> some View { _ShimView() }
    func fixedSize() -> some View { _ShimView() }
    func fixedSize(horizontal: Bool, vertical: Bool) -> some View { _ShimView() }
    func layoutPriority(_ value: Double) -> some View { _ShimView() }
    func zIndex(_ value: Double) -> some View { _ShimView() }
    func id<ID: Hashable>(_ id: ID) -> some View { _ShimView() }
    func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> some View { _ShimView() }
    func clipped(antialiased: Bool = false) -> some View { _ShimView() }
    func cornerRadius(_ radius: CGFloat, antialiased: Bool = true) -> some View { _ShimView() }
    func mask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View { _ShimView() }
    func mask<Mask: View>(_ mask: Mask) -> some View { _ShimView() }
    func contentShape<S: Shape>(_ shape: S, eoFill: Bool = false) -> some View { _ShimView() }
    func contentShape<S: Shape>(_ kind: ContentShapeKinds, _ shape: S, eoFill: Bool = false) -> some View { _ShimView() }
    func contentShape(_ kind: ContentShapeKinds) -> some View { _ShimView() }
}


// MARK: - Fond / superposition / bordure

public extension View {
    // Surcharge concrète : `Color` est à la fois `View` et `ShapeStyle`, sans
    // elle l'appel `.background(Theme.surface)` est ambigu (deux candidats
    // génériques). Le vrai SwiftUI n'a que la version ShapeStyle.
    func background(_ style: Color, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { _ShimView() }
    func background<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { _ShimView() }
    func background<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View { _ShimView() }
    func background<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { _ShimView() }
    // `@_disfavoredOverload` : `LinearGradient` est à la fois `View` et
    // `ShapeStyle`, donc les deux surcharges génériques s'appliquent. C'est
    // l'attribut que SwiftUI emploie pour départager ces cas.
    @available(*, deprecated, message: "shim SwiftUI : préférer la surcharge ShapeStyle")
    @_disfavoredOverload
    func background<V: View>(_ background: V, alignment: Alignment = .center) -> some View { _ShimView() }

    func overlay<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View { _ShimView() }
    func overlay(_ style: Color, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { _ShimView() }
    func overlay<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { _ShimView() }
    func overlay<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { _ShimView() }
    @available(*, deprecated, message: "shim SwiftUI : préférer la surcharge ShapeStyle")
    func overlay<V: View>(_ overlay: V, alignment: Alignment = .center) -> some View { _ShimView() }

    func border<S: ShapeStyle>(_ content: S, width: CGFloat = 1) -> some View { _ShimView() }
    func foregroundColor(_ color: Color?) -> some View { _ShimView() }
    func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View { _ShimView() }
    func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle>(_ primary: S1, _ secondary: S2) -> some View { _ShimView() }
    func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>(_ primary: S1, _ secondary: S2, _ tertiary: S3) -> some View { _ShimView() }
    func tint(_ tint: Color?) -> some View { _ShimView() }
    func accentColor(_ accentColor: Color?) -> some View { _ShimView() }
    func colorScheme(_ colorScheme: ColorScheme) -> some View { _ShimView() }
    func preferredColorScheme(_ colorScheme: ColorScheme?) -> some View { _ShimView() }
    func opacity(_ opacity: Double) -> some View { _ShimView() }
    func hidden() -> some View { _ShimView() }
    func blur(radius: CGFloat, opaque: Bool = false) -> some View { _ShimView() }
    func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View { _ShimView() }
    func shadow<S: ShapeStyle>(_ style: S, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View { _ShimView() }
    func colorMultiply(_ color: Color) -> some View { _ShimView() }
    func saturation(_ amount: Double) -> some View { _ShimView() }
    func grayscale(_ amount: Double) -> some View { _ShimView() }
    func contrast(_ amount: Double) -> some View { _ShimView() }
    func brightness(_ amount: Double) -> some View { _ShimView() }
    func hueRotation(_ angle: Angle) -> some View { _ShimView() }
    func luminanceToAlpha() -> some View { _ShimView() }
    func colorInvert() -> some View { _ShimView() }
    func blendMode(_ blendMode: BlendMode) -> some View { _ShimView() }
    func drawingGroup(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear) -> some View { _ShimView() }
    func compositingGroup() -> some View { _ShimView() }
}


// MARK: - Transformations

public extension View {
    func scaleEffect(_ scale: CGFloat, anchor: UnitPoint = .center) -> some View { _ShimView() }
    func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some View { _ShimView() }
    func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View { _ShimView() }
    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> some View { _ShimView() }
    func projectionEffect(_ transform: ProjectionTransform) -> some View { _ShimView() }
    func offset(_ offset: CGSize) -> some View { _ShimView() }
    func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View { _ShimView() }
    func position(_ position: CGPoint) -> some View { _ShimView() }
    func position(x: CGFloat = 0, y: CGFloat = 0) -> some View { _ShimView() }
    func aspectRatio(_ aspectRatio: CGFloat? = nil, contentMode: ContentMode) -> some View { _ShimView() }
    func aspectRatio(_ aspectRatio: CGSize, contentMode: ContentMode) -> some View { _ShimView() }
    func scaledToFit() -> some View { _ShimView() }
    func scaledToFill() -> some View { _ShimView() }
    func transformEffect(_ transform: CGAffineTransform) -> some View { _ShimView() }
}

public struct ProjectionTransform: Equatable {
    public nonisolated init() {}
    public static let identity = ProjectionTransform()
}

// MARK: - Animation et transitions

public extension View {
    func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View { _ShimView() }
    func animation(_ animation: Animation?) -> some View { _ShimView() }
    func transition(_ t: AnyTransition) -> some View { _ShimView() }
    func transition<S: Transition>(_ transition: S) -> some View { _ShimView() }
    func matchedGeometryEffect<ID: Hashable>(id: ID, in namespace: Namespace.ID, properties: MatchedGeometryProperties = .position, anchor: UnitPoint = .center, isSource: Bool = true) -> some View { _ShimView() }
}

public struct MatchedGeometryProperties: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let position = MatchedGeometryProperties(rawValue: 1 << 0)
    public static let size = MatchedGeometryProperties(rawValue: 1 << 1)
    public static let frame = MatchedGeometryProperties(rawValue: 1 << 2)
}

public protocol Transition {}

public struct OpacityTransition: Transition { public nonisolated init() {} }
public struct ScaleTransition: Transition { public nonisolated init(scale: Double = 1) {} }
public struct MoveTransition: Transition { public nonisolated init(edge: Edge) {} }
public struct OffsetTransition: Transition { public nonisolated init(offset: CGSize) {} }
public struct SlideTransition: Transition { public nonisolated init() {} }
public struct PushTransition: Transition { public nonisolated init(edge: Edge) {} }
public struct AsymmetricTransition<Insertion: Transition, Removal: Transition>: Transition {
    public nonisolated init(insertion: Insertion, removal: Removal) {}
}
public struct CombinedTransition: Transition { public nonisolated init() {} }

public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try body()
}

// MARK: - Typographie

public extension View {
    func font(_ font: Font?) -> some View { _ShimView() }
    func fontWeight(_ weight: Font.Weight?) -> some View { _ShimView() }
    func fontDesign(_ design: Font.Design?) -> some View { _ShimView() }
    func fontWidth(_ width: Font.Width?) -> some View { _ShimView() }
    func bold() -> some View { _ShimView() }
    func italic() -> some View { _ShimView() }
    func italic(_ isActive: Bool) -> some View { _ShimView() }
    func monospaced() -> some View { _ShimView() }
    func monospacedDigit() -> some View { _ShimView() }
    func kerning(_ kerning: CGFloat) -> some View { _ShimView() }
    func tracking(_ tracking: CGFloat) -> some View { _ShimView() }
    func baselineOffset(_ baselineOffset: CGFloat) -> some View { _ShimView() }
    func underline(_ isActive: Bool = true, pattern: Text.LineStyle? = nil, color: Color? = nil) -> some View { _ShimView() }
    func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle? = nil, color: Color? = nil) -> some View { _ShimView() }
    func textCase(_ textCase: Text.Case?) -> some View { _ShimView() }
    func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> some View { _ShimView() }
    func lineLimit(_ number: Int?) -> some View { _ShimView() }
    func lineLimit(_ limit: PartialRangeFrom<Int>) -> some View { _ShimView() }
    func lineLimit(_ limit: PartialRangeThrough<Int>) -> some View { _ShimView() }
    func lineLimit(_ limit: ClosedRange<Int>) -> some View { _ShimView() }
    func lineSpacing(_ lineSpacing: CGFloat) -> some View { _ShimView() }
    func multilineTextAlignment(_ alignment: TextAlignment) -> some View { _ShimView() }
    func truncationMode(_ mode: TruncationMode) -> some View { _ShimView() }
    func allowsTightening(_ flag: Bool) -> some View { _ShimView() }
    func minimumScaleFactor(_ factor: CGFloat) -> some View { _ShimView() }
    func textSelection<S: TextSelectability>(_ selectability: S) -> some View { _ShimView() }
    func dynamicTypeSize(_ size: DynamicTypeSize) -> some View { _ShimView() }
    func dynamicTypeSize(_ range: ClosedRange<DynamicTypeSize>) -> some View { _ShimView() }
    func textContentType(_ textContentType: UITextContentType?) -> some View { _ShimView() }
    func keyboardType(_ type: UIKeyboardType) -> some View { _ShimView() }
    func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View { _ShimView() }
    func autocorrectionDisabled(_ disable: Bool = true) -> some View { _ShimView() }
    func submitLabel(_ submitLabel: SubmitLabel) -> some View { _ShimView() }
    func labelsHidden() -> some View { _ShimView() }
    func labelStyle<S: LabelStyle>(_ style: S) -> some View { _ShimView() }
    func headerProminence(_ prominence: Prominence) -> some View { _ShimView() }
    func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> some View { _ShimView() }
    func symbolVariant(_ variant: SymbolVariants) -> some View { _ShimView() }
    func imageScale(_ scale: ImageScale) -> some View { _ShimView() }
}

public protocol TextSelectability {}

public struct EnabledTextSelectability: TextSelectability { public nonisolated init() {} }
public struct DisabledTextSelectability: TextSelectability { public nonisolated init() {} }
public extension TextSelectability where Self == EnabledTextSelectability {
    static var enabled: EnabledTextSelectability { EnabledTextSelectability() }
}
public extension TextSelectability where Self == DisabledTextSelectability {
    static var disabled: DisabledTextSelectability { DisabledTextSelectability() }
}

// MARK: - Styles de contrôles

public extension View {
    func buttonStyle<S: ButtonStyle>(_ style: S) -> some View { _ShimView() }
    func buttonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View { _ShimView() }
    func buttonBorderShape(_ shape: ButtonBorderShape) -> some View { _ShimView() }
    func toggleStyle<S: ToggleStyle>(_ style: S) -> some View { _ShimView() }
    func textFieldStyle<S: TextFieldStyle>(_ style: S) -> some View { _ShimView() }
    func pickerStyle<S: PickerStyle>(_ style: S) -> some View { _ShimView() }
    func datePickerStyle<S: DatePickerStyle>(_ style: S) -> some View { _ShimView() }
    func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> some View { _ShimView() }
    func listStyle<S: ListStyle>(_ style: S) -> some View { _ShimView() }
    func menuStyle<S: MenuStyle>(_ style: S) -> some View { _ShimView() }
    func tabViewStyle<S: TabViewStyle>(_ style: S) -> some View { _ShimView() }
    func groupBoxStyle<S: GroupBoxStyle>(_ style: S) -> some View { _ShimView() }
    func gaugeStyle<S: GaugeStyle>(_ style: S) -> some View { _ShimView() }
    func controlSize(_ size: ControlSize) -> some View { _ShimView() }
    func menuIndicator(_ visibility: Visibility) -> some View { _ShimView() }
    func menuOrder(_ order: MenuOrder) -> some View { _ShimView() }
    func redacted(reason: RedactionReasons) -> some View { _ShimView() }
    func unredacted() -> some View { _ShimView() }
    func privacySensitive(_ sensitive: Bool = true) -> some View { _ShimView() }
}

// MARK: - Listes

public extension View {
    func listRowInsets(_ insets: EdgeInsets?) -> some View { _ShimView() }
    func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { _ShimView() }
    func listRowBackground<V: View>(_ view: V?) -> some View { _ShimView() }
    func listSectionSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { _ShimView() }
    func listItemTint(_ tint: Color?) -> some View { _ShimView() }
    func swipeActions<T: View>(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> T) -> some View { _ShimView() }
    func badge(_ count: Int) -> some View { _ShimView() }
    func badge<S: StringProtocol>(_ label: S) -> some View { _ShimView() }
    func badge(_ key: LocalizedStringKey) -> some View { _ShimView() }
    func refreshable(action: @escaping @Sendable () async -> Void) -> some View { _ShimView() }
    /// `PhotosUI` : sélecteur de photos SwiftUI (iOS 16).
    func photosPicker<S: RandomAccessCollection>(
        isPresented: Binding<Bool>,
        selection: Binding<S>,
        maxSelectionCount: Int? = nil,
        matching filter: PHPickerFilter? = nil
    ) -> some View { _ShimView() }
    func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], allowsMultipleSelection: Bool = false, onCompletion: @escaping (Result<[URL], Error>) -> Void) -> some View { _ShimView() }
    func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View { _ShimView() }
}

public enum HorizontalEdge: Hashable, Sendable {
    case leading, trailing
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int
        public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
        public static let leading = Set(rawValue: 1 << 0)
        public static let trailing = Set(rawValue: 1 << 1)
        public static let all: Set = [.leading, .trailing]
    }
}

public enum VerticalEdge: Hashable, Sendable {
    case top, bottom
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int
        public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1 << 0)
        public static let bottom = Set(rawValue: 1 << 1)
        public static let all: Set = [.top, .bottom]
    }
}

// MARK: - Défilement

public extension View {
    func scrollContentBackground(_ visibility: Visibility) -> some View { _ShimView() }
    func scrollDismissesKeyboard(_ mode: ScrollDismissesKeyboardMode) -> some View { _ShimView() }
    func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = .all) -> some View { _ShimView() }
    func scrollDisabled(_ disabled: Bool) -> some View { _ShimView() }
}

// MARK: - Zones sûres

public extension View {
    func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View { _ShimView() }
    func edgesIgnoringSafeArea(_ edges: Edge.Set) -> some View { _ShimView() }
    func safeAreaInset<V: View>(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View { _ShimView() }
    func statusBarHidden(_ hidden: Bool = true) -> some View { _ShimView() }
    func persistentSystemOverlays(_ visibility: Visibility) -> some View { _ShimView() }
}

// MARK: - Navigation

public extension View {
    func navigationTitle(_ title: LocalizedStringKey) -> some View { _ShimView() }
    func navigationTitle<S: StringProtocol>(_ title: S) -> some View { _ShimView() }
    func navigationTitle(_ title: Text) -> some View { _ShimView() }
    func navigationBarTitle(_ title: LocalizedStringKey, displayMode: NavigationBarItem.TitleDisplayMode = .automatic) -> some View { _ShimView() }
    func navigationBarTitle<S: StringProtocol>(_ title: S, displayMode: NavigationBarItem.TitleDisplayMode = .automatic) -> some View { _ShimView() }
    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> some View { _ShimView() }
    func navigationBarHidden(_ hidden: Bool) -> some View { _ShimView() }
    func navigationBarBackButtonHidden(_ hidesBackButton: Bool = true) -> some View { _ShimView() }
    func navigationDestination<D: Hashable, C: View>(for data: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View { _ShimView() }
    func navigationDestination<D: Hashable, C: View>(isPresented: Binding<Bool>, @ViewBuilder destination: () -> C) -> some View { _ShimView() }
    func navigationViewStyle<S>(_ style: S) -> some View { _ShimView() }
    func toolbar<Content: ToolbarContent>(@ToolbarContentBuilder content: () -> Content) -> some View { _ShimView() }
    func toolbar(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { _ShimView() }
    func toolbarBackground<S: ShapeStyle>(_ style: S, for bars: ToolbarPlacement...) -> some View { _ShimView() }
    func toolbarRole(_ role: ToolbarRole) -> some View { _ShimView() }
    func tabItem<Item: View>(@ViewBuilder _ label: () -> Item) -> some View { _ShimView() }
    func tag<V: Hashable>(_ tag: V, includeOptional: Bool = true) -> some View { _ShimView() }
    func onOpenURL(perform action: @escaping (URL) -> Void) -> some View { _ShimView() }
}

public enum ToolbarPlacement: Hashable, Sendable {
    case automatic, bottomBar, navigationBar, tabBar
}

public enum ToolbarRole: Hashable, Sendable { case automatic, editor, navigationStack, browser }

// MARK: - Présentations

public extension View {
    func sheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View { _ShimView() }
    func sheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View { _ShimView() }
    func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View { _ShimView() }
    func fullScreenCover<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View { _ShimView() }
    func popover<Content: View>(isPresented: Binding<Bool>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top, @ViewBuilder content: @escaping () -> Content) -> some View { _ShimView() }
    func popover<Item: Identifiable, Content: View>(item: Binding<Item?>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top, @ViewBuilder content: @escaping (Item) -> Content) -> some View { _ShimView() }
    func presentationDetents(_ detents: Set<PresentationDetent>) -> some View { _ShimView() }
    func presentationDetents(_ detents: Set<PresentationDetent>, selection: Binding<PresentationDetent>) -> some View { _ShimView() }
    func presentationDragIndicator(_ visibility: Visibility) -> some View { _ShimView() }
    func presentationBackground<S: ShapeStyle>(_ style: S) -> some View { _ShimView() }
    func presentationCornerRadius(_ radius: CGFloat?) -> some View { _ShimView() }
    func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View { _ShimView() }
    func alert<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A = { EmptyView() }, @ViewBuilder message: @escaping () -> M = { EmptyView() }) -> some View { _ShimView() }
    func alert<A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A = { EmptyView() }, @ViewBuilder message: @escaping () -> M = { EmptyView() }) -> some View { _ShimView() }
    func alert<A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A = { EmptyView() }, @ViewBuilder message: @escaping () -> M = { EmptyView() }) -> some View { _ShimView() }
    func alert<S: StringProtocol, A: View, M: View, T>(_ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: @escaping (T) -> A = { (_: T) in EmptyView() }, @ViewBuilder message: @escaping (T) -> M = { (_: T) in EmptyView() }) -> some View { _ShimView() }
    func alert<A: View, M: View>(isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A = { EmptyView() }, @ViewBuilder message: @escaping () -> M = { EmptyView() }) -> some View { _ShimView() }
    func alert<E: Error, A: View, M: View>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: @escaping (E) -> A = { (_: E) in EmptyView() }, @ViewBuilder message: @escaping (E) -> M = { (_: E) in EmptyView() }) -> some View { _ShimView() }
    func confirmationDialog<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: @escaping () -> A = { EmptyView() }, @ViewBuilder message: @escaping () -> M = { EmptyView() }) -> some View { _ShimView() }
    func confirmationDialog<A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: @escaping () -> A = { EmptyView() }, @ViewBuilder message: @escaping () -> M = { EmptyView() }) -> some View { _ShimView() }
}

public enum PopoverAttachmentAnchor {
    case rect(Anchor<CGRect>)
    case point(UnitPoint)
}

public struct Anchor<Value> {}
public extension Anchor where Value == CGRect {
    static var bounds: Anchor<CGRect> { Anchor() }
}

// MARK: - Environnement / cycle de vie

public extension View {
    func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some View { _ShimView() }
    func environmentObject<T: ObservableObject>(_ object: T) -> some View { _ShimView() }
    func transformEnvironment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, transform: @escaping (inout V) -> Void) -> some View { _ShimView() }
    func onAppear(perform action: (() -> Void)? = nil) -> some View { _ShimView() }
    func onDisappear(perform action: (() -> Void)? = nil) -> some View { _ShimView() }
    func task(priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> some View { _ShimView() }
    func task<ID: Equatable>(id: ID, priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> some View { _ShimView() }
    func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View { _ShimView() }
    func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View { _ShimView() }
    func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> some View { _ShimView() }
    func onPreferenceChange<K: PreferenceKey>(_ key: K.Type, perform action: @escaping (K.Value) -> Void) -> some View { _ShimView() }
    func preference<K: PreferenceKey>(key: K.Type = K.self, value: K.Value) -> some View { _ShimView() }
    func transformPreference<K: PreferenceKey>(_ key: K.Type = K.self, _ callback: @escaping (inout K.Value) -> Void) -> some View { _ShimView() }
    func backgroundPreferenceValue<K: PreferenceKey, V: View>(_ key: K.Type, @ViewBuilder _ transform: @escaping (K.Value) -> V) -> some View { _ShimView() }
    func overlayPreferenceValue<K: PreferenceKey, V: View>(_ key: K.Type, @ViewBuilder _ transform: @escaping (K.Value) -> V) -> some View { _ShimView() }
    func onHover(perform action: @escaping (Bool) -> Void) -> some View { _ShimView() }
    func hoverEffect(_ effect: HoverEffect = .automatic) -> some View { _ShimView() }
}

// MARK: - Interaction

public extension View {
    func disabled(_ disabled: Bool) -> some View { _ShimView() }
    func allowsHitTesting(_ enabled: Bool) -> some View { _ShimView() }
    func focusable(_ isFocusable: Bool = true, onFocusChange: @escaping (Bool) -> Void = { _ in }) -> some View { _ShimView() }
    func focused<Value>(_ binding: FocusState<Value>.Binding, equals value: Value) -> some View where Value: Hashable { _ShimView() }
    func focused(_ binding: FocusState<Bool>.Binding) -> some View { _ShimView() }
    func help(_ textKey: LocalizedStringKey) -> some View { _ShimView() }
    func help<S: StringProtocol>(_ text: S) -> some View { _ShimView() }
    func help(_ text: Text) -> some View { _ShimView() }
    func contextMenu<MenuItems: View>(@ViewBuilder menuItems: () -> MenuItems) -> some View { _ShimView() }
    func contextMenu<MenuItems: View>(forSelectionType itemType: Any.Type, @ViewBuilder menuItems: (Set<AnyHashable>) -> MenuItems) -> some View { _ShimView() }
    func onDrag<V: View>(@ViewBuilder _ data: () -> V) -> some View { _ShimView() }
    func onDrop(of supportedContentTypes: [String], isTargeted: Binding<Bool>?, perform action: @escaping ([Any]) -> Bool) -> some View { _ShimView() }
    func draggable<T>(_ payload: @autoclosure @escaping () -> T) -> some View { _ShimView() }
    func searchable(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey? = nil) -> some View { _ShimView() }
    func searchable<S: StringProtocol>(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: S) -> some View { _ShimView() }
    func searchable(text: Binding<String>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey? = nil) -> some View { _ShimView() }
}

public struct SearchFieldPlacement: Hashable, Sendable {
    public static let automatic = SearchFieldPlacement()
    public static let toolbar = SearchFieldPlacement()
    public static let sidebar = SearchFieldPlacement()
    public static let navigationBarDrawer = SearchFieldPlacement()
    public static func navigationBarDrawer(displayMode: SearchFieldPlacement.DisplayMode) -> SearchFieldPlacement { SearchFieldPlacement() }
    public enum DisplayMode: Hashable, Sendable { case automatic, always }
}

// MARK: - Gestes

public extension View {
    func gesture<G: Gesture>(_ gesture: G, including mask: GestureMask = .all) -> some View { _ShimView() }
    func highPriorityGesture<G: Gesture>(_ gesture: G, including mask: GestureMask = .all) -> some View { _ShimView() }
    func simultaneousGesture<G: Gesture>(_ gesture: G, including mask: GestureMask = .all) -> some View { _ShimView() }
    func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View { _ShimView() }
    func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform action: @escaping (CGPoint) -> Void) -> some View { _ShimView() }
    func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, perform action: @escaping () -> Void, onPressingChanged: ((Bool) -> Void)? = nil) -> some View { _ShimView() }
    func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, pressing: ((Bool) -> Void)? = nil, perform action: @escaping () -> Void) -> some View { _ShimView() }
    func onLongPressGesture(minimumDuration: Double = 0.5, perform action: @escaping () -> Void) -> some View { _ShimView() }
    func coordinateSpace(name: AnyHashable) -> some View { _ShimView() }
}

public struct GestureMask: OptionSet, Sendable {
    public let rawValue: Int
    public nonisolated init(rawValue: Int) { self.rawValue = rawValue }
    public static let none = GestureMask(rawValue: 0)
    public static let gesture = GestureMask(rawValue: 1 << 0)
    public static let subviews = GestureMask(rawValue: 1 << 1)
    public static let all: GestureMask = [.gesture, .subviews]
}

public protocol _ShimGestureValue {
    associatedtype Value
}

extension DragGesture: _ShimGestureValue {}

/// Le résultat d'une chaîne de gestes est lui-même un geste : sans cette
/// conformité, `.onChanged { }.onEnded { }` ne compile pas.
extension _ShimGesture: _ShimGestureValue {}
extension TapGesture: _ShimGestureValue {
    public typealias Value = ()
}
extension LongPressGesture: _ShimGestureValue {
    public typealias Value = Bool
}
extension SpatialTapGesture: _ShimGestureValue {}
extension MagnificationGesture: _ShimGestureValue {}
extension RotationGesture: _ShimGestureValue {}

public extension Gesture where Self: _ShimGestureValue {
    func onChanged(_ action: @escaping (Self.Value) -> Void) -> _ShimGesture<Self.Value> { _ShimGesture() }
    func onEnded(_ action: @escaping (Self.Value) -> Void) -> _ShimGesture<Self.Value> { _ShimGesture() }
    func updating<State>(_ state: GestureState<State>, body: @escaping (Self.Value, inout State, inout Transaction) -> Void) -> _ShimGesture<Self.Value> { _ShimGesture() }
    func sequenced<Other: Gesture>(before other: Other) -> _ShimGesture<Self.Value> { _ShimGesture() }
    func simultaneously<Other: Gesture>(with other: Other) -> _ShimGesture<Self.Value> { _ShimGesture() }
}

// MARK: - Accessibilité

public extension View {
    func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View { _ShimView() }
    func accessibilityLabel(_ label: Text) -> some View { _ShimView() }
    func accessibilityLabel(_ labelKey: LocalizedStringKey) -> some View { _ShimView() }
    func accessibilityLabel<S: StringProtocol>(_ label: S) -> some View { _ShimView() }
    func accessibilityValue(_ value: Text) -> some View { _ShimView() }
    func accessibilityValue(_ valueKey: LocalizedStringKey) -> some View { _ShimView() }
    func accessibilityValue<S: StringProtocol>(_ value: S) -> some View { _ShimView() }
    func accessibilityHint(_ hint: Text) -> some View { _ShimView() }
    func accessibilityHint(_ hintKey: LocalizedStringKey) -> some View { _ShimView() }
    func accessibilityHint<S: StringProtocol>(_ hint: S) -> some View { _ShimView() }
    func accessibilityIdentifier(_ identifier: String) -> some View { _ShimView() }
    func accessibilityHidden(_ hidden: Bool = true) -> some View { _ShimView() }
    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View { _ShimView() }
    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View { _ShimView() }
    func accessibilitySortPriority(_ priority: Double) -> some View { _ShimView() }
    func accessibilityAction(_ actionKind: AccessibilityActionKind = .default, _ handler: @escaping () -> Void) -> some View { _ShimView() }
    func accessibilityAction<I>(_ actionKind: AccessibilityActionKind = .default, _ label: Text, _ handler: @escaping (I) -> Void) -> some View { _ShimView() }
    func accessibilityAction(named nameKey: LocalizedStringKey, _ handler: @escaping () -> Void) -> some View { _ShimView() }
    func accessibilityAction<S: StringProtocol>(named name: S, _ handler: @escaping () -> Void) -> some View { _ShimView() }
    func accessibilityAdjustableAction(_ handler: @escaping (AccessibilityAdjustmentDirection) -> Void) -> some View { _ShimView() }
    func accessibilityInputLabels(_ inputLabels: [Text]) -> some View { _ShimView() }
    func accessibilityFocused(_ binding: FocusState<Bool>.Binding) -> some View { _ShimView() }
    func accessibilityRespondsToUserInteraction(_ respondsToUserInteraction: Bool = true) -> some View { _ShimView() }
    func accessibilityZoomAction(_ handler: @escaping (AccessibilityZoomGestureAction) -> Void) -> some View { _ShimView() }
}

public enum AccessibilityAdjustmentDirection: Hashable, Sendable { case increment, decrement }

public struct AccessibilityZoomGestureAction {
    public enum Direction: Hashable, Sendable { case zoomIn, zoomOut }
    public var direction: Direction { .zoomIn }
    public var point: UnitPoint { .center }
}

// MARK: - Formes (modificateurs)

public extension Shape {
    func fill<S: ShapeStyle>(_ content: S, style: FillStyle = FillStyle()) -> some View { _ShimView() }
    func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle) -> some View { _ShimView() }
    func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1) -> some View { _ShimView() }
    func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool) -> some View { _ShimView() }
    func trim(from: CGFloat = 0, to: CGFloat = 1) -> some Shape { self }
    func rotation(_ angle: Angle, anchor: UnitPoint = .center) -> some Shape { self }
    func scale(_ scale: CGFloat, anchor: UnitPoint = .center) -> some Shape { self }
    func scale(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some Shape { self }
    func offset(_ offset: CGSize) -> some Shape { self }
    func offset(x: CGFloat = 0, y: CGFloat = 0) -> some Shape { self }
    func transform(_ transform: CGAffineTransform) -> some Shape { self }
    func size(_ size: CGSize) -> some Shape { self }
    func size(width: CGFloat, height: CGFloat) -> some Shape { self }
    func sizeToFit() -> some View { _ShimView() }
}

public extension InsettableShape {
    func strokeBorder<S: ShapeStyle>(_ content: S, style: StrokeStyle) -> some View { _ShimView() }
    func strokeBorder<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1) -> some View { _ShimView() }
    func strokeBorder<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool) -> some View { _ShimView() }
    func fill<S: ShapeStyle>(_ content: S, style: FillStyle = FillStyle()) -> some View { _ShimView() }
}

// MARK: - Scènes

public extension Scene {
    func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some Scene { self }
    func environmentObject<T: ObservableObject>(_ object: T) -> some Scene { self }
    func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some Scene { self }
    func defaultAppStorage(_ store: UserDefaults) -> some Scene { self }
    func commands<Content: View>(@ViewBuilder content: () -> Content) -> some Scene { self }
    func commandsRemoved() -> some Scene { self }
}


// MARK: - Égalité (réutilisation de vue)

public extension View {
    /// `View.equatable()` : marque la vue comme réutilisable tant qu'elle est
    /// égale. Shim : renvoie la vue elle-même (aucune vue enveloppe à typer).
    func equatable() -> Self { self }
}

// MARK: - Compléments Foundation absents de corelibs-foundation

/// `URL.startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`
/// appartiennent à Foundation sur Apple ; corelibs-foundation sous Linux ne les
/// fournit pas. L'extension vit ici (et non dans un module Foundation factice,
/// impossible à substituer) : les fichiers de Duello importent SwiftUI, donc
/// elle leur est visible. Renvoie `true`, comme sur iOS dans le cas nominal.
public extension URL {
    func startAccessingSecurityScopedResource() -> Bool { true }
    func stopAccessingSecurityScopedResource() {}
}
