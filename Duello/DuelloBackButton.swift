import SwiftUI

/// Retour visuel commun — port fidèle de `rn-ref/src/components/BackButton.tsx`.
///
/// Chevron d'encre, **sans fond, cadre ni forme décorative** : le composant RN
/// neutralise `borderWidth` / `borderRadius` / `backgroundColor` dans
/// `styles.button`, et ce style est appliqué **après** celui de l'écran. Les
/// écrans qui posent un carré bordé (`SubjectsScreen`, `MessagesScreen`,
/// `AccountScreen.settingsBackButton`) le voient donc annulé : le rendu réel
/// reste un chevron nu. La zone tactile est volontairement plus grande que le
/// pictogramme (`minWidth` / `minHeight` 40).
///
/// Repères de la source, repris tels quels :
/// - boîte `minWidth` / `minHeight` 40, ligne centrée, `gap: 4` ;
/// - pictogramme 22 par défaut, centré puis `translateX(-4)` ; en mode
///   `alignChevronTip` il passe à `translateX(3)` ; `iconVerticalOffset` le
///   décale en Y (une valeur négative le relève) ;
/// - variante `compact` : hauteur visuelle 24 (`height: 24`, `minHeight: 24`),
///   largeur minimale inchangée ;
/// - appui : `opacity 0.6` (`styles.pressed`).
///
/// Divergences **signalées**, non bricolées :
/// - **glyphe** — Ionicons `chevron-back` → SF Symbol `chevron.left`. Ionicons
///   n'a pas de notion de graisse ; `iconWeight` (défaut `.semibold`) n'est
///   qu'une approximation du trait. Seul le port Kotlin rend la police réelle.
/// - **`hitSlop: 8`** (RN) n'a pas d'équivalent iOS 16 : la cible tactile se
///   limite à la boîte 40 × 40.
/// - **retour matériel Android** (`useAndroidBackAction`) : sans objet sur iOS.
///
/// L'appui suit la valeur **déclarée** par le composant. `AppPressable` (RN)
/// résout son style avec l'état *resting* (`pressed === false`), si bien que
/// cet `opacity 0.6` peut rester inerte dans l'app réelle — point relevé au
/// rapport, laissé tel quel faute de pouvoir trancher au pixel.
struct DuelloBackButton<Label: View>: View {
    /// Aligne la pointe du chevron sur le bord du contenu (`alignChevronTip`).
    var alignChevronTip: Bool
    /// Réduit la hauteur visuelle à 24 pt (`compact`).
    var compact: Bool
    /// Couleur du pictogramme (`iconColor`, défaut `colors.ink`).
    var iconColor: Color
    /// Taille du pictogramme (`iconSize`, défaut **22** dans la source).
    var iconSize: CGFloat
    /// Graisse SF du pictogramme — approximation du trait Ionicons.
    var iconWeight: Font.Weight
    /// Décalage vertical fin du pictogramme (`iconVerticalOffset`).
    var iconVerticalOffset: CGFloat
    /// Désactive l'action (`disabled`).
    var isDisabled: Bool
    /// Libellé d'accessibilité (`accessibilityLabel`), omis s'il est `nil`.
    var accessibilityLabel: String?

    private let action: () -> Void
    private let label: () -> Label

    init(
        alignChevronTip: Bool = false,
        compact: Bool = false,
        iconColor: Color = Theme.ink,
        iconSize: CGFloat = 22,
        iconWeight: Font.Weight = .semibold,
        iconVerticalOffset: CGFloat = 0,
        isDisabled: Bool = false,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.alignChevronTip = alignChevronTip
        self.compact = compact
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.iconVerticalOffset = iconVerticalOffset
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(DuelloBackButtonPressStyle())
        .disabled(isDisabled)
        .modifier(DuelloBackButtonAccessibilityLabel(label: accessibilityLabel))
    }

    /// Boîte du composant : chevron puis contenu facultatif, centrés, `gap 4`.
    private var content: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.system(size: iconSize, weight: iconWeight))
                .foregroundStyle(iconColor)
                .offset(x: alignChevronTip ? 3 : -4, y: iconVerticalOffset)
            label()
        }
        .frame(minWidth: 40, minHeight: compact ? 24 : 40, maxHeight: compact ? 24 : nil)
        .contentShape(Rectangle())
    }
}

extension DuelloBackButton where Label == EmptyView {
    /// Variante sans contenu (usage dominant : chevron seul).
    init(
        alignChevronTip: Bool = false,
        compact: Bool = false,
        iconColor: Color = Theme.ink,
        iconSize: CGFloat = 22,
        iconWeight: Font.Weight = .semibold,
        iconVerticalOffset: CGFloat = 0,
        isDisabled: Bool = false,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            alignChevronTip: alignChevronTip,
            compact: compact,
            iconColor: iconColor,
            iconSize: iconSize,
            iconWeight: iconWeight,
            iconVerticalOffset: iconVerticalOffset,
            isDisabled: isDisabled,
            accessibilityLabel: accessibilityLabel,
            action: action,
            label: { EmptyView() }
        )
    }
}

/// Appui : `opacity 0.6` (`styles.pressed` de la source).
private struct DuelloBackButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// `accessibilityLabel` facultatif : n'est appliqué que s'il est fourni, faute
/// de quoi SwiftUI effacerait le libellé calculé par le système.
private struct DuelloBackButtonAccessibilityLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}
