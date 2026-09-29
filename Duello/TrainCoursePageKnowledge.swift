import SwiftUI

// V3 2026-09-29 (complexité) : extension extraite de `TrainCoursePage.swift`.
// Analyse des notions du cours (`indexCourseKnowledge` `SubjectsScreen.tsx:4934`,
// `courseAnalysisStatus` `8244`, reprise `retryCourseKnowledgeAnalysis` `5061`).
// Les membres étaient `private` dans `TrainCoursePage.swift` ; `private` en Swift
// est limité au FICHIER, ils sont donc élargis à `internal` (corps inchangés).
// Le bandeau d'affichage `knowledgeStatus(document:)` reste dans la vue.

extension TrainCoursePage {
    /// Démarre l'analyse du cours quand un PDF est présent et qu'aucun index
    /// n'existe pour ce document (`indexCourseKnowledge`, `SubjectsScreen.tsx:5034`).
    func startKnowledgeAnalysisIfNeeded(document: CtdStoredCourseDocument) {
        guard document.mimeType == .pdf else { return }
        guard knowledgeIndex?.sourceUploadedAt != document.uploadedAt else { return }
        guard !knowledgeAnalyzing else { return }
        Task { await runKnowledgeAnalysis(document: document) }
    }

    /// `indexCourseKnowledge` : génère les cartes du cours puis en tire l'index
    /// de connaissances (`persistCourseKnowledgeIndex`).
    func runKnowledgeAnalysis(document: CtdStoredCourseDocument) async {
        knowledgeAnalyzing = true
        knowledgeError = nil
        defer { knowledgeAnalyzing = false; knowledgeProgress = nil }
        let accountId = session.session?.publicId ?? ""
        let storage = CollUserDefaultsFlashcardJobStorage(accountId: accountId)
        do {
            let generated = try await CollFlashcardsApi.generateCourseFlashcardsFromPdf(
                accountId: accountId,
                document: document,
                chapterName: chapter.name,
                storage: storage,
                token: session.token,
                options: CollFlashcardGenerationOptions(
                    jobStorageKey: TrainCourseKnowledge.jobStorageKey(
                        year: programYear, chapterId: chapter.id
                    ),
                    onProgress: { progress in
                        Task { @MainActor in knowledgeProgress = progress }
                    }
                )
            )
            persistKnowledgeIndex(document: document, generated: generated)
        } catch {
            knowledgeError = CollFlashcardsApi.generationErrorMessage(error)
        }
    }

    /// `persistCourseKnowledgeIndex` : l'index des notions positionnées remplace
    /// celui du chapitre, et l'erreur éventuelle s'efface.
    func persistKnowledgeIndex(
        document: CtdStoredCourseDocument, generated: CollFlashcardsDocument
    ) {
        let index = CollCourseIndex.fromFlashcards(generated, sourceUploadedAt: document.uploadedAt)
        guard !index.anchors.isEmpty else { return }
        TrainCourseKnowledge.save(index, year: programYear, chapterId: chapter.id)
        knowledgeIndex = index
        knowledgeError = nil
    }

    /// Reprise explicite (`retryCourseKnowledgeAnalysis`).
    func retryKnowledgeAnalysis() {
        guard let document else { return }
        knowledgeError = nil
        Task { await runKnowledgeAnalysis(document: document) }
    }

    /// Message du bandeau d'analyse (`courseAnalysisStatusText`).
    var knowledgeStatusText: String {
        if knowledgeAnalyzing {
            let label = knowledgeProgressLabel ?? "Analyse des notions en arrière-plan…"
            return "\(label) Tu peux déjà indiquer où tu en es."
        }
        if let index = knowledgeIndex {
            return "\(index.anchors.count) notions repérées : les badges utilisent la position exacte du curseur."
        }
        if let knowledgeError {
            return "Analyse interrompue : \(knowledgeError)"
        }
        return "L’analyse précise des notions démarrera automatiquement."
    }

    /// `activeCourseKnowledgeProgressLabel` : phase de l'analyse en cours.
    var knowledgeProgressLabel: String? {
        guard let progress = knowledgeProgress else { return nil }
        switch progress.phase {
        case .preparing: return "Préparation du fichier…"
        case .uploading:
            let percent = Int(((progress.fraction ?? 0) * 100).rounded())
            return "Téléversement du cours : \(percent) %"
        case .queued: return "Cours téléversé · Analyse en attente…"
        case .analyzing: return "Cours téléversé · Analyse des notions…"
        }
    }
}
