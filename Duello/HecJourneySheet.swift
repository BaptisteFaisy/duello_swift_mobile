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

    /// Opacité à l'appui (`pressed: { opacity: … }` de la source).
    struct PressOpacityStyle: ButtonStyle {
        var pressed: Double = 0.65
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? pressed : 1)
        }
    }

    /// Fond à l'appui des lignes (`optionPressed` : `rgba(255,255,255,0.08)`).
    struct PressFillStyle: ButtonStyle {
        var fill: Color = Color.white.opacity(0.08)
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.background(configuration.isPressed ? fill : Color.clear)
        }
    }

    /// Appui des boutons d'action : opacité (`confirmationButtonPressed` :
    /// 0,72) et/ou remplissage (`optionPressed`).
    struct ActionPressStyle: ButtonStyle {
        var pressedOpacity: Double = 1
        var pressedFill: Color? = nil
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? pressedOpacity : 1)
                .background(configuration.isPressed ? (pressedFill ?? Color.clear) : Color.clear)
        }
    }

    /// Bouton icône de la feuille (flèches de date, calendrier, retour) et des
    /// en-têtes. Les glyphes sont ceux du RN (`IonIcon`), jamais un SF Symbol :
    /// la source rend un `<Ionicons name=… size=… color=… />` partout.
    ///
    /// `bordered` reprend les commandes encadrées de la source
    /// (`headerButton` : 40×40 ; `journeyRankingButton` : 64×34).
    struct IconButton: View {
        /// Nom logique Ionicons, tel qu'écrit dans la source RN.
        let name: String
        let label: String
        var size: CGFloat = 15
        var tint: Color = HecJourneyPalette.sheetInkSoft
        var width: CGFloat = 34
        var height: CGFloat = 34
        var bordered = false
        var cornerRadius: CGFloat = 12
        var pressOpacity: Double = 1
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                IonIcon(name: name, size: size, color: tint)
                    .frame(width: width, height: height)
                    .background(bordered ? Theme.surface : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: bordered ? cornerRadius : 0))
                    .overlay {
                        if bordered {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Theme.border, lineWidth: 1)
                        }
                    }
            }
            .buttonStyle(PressOpacityStyle(pressed: pressOpacity))
            .accessibilityLabel(label)
        }
    }

    /// Ligne d'option pleine largeur (chapitre, vacances). Les mesures par
    /// défaut sont celles de `chapterOption` ; `holidayOption` resserre la
    /// hauteur et la typo (voir `HecJourneyAddPanelPages`).
    struct OptionRow: View {
        let title: String
        /// Numéro d'index (« 01 »), aligné sur `chapterOptionIndex`.
        var leading: String? = nil
        var leadingWidth: CGFloat = 22
        /// Icône de tête (nom Ionicons).
        var icon: String? = nil
        var iconSize: CGFloat = 16
        var iconTint: Color = HecJourneyPalette.sheetAccent
        /// Icône de queue (nom Ionicons).
        var trailingIcon: String? = nil
        var trailingSize: CGFloat = 14
        var trailingTint: Color = HecJourneyPalette.sheetInkMuted
        var titleSize: CGFloat = 11
        var titleWeight: Font.Weight = .bold
        var titleColor: Color = HecJourneyPalette.sheetInk
        var spacing: CGFloat = 10
        var horizontalPadding: CGFloat = 16
        var verticalPadding: CGFloat = 0
        var minHeight: CGFloat = 0
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: spacing) {
                    if let leading {
                        Text(leading)
                            .font(.system(size: 8, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(HecJourneyPalette.sheetInkMuted)
                            .frame(width: leadingWidth, alignment: .leading)
                    }
                    if let icon {
                        IonIcon(name: icon, size: iconSize, color: iconTint)
                    }
                    Text(title)
                        .font(.system(size: titleSize, weight: titleWeight))
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if let trailingIcon {
                        IonIcon(name: trailingIcon, size: trailingSize, color: trailingTint)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressFillStyle())
        }
    }

    /// Bouton de la feuille. Les teintes et mesures sont portées explicitement,
    /// comme la source les écrit style par style (`confirmationButton`,
    /// `confirmationSecondaryButton`, `deleteConfirmationButton`,
    /// `holidayZoneButton`, `customDateButton`).
    struct ActionButton: View {
        let title: String
        var titleColor: Color = HecJourneyPalette.sheetPrimaryInk
        var background: Color = HecJourneyPalette.sheetStrong
        var borderColor: Color = .clear
        var titleSize: CGFloat = 9
        var tracking: CGFloat = 0.8
        var minHeight: CGFloat = 38
        var horizontalPadding: CGFloat = 14
        var enabled = true
        /// Icône optionnelle (nom Ionicons), comme « UTILISER LE … ».
        var icon: String? = nil
        var iconSize: CGFloat = 15
        var iconColor: Color = HecJourneyPalette.sheetAccent
        var pressOpacity: Double = 1
        var pressFill: Color? = nil
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 7) {
                    if let icon {
                        IonIcon(name: icon, size: iconSize, color: iconColor)
                    }
                    Text(title)
                        .font(.system(size: titleSize, weight: .black))
                        .tracking(tracking)
                        .foregroundStyle(titleColor)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity)
                .frame(minHeight: minHeight)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(ActionPressStyle(pressedOpacity: pressOpacity, pressedFill: pressFill))
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
        }
    }

    /// Rangée de boutons d'action aux rapports de flexibilité de la source :
    /// « ANNULER » pèse 0,8 face à « CONFIRMER »/« SUPPRIMER » à 1,2
    /// (`confirmationSecondaryButton` / `confirmationButton`).
    struct ActionRow: View {
        struct Slot: Identifiable {
            let id = UUID()
            let flex: CGFloat
            let button: ActionButton
        }

        let slots: [Slot]
        var spacing: CGFloat = 8

        var body: some View {
            GeometryReader { geometry in
                let count = max(1, slots.count)
                let total = max(0, geometry.size.width - spacing * CGFloat(count - 1))
                let weight = slots.reduce(0) { $0 + $1.flex }
                HStack(spacing: spacing) {
                    ForEach(slots) { slot in
                        slot.button
                            .frame(width: weight > 0 ? total * slot.flex / weight : total / CGFloat(count))
                    }
                }
            }
            .frame(height: 38)
        }
    }
}
