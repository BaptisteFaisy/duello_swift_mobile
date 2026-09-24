import SwiftUI

/// Palette et mesures reprises de `src/theme.ts` de l'application Expo.
/// Interface sans teinte : l'encre et ses gris portent toute la hiérarchie,
/// le vert n'apparaît que pour la maîtrise et la réussite.
enum Theme {
    // MARK: Couleurs

    static let backgroundHex = 0xFFFFFF
    static let surfaceHex = 0xFFFFFF
    static let surfaceMutedHex = 0xF4F5F4
    static let inkHex = 0x0A0D0C
    static let inkSoftHex = 0x555B58
    static let inkFaintHex = 0x8B918E
    static let primaryLightHex = 0xECEEED
    static let borderHex = 0xE1E4E2
    static let progressHex = 0x16A34A
    static let progressLightHex = 0xDCFCE7
    static let likeHex = 0xE5484D
    static let premiumHex = 0x16A34A
    static let premiumSurfaceHex = 0xF1FAF3
    static let premiumSurfaceBorderHex = 0xCDE9D6
    static let gradingPerfectHex = 0x166534
    static let gradingPerfectLightHex = 0xDCFCE7
    static let gradingPartialHex = 0xD97706
    static let gradingPartialLightHex = 0xFFF7D6

    static var background: Color { Color(hex: backgroundHex) }
    static var surface: Color { Color(hex: surfaceHex) }
    static var surfaceMuted: Color { Color(hex: surfaceMutedHex) }
    static var ink: Color { Color(hex: inkHex) }
    static var inkSoft: Color { Color(hex: inkSoftHex) }
    static var inkFaint: Color { Color(hex: inkFaintHex) }
    static var primary: Color { ink }
    static var primaryLight: Color { Color(hex: primaryLightHex) }
    static var border: Color { Color(hex: borderHex) }
    static var progress: Color { Color(hex: progressHex) }
    static var progressLight: Color { Color(hex: progressLightHex) }
    static var like: Color { Color(hex: likeHex) }
    static var premium: Color { Color(hex: premiumHex) }
    static var gradingPerfect: Color { Color(hex: gradingPerfectHex) }
    static var gradingPerfectLight: Color { Color(hex: gradingPerfectLightHex) }
    static var gradingPartial: Color { Color(hex: gradingPartialHex) }
    static var gradingPartialLight: Color { Color(hex: gradingPartialLightHex) }

    // MARK: Mesures

    /// Rayons de carte, alignés sur `radii` du thème Expo.
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 18

    /// Champ de fournisseur de l'étape `auth-method` (Google et Apple) :
    /// hauteur, écart logo/libellé et taille du logo. Une seule source, pour
    /// que les deux boutons d'une même paire ne puissent pas diverger — ils
    /// partagent déjà leur peinture (`GoogleFieldButtonStyle`).
    static let providerFieldMinHeight: CGFloat = 55
    static let providerFieldSpacing: CGFloat = 10
    static let providerLogoSize: CGFloat = 20

    // MARK: Champ de fournisseur — états

    /// Message d'échec sous le champ (`colors.prerequisitesMissing`, commun
    /// aux deux boutons Expo).
    static var providerError: Color { Color(hex: 0xB42318) }
    static var providerErrorOnDark: Color { Color(hex: 0xFF8A80) }

    // MARK: Prose d'étude

    /// Tailles de la prose d'étude. `readingText` du thème Expo ne fixe que la
    /// famille (Georgia) et la graisse (400) : la **taille** vient du style qui
    /// l'étend. Valeurs reprises des styles RN :
    /// - `readingSizeBody` **14** — énoncé et corrigé (`promptText`,
    ///   `correctionText`, `aiText`) : usage dominant, donc défaut ;
    /// - `readingSizeReader` **15** — lecture d'annale (`inlineStatementText`,
    ///   `questionCorrectionText`) ;
    /// - `readingSizeCompact` **11** — énoncé replié (`promptTextCompact`).
    static let readingSizeBody: CGFloat = 14
    static let readingSizeReader: CGFloat = 15
    static let readingSizeCompact: CGFloat = 11

    /// Prose d'étude : énoncé et corrigé en serif, comme un manuel. La taille
    /// n'est plus figée : le défaut reprend l'usage dominant du RN (14) ; pour
    /// l'annale (15) ou l'énoncé replié (11), passer la taille par
    /// `readingFont(size:)`.
    static let readingFont: Font = readingFont(size: readingSizeBody)

    /// Prose d'étude à taille paramétrable — famille (serif, cf. `Georgia` du RN)
    /// et graisse (400) fixes, exactement ce que porte `readingText`.
    static func readingFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

extension Color {
    init(hex: Int, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Carte blanche à bord fin et ombre légère, motif récurrent de l'interface
/// Duello. Valeurs reprises des cartes de l'app RN — `borderWidth 1`,
/// `borderColor colors.border`, `backgroundColor colors.surface`,
/// `borderRadius radii.large`, `...cardShadow` — soit : padding 18, rayon 18,
/// ombre `cardShadow` (`#0A0D0C` à 4 %, flou 8, décalage vertical 2).
///
/// Le padding et le rayon varient d'une carte à l'autre dans le RN ; le défaut
/// reprend l'usage dominant (carte bordée, `padding 18`, `radii.large`). Les
/// cartes qui s'en écartent passent leurs valeurs en paramètre
/// (`duelloCard(padding:radius:shadow:)`) plutôt que de redéfinir un motif local.
struct CardBackground: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = Theme.radiusLarge
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface)
            .cornerRadius(radius)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .shadow(
                color: shadow ? Theme.cardShadowColor : .clear,
                radius: Theme.cardShadowRadius,
                x: 0,
                y: Theme.cardShadowOffsetY
            )
    }
}

extension View {
    /// Carte du kit Duello : padding 18, rayon `radii.large` 18, bord 1 `border`,
    /// fond `surface`, ombre `cardShadow`. Défauts = usage RN dominant ; les
    /// cartes qui s'en écartent passent `padding`/`radius`/`shadow`.
    func duelloCard(
        padding: CGFloat = 18,
        radius: CGFloat = Theme.radiusLarge,
        shadow: Bool = true
    ) -> some View {
        modifier(CardBackground(padding: padding, radius: radius, shadow: shadow))
    }
}
