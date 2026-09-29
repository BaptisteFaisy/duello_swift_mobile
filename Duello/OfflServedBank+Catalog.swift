//
//  OfflServedBank+Catalog.swift
//  Duello
//
//  Catalogue par chapitre d'une banque servie séparément.
//
//  Fichier source Expo porté : `src/content/servedBank.ts`
//  (`servedExerciseCatalog` et ses deux constructeurs internes
//  `fromEmbeddedIndex` / `fromServedBank`).
//
//  Le socle embarqué ne porte que les premiers chapitres du programme : compter
//  sur lui ferait annoncer « 0 exercice » sur tous les autres jusqu'à la fin du
//  téléchargement. L'index embarqué décrit la banque entière sans ses énoncés —
//  il donne donc le décompte définitif dès le premier rendu, y compris hors
//  ligne.
//
//  Fichier séparé pour tenir le budget de fonctions de `OfflServedBank.swift`
//  (ratchet ≤ 10 fonctions par fichier).
//
//  Cible : iOS 16.
//
import Foundation

extension OfflServedBank {

    /// `servedExerciseCatalog` : catalogue par chapitre d'une banque d'énoncés.
    /// Le cache local peut dater de la publication précédente : il complète le
    /// catalogue embarqué sans jamais faire baisser son total.
    static func servedExerciseCatalog(
        _ id: OfflContentBundleId,
        bank: @escaping () -> [String: [OfflExerciseSeed]],
        embeddedItems: [OfflExerciseCatalogItem],
        embeddedSolutionCounts: [String: Int],
        hasSolution: @escaping (OfflExerciseSeed) -> Bool = {
            !($0.solution ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        },
        includeEntry: @escaping (OfflExerciseSeed) -> Bool = { _ in true }
    ) -> () -> [String: OfflExerciseCatalogChapter] {
        let embedded = embeddedIndex(
            items: embeddedItems,
            solutionCounts: embeddedSolutionCounts
        )
        var memo: (revision: Int, catalog: [String: OfflExerciseCatalogChapter])?
        return {
            let revision = OfflSync.contentRevision
            if let memo, memo.revision == revision { return memo.catalog }
            let raw = OfflSync.bundles[id].flatMap { OfflContentJSON.array($0.serialized) }
            let hasValidServedBank = raw?.contains { OfflServedSeeds.isExerciseSeed($0) != nil } ?? false
            let catalog = hasValidServedBank
                ? servedCatalog(
                    from: embedded,
                    bank: bank(),
                    hasSolution: hasSolution,
                    includeEntry: includeEntry
                )
                : embedded
            memo = (revision, catalog)
            return catalog
        }
    }

    /// `fromEmbeddedIndex` : catalogue déduit de l'index embarqué, sans construire
    /// un seul énoncé.
    private static func embeddedIndex(
        items: [OfflExerciseCatalogItem],
        solutionCounts: [String: Int]
    ) -> [String: OfflExerciseCatalogChapter] {
        var catalog: [String: OfflExerciseCatalogChapter] = [:]
        for item in items {
            var chapter = catalog[item.chapterId] ?? OfflExerciseCatalogChapter(
                itemIds: [], items: [], withSolution: solutionCounts[item.chapterId] ?? 0
            )
            chapter.itemIds.append(item.id)
            chapter.items.append(item)
            catalog[item.chapterId] = chapter
        }
        return catalog
    }

    /// `fromServedBank` : catalogue embarqué complété par la banque servie, le
    /// décompte des corrigés ne pouvant que monter.
    private static func servedCatalog(
        from embedded: [String: OfflExerciseCatalogChapter],
        bank: [String: [OfflExerciseSeed]],
        hasSolution: (OfflExerciseSeed) -> Bool,
        includeEntry: (OfflExerciseSeed) -> Bool
    ) -> [String: OfflExerciseCatalogChapter] {
        var catalog = embedded
        for (chapterId, seeds) in bank {
            let included = seeds.filter(includeEntry)
            var chapter = catalog[chapterId]
                ?? OfflExerciseCatalogChapter(itemIds: [], items: [], withSolution: 0)
            var knownIds = Set(chapter.itemIds)
            var indexById = Dictionary(
                uniqueKeysWithValues: chapter.items.enumerated().map { ($0.element.id, $0.offset) }
            )
            for seed in included {
                let itemId = "\(seed.chapterId)::exercice::\(seed.key)"
                if knownIds.insert(itemId).inserted { chapter.itemIds.append(itemId) }
                let item = OfflExerciseCatalogItem(
                    id: itemId,
                    chapterId: seed.chapterId,
                    title: seed.title,
                    difficulty: seed.difficulty,
                    notions: seed.notions,
                    badges: seed.badges,
                    roles: seed.roles
                )
                if let position = indexById[itemId] {
                    chapter.items[position] = item
                } else {
                    indexById[itemId] = chapter.items.count
                    chapter.items.append(item)
                }
            }
            chapter.withSolution = max(chapter.withSolution, included.filter(hasSolution).count)
            catalog[chapterId] = chapter
        }
        return catalog
    }
}
