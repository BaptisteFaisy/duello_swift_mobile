import Foundation

/// Lecture et écriture de la frise dans le stockage local.
///
/// Porté de `src/utils/hecJourneyTimeline.ts` — `sanitizeEntry`,
/// `parseHecJourneyTimelineState`, `serializeHecJourneyTimeline` — et des clés
/// de `src/storage/keys.ts` (`prepapp-hec-journey-timeline:v1`,
/// `prepapp-hec-journey-timeline:v2:<année>`).
///
/// La lecture passe par `JSONSerialization` plutôt que par un décodeur
/// synthétisé : la source valide et tronque **entrée par entrée** (identifiant
/// et titre non vides, type connu, `chapterId` obligatoire pour un chapitre,
/// doublons écartés) et une seule entrée abîmée ne doit pas faire tomber toute
/// la frise.
enum HecJourneyTimelineCodec {

    /// `parseHecJourneyTimelineState` : état vide dès que l'enveloppe est
    /// illisible ou d'une autre version de schéma.
    static func parse(_ raw: String?, registeredAt: Date) -> HecJourneyTimelineState {
        let empty = HecJourneyTimelineState(
            entries: [],
            neutralBlocksSeeded: false,
            neutralBlocksSeedVersion: 0
        )
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any],
              (payload["schemaVersion"] as? NSNumber)?.intValue == 1,
              let rawEntries = payload["entries"] as? [Any]
        else { return empty }

        var identifiers = Set<String>()
        var chapterIdentifiers = Set<String>()
        var entries: [HecJourneyEntry] = []
        for value in rawEntries {
            guard let entry = sanitize(value, registeredAt: registeredAt) else { continue }
            if identifiers.contains(entry.id) { continue }
            if let chapterId = entry.chapterId, chapterIdentifiers.contains(chapterId) { continue }
            identifiers.insert(entry.id)
            if let chapterId = entry.chapterId { chapterIdentifiers.insert(chapterId) }
            entries.append(entry)
        }
        entries.sort(by: HecJourneyEntries.compare)

        let seeded = payload["neutralBlocksSeeded"] as? Bool == true
        let version = (payload["neutralBlocksSeedVersion"] as? NSNumber)?.intValue
        return HecJourneyTimelineState(
            entries: entries,
            neutralBlocksSeeded: seeded,
            neutralBlocksSeedVersion: version.map { max(0, $0) } ?? (seeded ? 1 : 0)
        )
    }

    /// `serializeHecJourneyTimeline` : l'enveloppe complète, avec la version de
    /// graine courante.
    static func serialize(_ entries: [HecJourneyEntry]) -> String {
        let state = HecJourneyTimelineState(entries: entries)
        guard let data = try? JSONEncoder().encode(state),
              let text = String(data: data, encoding: .utf8)
        else { return "" }
        return text
    }

    /// `sanitizeEntry` : identifiant et titre bornés à 80 / 120 caractères,
    /// type connu, `chapterId` borné à 120 et obligatoire pour un chapitre,
    /// date ramenée au jour d'inscription au plus tôt.
    private static func sanitize(_ value: Any, registeredAt: Date) -> HecJourneyEntry? {
        guard let payload = value as? [String: Any] else { return nil }
        let id = trimmed(payload["id"] as? String, limit: 80)
        let title = trimmed(payload["title"] as? String, limit: 120)
        let chapterId = trimmed(payload["chapterId"] as? String, limit: 120)
        guard let type = (payload["type"] as? String).flatMap(HecJourneyBlockType.init(rawValue:)),
              !id.isEmpty,
              !title.isEmpty
        else { return nil }
        if type == .chapter && chapterId.isEmpty { return nil }

        let milliseconds = (payload["createdAt"] as? NSNumber)?.doubleValue
        let created = milliseconds.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        return HecJourneyEntry(
            id: id,
            type: type,
            title: title,
            createdAt: HecJourneyDates.normalize(created, registeredAt: registeredAt),
            chapterId: type == .chapter ? chapterId : nil
        )
    }

    private static func trimmed(_ value: String?, limit: Int) -> String {
        let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(limit))
    }
}
