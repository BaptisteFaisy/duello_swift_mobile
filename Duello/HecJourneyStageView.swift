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
            if showsTopYearSwitch {
                // `nextYearButtonTop` : `top: 54`.
                HecJourneyYearSwitchButton(isSecondYear: false) { onSelectYear(2) }
                    .padding(.top, 54)
            }
            bottomLayers
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

    /// Les commandes du bas (`bottom: 17`) et la bascule de 1re année
    /// (`nextYearButtonBottom` : `bottom: 55`) restent deux couches distinctes,
    /// comme la source.
    @ViewBuilder
    private var bottomLayers: some View {
        if showsBottomYearSwitch {
            HecJourneyYearSwitchButton(isSecondYear: true) { onSelectYear(1) }
                .padding(.bottom, 55)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        if flow.panel == nil {
            HecJourneyBottomControls(
                shortcut: shortcut,
                onAdd: onAddBlock,
                onShortcut: onShortcut
            )
            .padding(.bottom, 17)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: Feuille d'ajout

    @ViewBuilder
    private var sheetLayer: some View {
        if flow.panel != nil {
            ZStack(alignment: .bottom) {
                // `panelBackdrop` : `rgba(0,0,0,0.08)`.
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { flow.close() }
                    .accessibilityLabel(HecJourneyCopy.a11yCloseAdd)
                HecJourneyAddPanelView(
                    flow: flow,
                    chapters: chapters,
                    registeredAt: registeredAt
                )
                // `addPanel` : `left: 30`, `right: 30`, `bottom: 18`.
                .padding(.horizontal, 30)
                .padding(.bottom, 18)
            }
        }
    }
}
