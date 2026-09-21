//
//  OfflBootstrap.swift
//  Duello
//
//  Démarrage du contenu servi séparément.
//
//  Fichier source Expo porté : `src/content/contentBootstrap.ts`
//  (`prepareContent`, `scheduleContentRefresh`, `downloadContentWithRetry`,
//  `downloadExerciseContent`, `downloadExerciseChapterContent`,
//  `downloadChapterContent`, `prefetchChapterContent`,
//  `prefetchChapterStatements`, `downloadExerciseSolution`).
//
//  `prepareContent` est volontairement court : il relit le cache local et rend
//  la main. La vérification distante part ensuite en tâche de fond et ne sert
//  qu'au lancement suivant — jamais à retarder celui-ci.
//
//  Cible : iOS 16.
//
import Foundation

/// Point d'entrée du contenu hors ligne.
enum OfflBootstrap {
    /// `prepareContent` : applique le cache local sans réseau.
    static func prepareContent(
        ids: [OfflContentBundleId] = OfflContentBundleId.all,
        store: OfflContentStore = .shared
    ) async {
        _ = await OfflSync.adoptCachedContent(store: store, ids: ids)
    }

    /// `scheduleContentRefresh` : lance la synchronisation en tâche de fond.
    static func scheduleContentRefresh(
        order: [OfflContentBundleId] = [],
        ids: [OfflContentBundleId]? = nil,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix
    ) {
        Task { _ = await downloadContentWithRetry(order: order, ids: ids, baseUrl: baseUrl) }
    }

    /// `downloadContentWithRetry` : télécharge et reprend une panne transitoire.
    static func downloadContentWithRetry(
        order: [OfflContentBundleId] = [],
        ids: [OfflContentBundleId]? = nil,
        concurrency: Int = 1,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix,
        retryDelays: [Int] = OfflDownloadConfig.refreshRetryDelaysMs
    ) async -> OfflRemoteContentSummary {
        await OfflSync.retryRemoteContentDownload(
            download: {
                await OfflContentDownloadMonitor.shared.download(
                    order: order, ids: ids, concurrency: concurrency, baseUrl: baseUrl
                )
            },
            ids: ids,
            retryDelays: retryDelays
        )
    }

    /// `downloadExerciseContent` : un exercice et ses compléments utiles.
    static func downloadExerciseContent(
        itemId: String,
        bundleIds: [OfflContentBundleId],
        store: OfflContentStore = .shared,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix
    ) async -> OfflExerciseDownloadResult {
        await OfflSync.refreshRemoteExercise(baseUrl: baseUrl, store: store, bundleIds: bundleIds, itemId: itemId)
    }

    /// `downloadExerciseChapterContent` : seul l'exercice touché du chapitre.
    static func downloadExerciseChapterContent(
        itemId: String,
        request: OfflContentChapterRequest,
        store: OfflContentStore = .shared,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix
    ) async -> OfflChapterDownloadResult {
        await OfflSync.refreshRemoteChapterExercise(baseUrl: baseUrl, store: store, request: request, itemId: itemId)
    }

    /// `downloadChapterContent` : un ou plusieurs chapitres, sans banque annuelle.
    static func downloadChapterContent(
        requests: [OfflContentChapterRequest],
        store: OfflContentStore = .shared,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix
    ) async -> OfflChapterDownloadResult {
        await OfflSync.refreshRemoteChapters(baseUrl: baseUrl, store: store, requests: requests)
    }

    /// `prefetchChapterContent` : précharge les chapitres sans rendu.
    static func prefetchChapterContent(
        bundleIds: [OfflContentBundleId],
        concurrency: Int = 2,
        store: OfflContentStore = .shared,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix
    ) async -> OfflChapterDownloadResult {
        await OfflSync.prefetchRemoteChapters(baseUrl: baseUrl, store: store, bundleIds: bundleIds, concurrency: concurrency)
    }

    /// `prefetchChapterStatements` : prépare les fichiers des chapitres affichés.
    static func prefetchChapterStatements(
        requests: [OfflContentChapterRequest],
        store: OfflContentStore = .shared,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix
    ) async -> OfflChapterDownloadResult {
        await OfflSync.prefetchRemoteChapterRequests(baseUrl: baseUrl, store: store, requests: requests)
    }

    /// `downloadExerciseSolution` : corrigé unitaire, à l'ouverture de l'exercice.
    static func downloadExerciseSolution(
        itemId: String,
        store: OfflContentStore = .shared,
        baseUrl: String = OfflDownloadConfig.contentPathPrefix
    ) async -> Bool {
        await OfflSync.refreshRemoteExerciseSolution(baseUrl: baseUrl, store: store, itemId: itemId)
    }
}
