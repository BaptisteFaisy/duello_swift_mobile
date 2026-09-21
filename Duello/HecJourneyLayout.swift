import Foundation

/// Disposition des blocs le long de la frise : positions continues (une unité
/// vaut une semaine) et repérage du bloc courant.
///
/// Porté de `src/utils/hecJourneyTimeline.ts` — `hecJourneyTimelinePositions`,
/// `hecJourneyScenePositions`, `hecJourneyPositionAtIndex` et
/// `hecJourneyCurrentBlockIndex`. Le `hecJourneyTimelineDatePosition` et le
/// `maximumPosition` de la source n'ont pas de consommateur ici : la frise 2D
/// ne dessine que les crans visibles, sans piste mesurée ni plan lointain.
enum HecJourneyLayout {

    /// `hecJourneyTimelinePositions` : une unité de profondeur vaut une
    /// semaine, avec un écart minimal entre deux blocs du même jour.
    static func timelinePositions(
        registeredAt: Date,
        dates: [Date],
        maximumBlockGap: Double = .infinity
    ) -> [Double] {
        let origin = HecJourneyDates.normalize(registeredAt, registeredAt: registeredAt)
        var positions = [Double](repeating: 0, count: dates.count + 1)
        var previous: Double = 0
        for (index, date) in dates.enumerated() {
            let normalized = HecJourneyDates.normalize(date, registeredAt: origin)
            let weeks = max(0, normalized.timeIntervalSince(origin) / HecJourneyDates.dayInterval / 7)
            let datePosition = min(weeks, previous + maximumBlockGap)
            previous = max(datePosition, previous + HecJourneyTimelineConstants.minimumBlockGap)
            positions[index + 1] = previous
        }
        return positions
    }

    /// `hecJourneyScenePositions` : les jalons principaux portent la frise, les
    /// colles, DS et interrogations s'intercalent entre eux ; une position
    /// finale peut rester ancrée au bout de la frise.
    static func scenePositions(
        blocks: [HecJourneySceneBlock],
        maximumBlockGap: Double = .infinity,
        finalPosition: Double? = nil
    ) -> [Double] {
        guard !blocks.isEmpty else { return [] }
        let mainIndexes = blocks.indices.filter { !blocks[$0].type.isAssessment }
        guard let firstMain = mainIndexes.first else {
            return blocks.map { _ in 0 }
        }

        var mainPositions = timelinePositions(
            registeredAt: blocks[firstMain].createdAt,
            dates: mainIndexes.dropFirst().map { blocks[$0].createdAt },
            maximumBlockGap: maximumBlockGap
        )
        if let finalPosition, mainPositions.count > 1 {
            let last = mainPositions.count - 1
            mainPositions[last] = max(
                finalPosition,
                mainPositions[last - 1] + HecJourneyTimelineConstants.minimumBlockGap
            )
        }
        return spread(blocks: blocks, mainIndexes: mainIndexes, mainPositions: mainPositions)
    }

    /// `hecJourneyPositionAtIndex` : interpolation linéaire entre deux crans.
    static func position(atIndex index: Double, positions: [Double]) -> Double {
        guard !positions.isEmpty else { return 0 }
        let bounded = max(0, min(Double(positions.count - 1), index))
        let lower = Int(floor(bounded))
        let upper = min(positions.count - 1, lower + 1)
        let fraction = bounded - Double(lower)
        return positions[lower] + (positions[upper] - positions[lower]) * fraction
    }

    /// `hecJourneyCurrentBlockIndex` : dernier jalon principal déjà daté.
    /// Les emplacements neutres, les repères latéraux et le blason final ne
    /// déplacent pas le bloc courant.
    static func currentBlockIndex(blocks: [HecJourneySceneBlock], now: Date = Date()) -> Int {
        let today = HecJourneyDates.startOfLocalDay(now)
        var latest = -1
        for (index, block) in blocks.enumerated() {
            guard block.type != .admission else { continue }
            if let type = block.type.blockType {
                guard type != .neutral, !HecJourneyBlocks.isAssessment(type) else { continue }
            }
            if block.createdAt <= today { latest = index }
        }
        return latest
    }

    /// Interpole la position des repères latéraux entre les deux jalons qui
    /// les encadrent, sans jamais déplacer ces jalons.
    private static func spread(
        blocks: [HecJourneySceneBlock],
        mainIndexes: [Int],
        mainPositions: [Double]
    ) -> [Double] {
        var positions = [Double](repeating: 0, count: blocks.count)
        var mainPositionIndex = 0
        for index in blocks.indices {
            if mainPositionIndex < mainIndexes.count, mainIndexes[mainPositionIndex] == index {
                positions[index] = mainPositions[mainPositionIndex]
                mainPositionIndex += 1
                continue
            }
            positions[index] = branchPosition(
                block: blocks[index],
                blocks: blocks,
                mainIndexes: mainIndexes,
                mainPositions: mainPositions,
                nextMainIndex: min(mainPositionIndex, mainIndexes.count - 1)
            )
        }
        return positions
    }

    /// Position d'un bloc intercalé, proportionnelle à sa date entre le jalon
    /// précédent et le suivant.
    private static func branchPosition(
        block: HecJourneySceneBlock,
        blocks: [HecJourneySceneBlock],
        mainIndexes: [Int],
        mainPositions: [Double],
        nextMainIndex: Int
    ) -> Double {
        let nextIndex = min(nextMainIndex, mainIndexes.count - 1)
        let nextBlock = blocks[mainIndexes[nextIndex]]
        let previousIndex = nextBlock.createdAt == block.createdAt ? nextIndex : max(0, nextIndex - 1)
        let previousBlock = blocks[mainIndexes[previousIndex]]
        let previousPosition = mainPositions[previousIndex]
        let nextPosition = mainPositions[nextIndex]

        let span = nextBlock.createdAt.timeIntervalSince(previousBlock.createdAt)
        guard span > 0 else { return previousPosition }
        let fraction = max(0, min(1, block.createdAt.timeIntervalSince(previousBlock.createdAt) / span))
        return previousPosition + (nextPosition - previousPosition) * fraction
    }
}
