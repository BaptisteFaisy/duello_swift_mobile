//
//  OfflServedBank.swift
//  Duello
//
//  Adaptation d'une banque embarquée en banque servie séparément.
//
//  Fichier source Expo porté : `src/content/servedBank.ts`
//  (`servedList`, `servedChapterBank`, `servedChapterEntries`, `servedRecord`,
//  `servedTextRecord`, `servedExerciseBank`, `groupByChapter`, `mergeEntries`).
//
//  Le même mécanisme vaut pour toutes les banques : la version embarquée est le
//  socle, la version distante la recouvre une fois validée, et la banque dérivée
//  se recalcule uniquement quand la révision de contenu change. Le contrôle de
//  forme (`isEntry`) appartient à l'appelant, qui seul connaît son modèle exact.
//
//  La source manipule des `unknown` et des type guards ; le portage expose les
//  mêmes gardes sous forme de conversions (`(Any) -> T?`), la matière d'une
//  entrée restant lue par l'appelant (`chapterId` / `identity`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Banques servies séparément (`servedBank.ts`).
enum OfflServedBank {

    /// `groupByChapter` : range des entrées par identifiant de chapitre.
    static func groupByChapter<T>(
        _ seeds: [T],
        chapterId: (T) -> String
    ) -> [String: [T]] {
        var bank: [String: [T]] = [:]
        for seed in seeds { bank[chapterId(seed), default: []].append(seed) }
        return bank
    }

    /// `servedList` : une liste servie remplace la liste embarquée dès qu'elle
    /// contient au moins une entrée valide, sinon les entrées ciblées la
    /// complètent.
    static func servedList<T>(
        _ id: OfflContentBundleId,
        embedded: [T],
        isEntry: @escaping (Any) -> T?,
        identity: @escaping (T) -> String? = { _ in nil }
    ) -> () -> [T] {
        var memo: (revision: Int, entries: [T])?
        return {
            let revision = OfflSync.servedBanksRevision
            if let memo, memo.revision == revision { return memo.entries }
            let served = bundleRaw(id)?.compactMap(isEntry)
            let partial = partialRaw(id).compactMap(isEntry)
            let entries: [T]
            if let served, !served.isEmpty {
                entries = served
            } else {
                entries = mergeEntries(embedded, partial, identity: identity)
            }
            memo = (revision, entries)
            return entries
        }
    }

    /// `servedChapterBank` : liste servie remise sous la forme attendue par les
    /// écrans, chapitre par chapitre.
    static func servedChapterBank<T>(
        _ id: OfflContentBundleId,
        embedded: [T],
        isEntry: @escaping (Any) -> T?,
        chapterId: @escaping (T) -> String,
        identity: @escaping (T) -> String? = { _ in nil }
    ) -> () -> [String: [T]] {
        let entries = servedList(id, embedded: embedded, isEntry: isEntry, identity: identity)
        var memo: (revision: Int, bank: [String: [T]])?
        return {
            let revision = OfflSync.servedBanksRevision
            if let memo, memo.revision == revision { return memo.bank }
            let bank = groupByChapter(entries(), chapterId: chapterId)
            memo = (revision, bank)
            return bank
        }
    }

    /// `servedChapterEntries` : variante ciblée pour un écran qui n'ouvre qu'un
    /// chapitre. Une banque complète déjà téléchargée reste l'autorité.
    static func servedChapterEntries<T>(
        _ id: OfflContentBundleId,
        embeddedChapter: @escaping (String) -> [T],
        isEntry: @escaping (Any) -> T?,
        chapterId: @escaping (T) -> String,
        identity: @escaping (T) -> String? = { _ in nil }
    ) -> (String) -> [T] {
        var memo: (revision: Int, served: [String: [T]]?, partial: [String: [T]])?
        return { requested in
            let revision = OfflSync.servedBanksRevision
            if memo?.revision != revision {
                let servedEntries = bundleRaw(id)?.compactMap(isEntry)
                let served = (servedEntries?.isEmpty == false)
                    ? groupByChapter(servedEntries ?? [], chapterId: chapterId)
                    : nil
                let partial = groupByChapter(partialRaw(id).compactMap(isEntry), chapterId: chapterId)
                memo = (revision, served, partial)
            }
            guard let memo else { return embeddedChapter(requested) }
            if let served = memo.served { return served[requested] ?? [] }
            return mergeEntries(embeddedChapter(requested), memo.partial[requested] ?? [], identity: identity)
        }
    }

    /// `servedRecord` : banque servie en table (`[clé, valeur]`), remplacée par
    /// la version distante dès qu'elle porte au moins une paire valide.
    static func servedRecord<T>(
        _ id: OfflContentBundleId,
        embedded: [String: T],
        isValue: @escaping (Any) -> T?
    ) -> () -> [String: T] {
        var memo: (revision: Int, record: [String: T])?
        return {
            let revision = OfflSync.servedBanksRevision
            if let memo, memo.revision == revision { return memo.record }
            let served = recordPairs(bundleRaw(id), isValue: isValue)
            let partial = recordPairs(partialRaw(id), isValue: isValue) ?? [:]
            let record: [String: T]
            if let served, !served.isEmpty {
                record = served
            } else {
                record = embedded.merging(partial) { _, remote in remote }
            }
            memo = (revision, record)
            return record
        }
    }

    /// `servedTextRecord` : table de textes servie séparément.
    static func servedTextRecord(
        _ id: OfflContentBundleId,
        embedded: [String: String]
    ) -> () -> [String: String] {
        servedRecord(id, embedded: embedded, isValue: OfflServedSeeds.isFilledText)
    }

    /// `servedExerciseBank` : banque d'énoncés servie séparément, groupée par
    /// chapitre. Un sujet incomplet est écarté (`isExerciseSeed`).
    static func servedExerciseBank(
        _ id: OfflContentBundleId,
        embedded: [OfflExerciseSeed]
    ) -> () -> [String: [OfflExerciseSeed]] {
        let entries = servedList(
            id,
            embedded: embedded,
            isEntry: OfflServedSeeds.isExerciseSeed,
            identity: { "\($0.chapterId)::\($0.key)" }
        )
        var memo: (revision: Int, bank: [String: [OfflExerciseSeed]])?
        return {
            let revision = OfflSync.servedBanksRevision
            if let memo, memo.revision == revision { return memo.bank }
            let bank = groupByChapter(entries()) { $0.chapterId }
            memo = (revision, bank)
            return bank
        }
    }

    /// `mergeEntries` : recouvre les entrées embarquées par les entrées ciblées,
    /// par identité, sans réordonner le socle.
    private static func mergeEntries<T>(
        _ embedded: [T],
        _ partial: [T],
        identity: (T) -> String?
    ) -> [T] {
        if partial.isEmpty { return embedded }
        var merged = embedded
        var positions: [String: Int] = [:]
        for (index, entry) in merged.enumerated() {
            if let key = identity(entry) { positions[key] = index }
        }
        for entry in partial {
            let key = identity(entry)
            if let key, let position = positions[key] {
                merged[position] = entry
            } else {
                merged.append(entry)
                if let key { positions[key] = merged.count - 1 }
            }
        }
        return merged
    }
}
