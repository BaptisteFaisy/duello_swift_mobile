import SwiftUI

/// Éléments d'habillage de la feuille sombre du parcours.
enum HecJourneySheet {
    /// Filet horizontal de séparation (`borderBottomColor` de la source).
    struct Separator: View {
        var color: Color = HecJourneyPalette.sheetSeparator
        var body: some View {
            Rectangle().fill(color).frame(height: 1)
        }
    }

    /// Bouton icône de la feuille (flèches de date, calendrier, retour).
    struct IconButton: View {
        let systemName: String
        let label: String
        var size: CGFloat = 15
        var tint: Color = HecJourneyPalette.sheetInkSoft
        var frame: CGFloat = 34
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: frame, height: frame)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }
    }

    /// Ligne d'option pleine largeur (chapitre, vacances).
    struct OptionRow: View {
        let title: String
        var leading: String? = nil
        var icon: String? = nil
        var trailingIcon: String? = nil
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 10) {
                    if let leading {
                        Text(leading)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(HecJourneyPalette.sheetInkMuted)
                            .frame(width: 22, alignment: .leading)
                    }
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HecJourneyPalette.sheetAccent)
                    }
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(HecJourneyPalette.sheetInk)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    if let trailingIcon {
                        Image(systemName: trailingIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(HecJourneyPalette.sheetInkMuted)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Bouton de la feuille : plein pour « CONFIRMER » (`#F0EDE8` sur
    /// `#1B1A18`) et « SUPPRIMER » (`#D95B5B` sur blanc), bordé pour
    /// « ANNULER » et les zones.
    struct ActionButton: View {
        let title: String
        var filled = true
        var danger = false
        var enabled = true
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(foreground)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 38)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(filled ? Color.clear : HecJourneyPalette.sheetBorderSoft, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
        }

        private var foreground: Color {
            if !filled { return HecJourneyPalette.sheetInkSubtle }
            return danger ? Color.white : HecJourneyPalette.sheetPrimaryInk
        }

        private var background: Color {
            if !filled { return Color.clear }
            return danger ? HecJourneyPalette.sheetDangerFill : HecJourneyPalette.sheetStrong
        }
    }
}
