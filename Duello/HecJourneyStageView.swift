import SwiftUI

/// Scène du parcours : la frise, le titre, les commandes et la feuille d'ajout.
///
/// Porté de la vue de `src/components/HecJourney.tsx` — `sceneViewport`,
/// `titleRow`, `nextYearButton`, `bottomControls` et `addPanel` — à ceci près
/// que la surface OpenGL est remplacée par `HecJourneySceneView`.
struct HecJourneyStageView: View {
    let model: HecJourneySceneModel
    let programYear: Int
    let activeIndex: Int
    @Binding var scrollOffset: CGFloat
    @ObservedObject var flow: HecJourneyAddFlow
    let chapters: [HecJourneyChapter]
    let registeredAt: Date
    let shortcut: HecJourneyShortcut
    let onSelectNode: (Int) -> Void
    let onActiveIndexChange: (Int) -> Void
    let onAddBlock: () -> Void
    let onShortcut: () -> Void
    let onSelectYear: (Int) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            HecJourneySceneView(
                blocks: model.blocks,
                positions: model.positions,
                activeIndex: activeIndex,
                currentBlockIndex: model.currentBlockIndex,
                scrollOffset: $scrollOffset,
                onSelectNode: onSelectNode,
                onActiveIndexChange: onActiveIndexChange
            )
            HecJourneyTitleRow(block: model.activeBlock(at: activeIndex))
                .padding(.top, 7)
            if showsTopYearSwitch {
                HecJourneyYearSwitchButton(isSecondYear: false) { onSelectYear(2) }
                    .padding(.top, 54)
            }
            bottomStack
            sheetLayer
        }
    }

    // MARK: Commandes

    /// En fin de 1re année, la source propose de monter vers la 2e.
    private var showsTopYearSwitch: Bool {
        programYear == 1 && flow.panel == nil && activeIndex == model.blocks.count - 1
    }

    /// Au début de la 2e année, elle propose de redescendre en 1re.
    private var showsBottomYearSwitch: Bool {
        programYear == 2 && flow.panel == nil && activeIndex == 0
    }

    private var bottomStack: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            if showsBottomYearSwitch {
                HecJourneyYearSwitchButton(isSecondYear: true) { onSelectYear(1) }
            }
            if flow.panel == nil {
                HecJourneyBottomControls(
                    shortcut: shortcut,
                    onAdd: onAddBlock,
                    onShortcut: onShortcut
                )
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: Feuille d'ajout

    @ViewBuilder
    private var sheetLayer: some View {
        if flow.panel != nil {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { flow.close() }
                    .accessibilityLabel(HecJourneyCopy.a11yCloseAdd)
                HecJourneyAddPanelView(
                    flow: flow,
                    chapters: chapters,
                    registeredAt: registeredAt
                )
                .frame(maxWidth: 420)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .transition(.opacity)
        }
    }
}
