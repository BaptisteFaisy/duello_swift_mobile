import Foundation

/// Graine des emplacements neutres de la frise : 32 emplacements hebdomadaires
/// sur l'année, et migration des anciennes versions.
///
/// Porté de `src/utils/hecJourneyTimeline.ts` — `seedHecJourneyNeutralBlocks`,
/// `migratePreexistingEntries`, `restoreNeutralSlot`, `neutralEntryAtIndex`,
/// `HEC_JOURNEY_NEUTRAL_BLOCK_COUNT`, `HEC_JOURNEY_NEUTRAL_V1_COUNT`,
/// `HEC_JOURNEY_NEUTRAL_V2_COUNT`.
///
/// La version 3 retire les attributions créées par les anciennes graines (les
/// colles et les DS redeviennent des repères indépendants) et la version 4
/// replace les emplacements restants sur la grille hebdomadaire.
enum HecJourneySeeding {

    /// `seedHecJourneyNeutralBlocks`.
    static func seed(
        entries: [HecJourneyEntry],
        registeredAt: Date,
        now: Date = Date(),
        previousSeedVersion: Int = 0,
        timelineEndAt: Date? = nil
    ) -> [HecJourneyEntry] {
        let migrated = migratePreexisting(entries, previousSeedVersion: previousSeedVersion)
        let start = HecJourneyDates.normalize(registeredAt, registeredAt: registeredAt)
        let today = HecJourneyDates.normalize(max(start, now), registeredAt: registeredAt)
        let end = timelineEnd(timelineEndAt, start: start, today: today)
        let elapsedDays = max(0, Int(floor(end.timeIntervalSince(start) / HecJourneyDates.dayInterval)))

        let firstIndex: Int
        if previousSeedVersion >= 2 {
            firstIndex = HecJourneyTimelineConstants.neutralV2Count
        } else if previousSeedVersion >= 1 {
            firstIndex = HecJourneyTimelineConstants.neutralV1Count
        } else {
            firstIndex = 0
        }

        let repositioned = migrated.map { entry -> HecJourneyEntry in
            guard previousSeedVersion == 3, entry.type == .neutral, HecJourneyEntries.isNeutralSlotId(entry.id)
            else { return entry }
            guard let slot = Int(entry.id.suffix(2)), slot >= 1, slot <= HecJourneyTimelineConstants.neutralBlockCount
            else { return entry }
            return neutralEntry(at: slot - 1, start: start, elapsedDays: elapsedDays)
        }

        let neutralEntries = (firstIndex..<HecJourneyTimelineConstants.neutralBlockCount)
            .map { neutralEntry(at: $0, start: start, elapsedDays: elapsedDays) }

        var identifiers = Set<String>()
        return (repositioned + neutralEntries)
            .filter { identifiers.insert($0.id).inserted }
            .sorted(by: HecJourneyEntries.compare)
    }

    /// `migratePreexistingEntries` : la version 3 rend neutres les
    /// emplacements occupés par un vrai bloc et détache les repères qui y
    /// étaient rattachés.
    static func migratePreexisting(_ entries: [HecJourneyEntry], previousSeedVersion: Int) -> [HecJourneyEntry] {
        guard previousSeedVersion < 3 else { return entries }
        var migrated: [HecJourneyEntry] = []
        for entry in entries {
            if entry.type == .neutral {
                migrated.append(entry)
                continue
            }
            if HecJourneyBlocks.isAssessment(entry.type) {
                guard HecJourneyEntries.isNeutralSlotId(entry.id) else {
                    migrated.append(entry)
                    continue
                }
                migrated.append(restoreNeutralSlot(entry))
                migrated.append(
                    HecJourneyEntry(
                        id: "assessment-\(entry.type.rawValue)-\(entry.id)",
                        type: entry.type,
                        title: entry.title,
                        createdAt: entry.createdAt
                    )
                )
                continue
            }
            if HecJourneyEntries.isNeutralSlotId(entry.id) {
                migrated.append(restoreNeutralSlot(entry))
            }
        }
        return migrated
    }

    /// `restoreNeutralSlot`.
    static func restoreNeutralSlot(_ entry: HecJourneyEntry) -> HecJourneyEntry {
        HecJourneyEntry(
            id: entry.id,
            type: .neutral,
            title: HecJourneyBlocks.label(.neutral),
            createdAt: entry.createdAt
        )
    }

    /// `neutralEntryAtIndex` : `neutral-v1-01` … `neutral-v2-32`, répartis
    /// uniformément sur les jours écoulés.
    static func neutralEntry(at index: Int, start: Date, elapsedDays: Int) -> HecJourneyEntry {
        let number = index + 1
        let prefix = index < HecJourneyTimelineConstants.neutralV1Count ? "neutral-v1" : "neutral-v2"
        let offset = Int(
            (
                Double(number) * Double(elapsedDays)
                    / Double(HecJourneyTimelineConstants.neutralBlockCount)
            ).rounded()
        )
        return HecJourneyEntry(
            id: "\(prefix)-\(String(format: "%02d", number))",
            type: .neutral,
            title: HecJourneyBlocks.label(.neutral),
            createdAt: start.addingTimeInterval(Double(offset) * HecJourneyDates.dayInterval)
        )
    }

    /// Fin de l'année de la frise : la date de fin fournie quand elle est
    /// valide, sinon 32 semaines après aujourd'hui.
    private static func timelineEnd(_ timelineEndAt: Date?, start: Date, today: Date) -> Date {
        if let timelineEndAt, HecJourneyDates.isUsable(timelineEndAt) {
            return max(start, HecJourneyDates.startOfLocalDay(timelineEndAt))
        }
        let weeks = Double(HecJourneyTimelineConstants.neutralBlockCount) * 7 * HecJourneyDates.dayInterval
        return today.addingTimeInterval(weeks)
    }
}
