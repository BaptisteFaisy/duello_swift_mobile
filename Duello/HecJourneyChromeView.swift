import SwiftUI

/// Barre d'en-tête du parcours : retour ou sélecteur d'année, puis classement.
///
/// Porté de `PerformanceOverviewBar` tel qu'utilisé par
/// `src/components/HecJourney.tsx` : à gauche la flèche de retour quand le
/// parent en fournit une (`onBack`), sinon les onglets d'année
/// (`ProgramYearTabs`) ; à droite le trophée qui ouvre le classement XP de
/// mathématiques.
struct HecJourneyHeaderBar: View {
    let showsBackButton: Bool
    let programYear: Int
    let onBack: () -> Void
    let onSelectYear: (Int) -> Void
    let onOpenRanking: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if showsBackButton {
                HecJourneySheet.IconButton(
                    systemName: "chevron.left",
                    label: HecJourneyCopy.a11yBackToParcours,
                    size: 20,
                    tint: Theme.ink,
                    frame: 40,
                    action: onBack
                )
            } else {
                HecJourneyYearTabs(programYear: programYear, onSelectYear: onSelectYear)
            }
            Spacer(minLength: 0)
            HecJourneySheet.IconButton(
                systemName: "trophy",
                label: HecJourneyCopy.a11yRanking,
                size: 21,
                tint: Theme.ink,
                frame: 40,
                action: onOpenRanking
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }
}

/// Sélecteur d'année (`ProgramYearTabs`) : « 1re année » / « 2e année ».
struct HecJourneyYearTabs: View {
    let programYear: Int
    let onSelectYear: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach([1, 2], id: \.self) { year in
                Button {
                    onSelectYear(year)
                } label: {
                    Text(HecJourneyCopy.yearLabels[year] ?? "")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(year == programYear ? Theme.surface : Theme.inkSoft)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(year == programYear ? Theme.ink : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(HecJourneyCopy.yearLabels[year] ?? "")
            }
        }
        .padding(3)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(HecJourneyCopy.a11yProgramYear)
    }
}

/// Titre « PARCOURS HEC » et rappel du bloc mis au premier plan.
///
/// Porté de `titleRow` de `src/components/HecJourney.tsx` : la source masque
/// toute interaction sur cette couche (`pointerEvents="none"`), d'où
/// `allowsHitTesting(false)`.
struct HecJourneyTitleRow: View {
    /// Bloc au premier plan ; absent seulement si la frise est vide.
    let block: HecJourneySceneBlock?

    var body: some View {
        VStack(spacing: 3) {
            Text(HecJourneyCopy.screenTitle)
                .font(.system(size: 10, weight: .black))
                .tracking(2.1)
                .foregroundStyle(Theme.ink)
            if let block {
                Text(subtitle(for: block))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(block.title.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
        }
        .allowsHitTesting(false)
    }

    /// Le blason final n'a pas de date : la source écrit « fin du parcours ».
    private func subtitle(for block: HecJourneySceneBlock) -> String {
        block.type == .admission
            ? HecJourneyCopy.endOfJourney
            : HecJourneyDates.format(block.createdAt)
    }
}

/// Raccourci de navigation de la frise (`JOURNEY_SHORTCUTS`) : le bouton fait
/// le tour « bloc actuel » → « fin » → « début ».
enum HecJourneyShortcut: CaseIterable {
    case current
    case end
    case start

    var label: String {
        switch self {
        case .current: return HecJourneyCopy.shortcutCurrent
        case .end: return HecJourneyCopy.shortcutEnd
        case .start: return HecJourneyCopy.shortcutStart
        }
    }

    /// `Ionicons` `chevron-up` pour la fin, `chevron-down` pour le début, un
    /// point pour le bloc actuel.
    var icon: String? {
        switch self {
        case .current: return nil
        case .end: return "chevron.up"
        case .start: return "chevron.down"
        }
    }

    var next: HecJourneyShortcut {
        switch self {
        case .current: return .end
        case .end: return .start
        case .start: return .current
        }
    }
}

/// Commandes du bas : « + » pour ajouter un bloc, et le raccourci de
/// navigation.
struct HecJourneyBottomControls: View {
    let shortcut: HecJourneyShortcut
    let onAdd: () -> Void
    let onShortcut: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HecJourneySheet.IconButton(
                systemName: "plus",
                label: HecJourneyCopy.a11yAddBlock,
                size: 14,
                tint: Theme.ink,
                frame: 24,
                action: onAdd
            )
            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            HecJourneySheet.IconButton(
                systemName: shortcut.icon ?? "circle.fill",
                label: shortcut.label,
                size: shortcut.icon == nil ? 6 : 12,
                tint: Theme.inkSoft,
                frame: 25,
                action: onShortcut
            )
        }
        .padding(4)
        .background(Color.white.opacity(0.94))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }
}

/// Bouton de bascule d'année affiché aux extrémités de la frise
/// (`nextYearButton`) : « PARCOURS DE 2E ANNÉE » en fin de 1re année,
/// « PARCOURS DE 1RE ANNÉE » au début de la 2e.
struct HecJourneyYearSwitchButton: View {
    /// Vrai quand on propose de revenir en 1re année.
    let isSecondYear: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if !isSecondYear {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Text(isSecondYear ? HecJourneyCopy.previousYearButton : HecJourneyCopy.nextYearButton)
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink)
                if isSecondYear {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(Color.white.opacity(0.94))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSecondYear ? HecJourneyCopy.a11yPreviousYear : HecJourneyCopy.a11yNextYear)
    }
}
