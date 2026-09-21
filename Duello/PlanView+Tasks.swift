//
//  PlanView+Tasks.swift
//  Duello
//
//  Écran « Plan » — ajout, coche et report des tâches (extension de PlanView).
//
import Foundation
import SwiftUI

extension PlanView {

    // MARK: Ajout, coche, report

    /// `handleTranscript` (lignes 158-183) : analyse IA locale si elle est
    /// réglée, repli sur l'analyseur standard, tri par urgence décroissante.
    func addTasks(from transcript: String) {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        composerText = ""
        ollamaFallbackNotice = false

        let useOllama = ollamaSettings.enabled
            && !ollamaSettings.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard useOllama else {
            append(PlanTaskAnalyzer.parse(transcript: clean))
            return
        }

        isAnalyzing = true
        let settings = ollamaSettings
        Task {
            do {
                let parsed = try await PlanOllamaClient.parse(transcript: clean, settings: settings)
                DispatchQueue.main.async {
                    isAnalyzing = false
                    append(parsed)
                }
            } catch {
                let fallback = PlanTaskAnalyzer.parse(transcript: clean)
                DispatchQueue.main.async {
                    isAnalyzing = false
                    ollamaFallbackNotice = true
                    append(fallback)
                }
            }
        }
    }

    private func append(_ added: [PlanTask]) {
        guard !added.isEmpty else { return }
        var next = tasks + added
        next.sort { PlanTaskAnalyzer.urgencyScore($0) > PlanTaskAnalyzer.urgencyScore($1) }
        tasks = next
        persistTasks(next)

        lastAddedCount = added.count
        let count = added.count
        // Le bandeau d'ajout s'efface tout seul après 3 500 ms (ligne 95).
        DispatchQueue.main.asyncAfter(deadline: .now() + PlanMetrics.bannerDismissDelay) {
            if lastAddedCount == count { lastAddedCount = 0 }
        }
    }

    private func updateTasks(_ transform: (inout [PlanTask]) -> Void) {
        var next = tasks
        transform(&next)
        tasks = next
        persistTasks(next)
    }

    /// Coche locale : la tâche faite sort de l'avancement et s'affiche en grisé.
    func toggle(_ task: PlanTask) {
        updateTasks { items in
            guard let index = items.firstIndex(where: { $0.id == task.id }) else { return }
            items[index].isDone.toggle()
        }
    }

    /// Report local d'un jour : l'échéance glisse, la tâche redevient à faire.
    func report(_ task: PlanTask) {
        updateTasks { items in
            guard let index = items.firstIndex(where: { $0.id == task.id }) else { return }
            items[index].postponedDays += 1
            items[index].isDone = false
        }
    }
}
