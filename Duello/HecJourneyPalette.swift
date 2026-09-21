import SwiftUI

/// Teintes propres au parcours HEC, relevées dans les sources Expo.
///
/// - `HEC_JOURNEY_NAVY` (`#123B68`) et la piste (`#C8D6E0`) viennent de
///   `src/components/HecJourneyScene.tsx` ;
/// - la palette sombre vient de la feuille d'ajout de
///   `src/components/HecJourney.tsx` (`backgroundColor: rgba(25,24,22,0.98)`,
///   séparateurs `rgba(255,255,255,0.17)` / `0.10` / `0.08`, textes `#E5E2DD`,
///   `#D7D4D0`, `#B2AEA9`, `#77736E`, désactivé `#4D4A46`, corbeille `#E98888`,
///   `#F2AAAA`) et de `HecJourneyCalendarPicker.tsx` (jour sélectionné
///   `#E5E2DD` sur texte `#1B1A18`).
///
/// Ces teintes ne sont pas dans `Theme` : elles n'existent que sur cet écran,
/// qui garde sa feuille sombre au milieu d'une interface claire.
enum HecJourneyPalette {

    // MARK: Scène

    /// `HEC_JOURNEY_NAVY` : les blocs de cours déjà vus.
    static let navy = Color(hex: 0x123B68)
    /// Couleur du tuyau de la piste (`#C8D6E0`).
    static let track = Color(hex: 0xC8D6E0)

    // MARK: Feuille d'ajout

    static let sheet = Color(hex: 0x191816)
    static let sheetBorder = Color.white.opacity(0.17)
    static let sheetSeparator = Color.white.opacity(0.10)
    static let sheetSeparatorSoft = Color.white.opacity(0.08)

    static let sheetInk = Color(hex: 0xE5E2DD)
    static let sheetInkSoft = Color(hex: 0xD7D4D0)
    static let sheetInkFaint = Color(hex: 0xB2AEA9)
    static let sheetInkMuted = Color(hex: 0x77736E)
    static let sheetInkDisabled = Color(hex: 0x4D4A46)
    static let sheetAccent = Color(hex: 0xD9D6D1)
    static let sheetDanger = Color(hex: 0xE98888)
    static let sheetDangerStrong = Color(hex: 0xF2AAAA)
    static let sheetHighlight = Color(hex: 0xE5E2DD)
    static let sheetHighlightInk = Color(hex: 0x1B1A18)
    /// Titres de panneau et bouton principal (`confirmationButton`).
    static let sheetStrong = Color(hex: 0xF0EDE8)
    static let sheetPrimaryInk = Color(hex: 0x1B1A18)
    /// Bouton de suppression (`deleteConfirmationButton`).
    static let sheetDangerFill = Color(hex: 0xD95B5B)
    /// Bouton secondaire (`confirmationSecondaryText`) et sous-titres.
    static let sheetInkSubtle = Color(hex: 0xA9A49E)
    static let sheetInkHint = Color(hex: 0x8E8983)
    /// Bordures et fonds translucides de la feuille.
    static let sheetBorderSoft = Color.white.opacity(0.14)
    /// Filet entre deux lignes de liste (`borderBottomColor` de `chapterOption`).
    static let sheetRowSeparator = Color.white.opacity(0.07)
    static let sheetIconSurface = Color.white.opacity(0.08)
    static let sheetDangerSurface = Color(hex: 0xE55C5C).opacity(0.12)
}
