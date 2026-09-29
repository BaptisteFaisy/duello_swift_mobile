//
//  RankingSubjectXpStore.swift
//  Duello
//
//  Journal d'XP par matière : persistance et normalisation.
//
//  Fichier source Expo porté :
//    - src/utils/subjectXp.ts
//        `SubjectXpAward`, `SubjectXpLog`, `EMPTY_SUBJECT_XP`,
//        `isXpActivity`, `normalizeSubjectXp`, `loadSubjectXp`, `hasAward`,
//        `recordSubjectXp` et l'écriture sous la clé
//        `ACCOUNT_STORAGE_KEYS.subjectXp` (`prepapp-subject-xp:v1`).
//
//  Limite documentée : la source sérialise les écritures par compte via une
//  file (`logQueues`). Le store iOS est lié au fil principal et n'a qu'un
//  compte à la fois : la file n'est pas nécessaire, comme
//  `CollTrainingTimeStore`.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Points gagnés sur un sujet, une seule fois par sujet et par matière
/// (`SubjectXpAward`).
struct SubjectXpAward: Codable, Equatable {
    /// Lundi de la semaine où le sujet a été réussi, au format AAAA-MM-JJ.
    var week: String
    var subject: String
    var itemId: String
    var activity: CollTrainingActivity
    var xp: Int
}

/// Journal d'XP par matière (`SubjectXpLog`).
struct SubjectXpLog: Codable, Equatable {
    var version: Int = 1
    var awards: [SubjectXpAward] = []

    /// `EMPTY_SUBJECT_XP`.
    static let empty = SubjectXpLog()
}

/// Persistance et normalisation du journal d'XP par matière (`utils/subjectXp.ts`).
enum RankingSubjectXpStore {

    /// `ACCOUNT_STORAGE_KEYS.subjectXp`.
    static let storageKey = "prepapp-subject-xp:v1"

    /// `isXpActivity` : seule une activité classée compte.
    static func isXpActivity(_ activity: CollTrainingActivity) -> Bool {
        rankingXpActivities.contains(activity)
    }

    /// `normalizeSubjectXp` : une attribution par sujet et par matière, les
    /// semaines trop anciennes en moins. En cas de doublon, la première
    /// attribution (semaine la plus ancienne) est celle qui reste : un sujet
    /// refait garde la semaine de sa première réussite.
    static func normalize(_ log: SubjectXpLog, at date: Date = Date()) -> SubjectXpLog {
        let floor = RankingSubjectXp.retentionFloor(at: date)
        var kept: [String: SubjectXpAward] = [:]
        for award in log.awards {
            let subject = award.subject.trimmingCharacters(in: .whitespacesAndNewlines)
            let itemId = award.itemId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard award.xp > 0,
                  !subject.isEmpty,
                  !itemId.isEmpty,
                  isXpActivity(award.activity),
                  isWeekKey(award.week),
                  award.week >= floor
            else { continue }

            let key = "\(subject)::\(itemId)"
            if let existing = kept[key], existing.week <= award.week { continue }
            kept[key] = SubjectXpAward(
                week: award.week,
                subject: subject,
                itemId: itemId,
                activity: award.activity,
                xp: award.xp
            )
        }
        let sorted = kept.values.sorted { first, second in
            if first.week != second.week { return first.week < second.week }
            if first.subject != second.subject { return first.subject < second.subject }
            return first.itemId < second.itemId
        }
        return SubjectXpLog(version: 1, awards: sorted)
    }

    /// `loadSubjectXp` : un journal illisible ne doit pas empêcher de travailler,
    /// on repart à vide.
    static func load() -> SubjectXpLog {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let data = raw.data(using: .utf8),
              let log = try? JSONDecoder().decode(SubjectXpLog.self, from: data)
        else { return .empty }
        return normalize(log)
    }

    /// `hasAward` : vrai lorsque ce sujet a déjà rapporté ses points dans cette
    /// matière.
    static func hasAward(_ log: SubjectXpLog, subject: String, itemId: String) -> Bool {
        let wanted = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return log.awards.contains { $0.subject == wanted && $0.itemId == itemId }
    }

    /// `recordSubjectXp` : inscrit les points d'un sujet réussi et rend le
    /// journal à jour. Un sujet raté, un sujet déjà crédité ou une activité non
    /// classée laissent le journal intact.
    static func record(
        _ measure: RankingSubjectXp.Input,
        subject: String,
        itemId: String,
        at date: Date = Date()
    ) -> SubjectXpLog {
        let subjectValue = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemValue = itemId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isXpActivity(measure.activity) else { return load() }
        let xp = RankingSubjectXp.computeSubjectXp(measure)
        guard xp > 0, !subjectValue.isEmpty, !itemValue.isEmpty else { return load() }

        let current = load()
        if hasAward(current, subject: subjectValue, itemId: itemValue) { return current }

        let award = SubjectXpAward(
            week: WeeklyXP.weekKey(at: date),
            subject: subjectValue,
            itemId: itemValue,
            activity: measure.activity,
            xp: xp
        )
        let updated = normalize(
            SubjectXpLog(version: 1, awards: current.awards + [award]),
            at: date
        )
        persist(updated)
        return updated
    }

    /// Écriture du journal dans les préférences ; l'échec laisse le journal de
    /// la session en cours intact.
    private static func persist(_ log: SubjectXpLog) {
        guard let data = try? JSONEncoder().encode(log),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }

    /// Clé de semaine valide : `AAAA-MM-JJ` (garde-fou de `normalizeSubjectXp`).
    private static func isWeekKey(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2
        else { return false }
        return value.allSatisfy { $0.isNumber || $0 == "-" }
    }
}
