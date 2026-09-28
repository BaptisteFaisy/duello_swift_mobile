import SwiftUI

/// Barre d'en-tête du parcours : retour ou sélecteur d'année, puis classement.
///
/// Porté de `PerformanceOverviewBar` tel qu'utilisé par
/// `src/components/HecJourney.tsx` (`header`, `refined`/`embedded`/`balanced`) :
/// hauteur 60 (`PERFORMANCE_OVERVIEW_BAR_HEIGHT`), remontée de 7 points
/// (`transform: [{ translateY: -7 }]`, `:1519`), à gauche la flèche de retour
/// quand le parent en fournit une (`onBack`), sinon les onglets d'année
/// (`ProgramYearTabs`) ; à droite le trophée qui ouvre le classement XP de
/// mathématiques.
struct HecJourneyHeaderBar: View {
    let showsBackButton: Bool
    let programYear: Int
    /// Année de départ du parcours : l'onglet correspondant porte le hint
    /// « Votre année actuelle ».
    var profileYear: Int? = nil
    let onBack: () -> Void
    let onSelectYear: (Int) -> Void
    let onOpenRanking: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            if showsBackButton {
                // `BackButton` : chevron nu (aucun cadre), `iconSize` 22.
                HecJourneySheet.IconButton(
                    name: "chevron-back",
                    label: HecJourneyCopy.a11yBackToParcours,
                    size: 22,
                    tint: Theme.ink,
                    width: 40,
                    height: 40,
                    pressOpacity: 0.6,
                    action: onBack
                )
            } else {
                HecJourneyYearTabs(programYear: programYear, profileYear: profileYear, onSelectYear: onSelectYear)
                    .padding(.leading, 8)
            }
            Spacer(minLength: 0)
            // Sans retour, la coupe reprend l'encombrement du sélecteur opposé
            // (`journeyRankingButton` : 64×34, radius 10) ; avec retour, c'est
            // le bouton encadré standard (`headerButton` : 40×40, radius 12).
            HecJourneySheet.IconButton(
                name: "trophy-outline",
                label: HecJourneyCopy.a11yRanking,
                size: 21,
                tint: Theme.ink,
                width: showsBackButton ? 40 : 64,
                height: showsBackButton ? 40 : 34,
                bordered: true,
                cornerRadius: showsBackButton ? 12 : 10,
                pressOpacity: 0.65,
                action: onOpenRanking
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minHeight: 60)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .offset(y: -7)
    }
}

/// Sélecteur d'année (`ProgramYearTabs`) : « 1re » / « 2e ».
struct HecJourneyYearTabs: View {
    let programYear: Int
    /// Année du profil : l'onglet correspondant porte le hint « année
    /// actuelle » (`ProgramYearTabs.tsx:92`).
    var profileYear: Int? = nil
    let onSelectYear: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach([1, 2], id: \.self) { year in
                Button {
                    onSelectYear(year)
                } label: {
                    Text(HecJourneyCopy.yearTabTitles[year] ?? "")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(year == programYear ? Theme.surface : Theme.inkSoft)
                        .frame(minWidth: 29, minHeight: 30)
                        .background(year == programYear ? Theme.ink : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(HecJourneySheet.PressOpacityStyle(pressed: 0.65))
                .accessibilityLabel("Programme de \(HecJourneyCopy.yearLabels[year] ?? "")")
                .accessibilityHint(year == profileYear ? HecJourneyCopy.yearCurrentHint : "")
                .accessibilityAddTraits(year == programYear ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(HecJourneyCopy.a11yProgramYear)
    }
}

/// Titre « PARCOURS HEC » et rappel du bloc mis au premier plan.
///
/// Porté de `titleRow` de `src/components/HecJourney.tsx:1044-1058` : une ligne
/// (`flexDirection: row`, `justifyContent: space-between`) — titre à gauche,
/// date + type alignés à droite sur au plus 62 % de la largeur. La source masque
/// toute interaction sur cette couche (`pointerEvents="none"`), d'où
/// `allowsHitTesting(false)`.
struct HecJourneyTitleRow: View {
    /// Bloc au premier plan ; absent seulement si la frise est vide.
    let block: HecJourneySceneBlock?

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 8) {
                Text(HecJourneyCopy.screenTitle)
                    .font(.system(size: 10, weight: .black))
                    .tracking(2.1)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                if let block {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(subtitle(for: block))
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text(block.title.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: geometry.size.width * 0.62, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 7)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(minHeight: 50)
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
        case .end: return "chevron-up"
        case .start: return "chevron-down"
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
/// navigation. Les deux commandes sont **séparées** (`addButton` 24×24 et
/// `navigationControl` 25×24, écart 8), comme `bottomControls` de la source.
struct HecJourneyBottomControls: View {
    let shortcut: HecJourneyShortcut
    let onAdd: () -> Void
    let onShortcut: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAdd) {
                IonIcon(name: "add", size: 14, color: Theme.ink)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(HecJourneySheet.PressOpacityStyle(pressed: 0.65))
            .accessibilityLabel(HecJourneyCopy.a11yAddBlock)

            Button(action: onShortcut) {
                Group {
                    if let icon = shortcut.icon {
                        IonIcon(name: icon, size: 12, color: Theme.inkSoft)
                    } else {
                        Circle().fill(Theme.inkSoft).frame(width: 5, height: 5)
                    }
                }
                .frame(width: 25, height: 24)
                .background(Color.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(HecJourneySheet.PressOpacityStyle(pressed: 0.65))
            .accessibilityLabel(shortcut.label)
        }
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
                    IonIcon(name: "chevron-up", size: 14, color: Theme.ink)
                }
                Text(isSecondYear ? HecJourneyCopy.previousYearButton : HecJourneyCopy.nextYearButton)
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink)
                if isSecondYear {
                    IonIcon(name: "chevron-down", size: 14, color: Theme.ink)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(HecJourneySheet.PressOpacityStyle(pressed: 0.65))
        .accessibilityLabel(isSecondYear ? HecJourneyCopy.a11yPreviousYear : HecJourneyCopy.a11yNextYear)
    }
}
