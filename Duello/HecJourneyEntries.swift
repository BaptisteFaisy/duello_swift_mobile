import Foundation

/// Opérations sur la liste d'entrées de la frise : insertion ordonnée,
/// ajout, retrait, libération d'un emplacement et affectation d'un bloc à un
/// emplacement neutre.
///
/// Porté de `src/utils/hecJourneyTimeline.ts` — `compareHecJourneyEntries`,
/// `insertHecJourneyEntry`, `addHecJourneyEntry`, `removeHecJourneyEntry`,
/// `releaseHecJourneyBlock`, `assignHecJourneyEntryToNeutralBlock`,
/// `isNeutralSlotId` — et de `createEntryId` de
/// `src/components/HecJourney.tsx`.
enum HecJourneyEntries {

    /// `createEntryId` : `<type>-<horodatage base 36>-<suffixe>`.
    static func createId(_ type: HecJourneyBlockType) -> String {
        let stamp = String(UInt64(Date().timeIntervalSince1970 * 1000), radix: 36)
        let suffix = String(UInt32.random(in: 0..<UInt32.max), radix: 36)
        return "\(type.rawValue)-\(stamp)-\(suffix.prefix(6))"
    }

    /// `compareHecJourneyEntries` : date croissante, puis identifiant.
    static func compare(_ left: HecJourneyEntry, _ right: HecJourneyEntry) -> Bool {
        if left.createdAt == right.createdAt { return left.id < right.id }
        return left.createdAt < right.createdAt
    }

    /// `insertHecJourneyEntry` : insertion dichotomique quand la liste est
    /// déjà ordonnée, tri complet sinon.
    static func insert(_ entry: HecJourneyEntry, into entries: [HecJourneyEntry]) -> [HecJourneyEntry] {
        guard isSorted(entries) else {
            return (entries + [entry]).sorted(by: compare)
        }
        var lower = 0
        var upper = entries.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if compare(entries[middle], entry) { lower = middle + 1 } else { upper = middle }
        }
        var next = entries
        next.insert(entry, at: lower)
        return next
    }

    /// `addHecJourneyEntry` : refuse un doublon d'identifiant ou de chapitre.
    static func add(_ entry: HecJourneyEntry, to entries: [HecJourneyEntry]) -> [HecJourneyEntry] {
        let exists = entries.contains { existing in
            existing.id == entry.id
                || (entry.chapterId != nil && existing.chapterId == entry.chapterId)
        }
        return exists ? entries : insert(entry, into: entries)
    }

    /// `removeHecJourneyEntry`.
    static func remove(_ id: String, from entries: [HecJourneyEntry]) -> [HecJourneyEntry] {
        entries.filter { $0.id != id }
    }

    /// `releaseHecJourneyBlock` : supprimer un vrai bloc libère son emplacement
    /// au lieu de raccourcir le parcours.
    static func release(_ id: String, in entries: [HecJourneyEntry]) -> [HecJourneyEntry] {
        entries.map { entry in
            guard entry.id == id else { return entry }
            return HecJourneyEntry(
                id: entry.id,
                type: .neutral,
                title: HecJourneyBlocks.label(.neutral),
                createdAt: entry.createdAt
            )
        }
    }

    /// `assignHecJourneyEntryToNeutralBlock` : un jalon prend l'emplacement
    /// neutre choisi, ou le premier libre après le dernier vrai bloc ; un
    /// repère d'évaluation reste indépendant.
    static func assign(
        _ entry: HecJourneyEntry,
        in entries: [HecJourneyEntry],
        preferredNeutralId: String?
    ) -> (entries: [HecJourneyEntry], assigned: HecJourneyEntry) {
        var existing: HecJourneyEntry?
        var preferredNeutralIndex = -1
        var lastRealIndex = -1

        for (index, candidate) in entries.enumerated() {
            if existing == nil,
               candidate.id == entry.id
                   || (entry.chapterId != nil && candidate.chapterId == entry.chapterId) {
                existing = candidate
            }
            if preferredNeutralIndex < 0,
               let preferredNeutralId,
               candidate.id == preferredNeutralId,
               candidate.type == .neutral {
                preferredNeutralIndex = index
            }
            if candidate.type != .neutral { lastRealIndex = index }
        }

        if let existing {
            return (entries, existing)
        }
        if HecJourneyBlocks.isAssessment(entry.type) {
            return (insert(entry, into: entries), entry)
        }

        let neutralIndex: Int
        if preferredNeutralIndex >= 0 {
            neutralIndex = preferredNeutralIndex
        } else if lastRealIndex + 1 < entries.count {
            neutralIndex = lastRealIndex + 1
        } else {
            neutralIndex = -1
        }
        guard neutralIndex >= 0 else {
            return (insert(entry, into: entries), entry)
        }

        let assigned = HecJourneyEntry(
            id: entries[neutralIndex].id,
            type: entry.type,
            title: entry.title,
            createdAt: entry.createdAt,
            chapterId: entry.chapterId
        )
        var next = entries
        next.remove(at: neutralIndex)
        return (insert(assigned, into: next), assigned)
    }

    /// `isNeutralSlotId` : `neutral-v1-07`, `neutral-v2-31`…
    static func isNeutralSlotId(_ id: String) -> Bool {
        let parts = id.split(separator: "-")
        guard parts.count == 3, parts[0] == "neutral" else { return false }
        guard parts[1] == "v1" || parts[1] == "v2" else { return false }
        guard parts[2].count == 2, parts[2].allSatisfy({ $0.isNumber }) else { return false }
        return true
    }

    /// Vérifie l'ordre croissant sans trier, comme la source.
    private static func isSorted(_ entries: [HecJourneyEntry]) -> Bool {
        guard entries.count > 1 else { return true }
        for index in 1..<entries.count where compare(entries[index], entries[index - 1]) {
            return false
        }
        return true
    }
}
