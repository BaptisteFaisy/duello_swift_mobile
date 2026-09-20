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

    // MARK: Mesures

    /// Rayons de carte, alignés sur `radii` du thème Expo.
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 18

    /// Prose d'étude : énoncé et corrigé en serif, comme un manuel.
    static let readingFont: Font = .system(size: 16, weight: .regular, design: .serif)
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

/// Carte blanche à bord fin, motif récurrent de l'interface Duello.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(Theme.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func duelloCard() -> some View {
        modifier(CardBackground())
    }
}
