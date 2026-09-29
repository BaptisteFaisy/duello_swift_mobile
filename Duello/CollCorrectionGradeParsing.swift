//
//  CollCorrectionGradeParsing.swift
//  Duello
//
//  Lecture tolérante du journal des notes (`utils/correctionGradeHistory.ts`) :
//  une note illisible est écartée seule, jamais tout le journal.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/correctionGradeHistory.ts
//        `cleanText`, `cleanScore`, `cleanTimestamp`, `cleanItemIds`,
//        `normalizeCorrectionGradeEntry`, `parseCorrectionGradeHistory`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Lecture d'une note (`normalizeCorrectionGradeEntry`, `parse…`).
enum CollCorrectionGradeParsing {
    /// Bornes de nettoyage des textes (`cleanText`).
    private static let subjectLimit = 120
    private static let titleLimit = 240
    private static let idLimit = 300
    private static let itemIdLimit = 240

    /// `normalizeCorrectionGradeEntry` : lit une entrée déjà typée et écarte
    /// tout champ hors bornes (identifiant vide, note hors `[0, 20]`…).
    static func normalizeEntry(
        _ value: CollCorrectionGradeEntry
    ) -> CollCorrectionGradeEntry? {
        guard let id = cleanText(value.id, limit: idLimit),
              let score = cleanScore(value.score),
              let submittedAt = cleanTimestamp(value.submittedAt)
        else { return nil }
        return CollCorrectionGradeEntry(
            id: id,
            activity: value.activity,
            score: score,
            submittedAt: submittedAt,
            subject: cleanText(value.subject, limit: subjectLimit),
            title: cleanText(value.title, limit: titleLimit),
            itemIds: cleanItemIds(value.itemIds)
        )
    }

    /// `normalizeCorrectionGradeEntry` sur une valeur JSON brute.
    static func normalizeRaw(_ value: Any?) -> CollCorrectionGradeEntry? {
        guard let object = value as? [String: Any],
              let id = cleanText(object["id"] as? String, limit: idLimit),
              let activity = CollCorrectionActivity(rawValue: (object["activity"] as? String) ?? ""),
              let score = cleanScore(rawNumber(object["score"])),
              let submittedAt = cleanTimestamp(timestamp(object["submittedAt"]))
        else { return nil }
        let rawItemIds = (object["itemIds"] as? [Any])?.compactMap { $0 as? String } ?? []
        return CollCorrectionGradeEntry(
            id: id,
            activity: activity,
            score: score,
            submittedAt: submittedAt,
            subject: cleanText(object["subject"] as? String, limit: subjectLimit),
            title: cleanText(object["title"] as? String, limit: titleLimit),
            itemIds: cleanItemIds(rawItemIds)
        )
    }

    /// `parseCorrectionGradeHistory` : un journal illisible repart à vide.
    static func parse(_ raw: String?) -> [CollCorrectionGradeEntry] {
        guard let raw, let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let array = parsed as? [Any]
        else { return [] }
        return CollCorrectionGrades.merge(array.compactMap { normalizeRaw($0) }.map { [$0] })
    }

    // MARK: Nettoyage des champs

    /// `cleanText` : texte coupé à `limit`, `nil` quand il est vide.
    private static func cleanText(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let cleaned = String(
            value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit)
        )
        return cleaned.isEmpty ? nil : cleaned
    }

    /// `cleanScore` : note finie dans `[0, 20]`, arrondie au dixième.
    private static func cleanScore(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0, value <= 20 else { return nil }
        return (value * 10).rounded() / 10
    }

    /// `cleanTimestamp` : instant positif, en millisecondes.
    private static func cleanTimestamp(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// `cleanItemIds` : identifiants nettoyés, dédoublonnés, ordre conservé.
    private static func cleanItemIds(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for value in values {
            guard let cleaned = cleanText(value, limit: itemIdLimit) else { continue }
            if seen.insert(cleaned).inserted { out.append(cleaned) }
        }
        return out
    }

    // MARK: Lecture JSON brute

    /// Nombre brut, quel que soit le type numérique (`NSNumber` bridgé).
    private static func rawNumber(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return value as? Double
    }

    /// `cleanTimestamp` d'une valeur JSON : nombre ou date ISO 8601.
    private static func timestamp(_ value: Any?) -> Double? {
        if let number = rawNumber(value) { return number }
        guard let raw = value as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date.timeIntervalSince1970 * 1000 }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw).map { $0.timeIntervalSince1970 * 1000 }
    }
}
