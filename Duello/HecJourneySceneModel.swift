import Foundation

/// Frise prête à afficher : les blocs, leurs positions et le bloc courant.
///
/// Rassemble les `useMemo` de `src/components/HecJourney.tsx` — `blocks`,
/// `positions` et `currentBlockIndex` — pour que la vue n'ait plus qu'à les
/// lire.
///
/// Le `maximumPosition` de la source (longueur de la piste, plan lointain de la
/// caméra) n'a pas d'équivalent : la frise 2D ne dessine que les crans visibles
/// (`HecJourneyProjection.visibleIndices`).
struct HecJourneySceneModel {
    let blocks: [HecJourneySceneBlock]
    let positions: [Double]
    let currentBlockIndex: Int

    init(
        store: HecJourneyStore,
        programYear: Int,
        startingProgramYear: Int,
        courseStatus: HecJourneySceneBuilder.CourseStatusProvider
    ) {
        let builtBlocks = HecJourneySceneBuilder.blocks(
            entries: store.entries,
            admission: store.admission,
            programYear: programYear,
            startingProgramYear: startingProgramYear,
            registeredAt: store.registeredAt,
            timelineEndDate: store.timelineEndDate,
            courseStatus: courseStatus
        )
        let builtPositions = HecJourneySceneBuilder.positions(
            blocks: builtBlocks,
            programYear: programYear
        )
        self.blocks = builtBlocks
        self.positions = builtPositions
        self.currentBlockIndex = max(0, HecJourneyLayout.currentBlockIndex(blocks: builtBlocks))
    }

    /// Bloc d'un cran donné, borné aux extrémités de la frise.
    func activeBlock(at index: Int) -> HecJourneySceneBlock? {
        guard !blocks.isEmpty else { return nil }
        return blocks[max(0, min(blocks.count - 1, index))]
    }
}
